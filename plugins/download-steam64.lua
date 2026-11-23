-- download.lua for the 64-bit (steamrt64) Steam client + SLSsteam.
-- Part of https://github.com/one-eyed-queen/paws-plugins
--
-- This is the x64 port of the 32-bit download.lua shipped with paws. The x86 plugin's
-- byte patterns and PackageInfo_t offsets do not exist in the 64-bit client.
-- Verified against steamclient.so build 1792618285 (sha256 dab8df0d...).
--
-- -- version: 2026.11.23-x64-3
-- -- steam-arch: 64
-- -- steam-build: 1792618285
-- -- pattern-source: steamrt64/steamclient.so
-- -- depots-offset: 0x58 (second CUtlVector in PackageInfo_t; x86 plugin used 0x48)
--
-- 2026.11.23-x64-3: MRC sanity checks, success cache and failure backoff, HTTPS provider, total request
-- budget, mutex safety on every hook, and defensive depot-vector handling. The MRC robustness ideas came
-- from niwia's SpaceBunny (GPL-3.0, credited in contrib/assella); this is an independent x64 implementation.

Downloader = Downloader or {
	setup = false,

	-- Hooks
	getPackageHook = nil, getPackageTramp = nil,
	getBinaryHook = nil, getBinaryTramp = nil,
	getMRCHook = nil, getMRCTramp = nil,

	-- GetPackage vars
	PackageDepotIds = {},
	OriginalDepotCaptured = false,
	Package = nil,
	RewriteDepots = false,

	-- GetMRC vars
	MRC_PROVIDERS = {
		{ name = "wudrm", url = "https://gmrc.wudrm.com/manifest/" },
	},
	MRC_TIMEOUT_SEC = 4,
	MRC_TOTAL_BUDGET_SEC = 8,
	MRC_CACHE_TTL = 300,
	MRC_FAIL_TTL = 30,
	MRC_CACHE_MAX = 500,
	MRCCache = {},
	MRCFail = {},
	MRCProviderFail = {},
}

Downloader.resetSettings = function()
	-- Config stuff. Reset these on every Lua reload
	Downloader.AdditionalDepots = {}
	Downloader.DecryptionKeys = {}
end
Downloader.resetSettings()

-- Include guard, do not run multiple times
if Downloader.setup then
	return
end
Downloader.setup = true

local ffi = require("ffi")

-- This build is for the 64-bit client only. Fail loudly rather than silently producing 0 B.
if not ffi.abi("64bit") then
	log.notifyError("download.lua (x64) needs the 64-bit Steam client. Use the x86 plugin instead.")
	return
end

-- Locate libtier0_s.so by absolute path. ffi.load("tier0_s") resolves by SONAME, and
-- this library has no SONAME, so a bare name fails inside Steam's LuaJIT on x64.
-- steamclient.so is always mapped (we scan it below) and libtier0_s.so sits beside it
-- in steamrt64, so prefer that sibling path; fall back to any mapped copy, then to names.
-- luaL_openlibs makes io available to plugins.
local tier0
local function load_tier0()
	local sibling, mapped
	local f = io.open("/proc/self/maps", "r")
	if f then
		for line in f:lines() do
			-- Grab the mapped path up to .so; a "(deleted)" suffix after it is harmless.
			if not sibling then
				local client = line:match("(/%S*steamclient%.so)")
				if client then
					local dir = client:match("^(.*)/")
					if dir then
						sibling = dir .. "/libtier0_s.so"
					end
				end
			end
			if not mapped then
				mapped = line:match("(/%S*libtier0_s%.so)")
			end
		end
		f:close()
	end
	for _, path in ipairs({ sibling, mapped }) do
		if path then
			local ok, lib = pcall(ffi.load, path)
			if ok then
				return lib
			end
		end
	end
	for _, name in ipairs({ "libtier0_s.so", "tier0_s" }) do
		local ok, lib = pcall(ffi.load, name)
		if ok then
			return lib
		end
	end
	error("could not load libtier0_s.so: no sibling of steamclient.so, no mapped copy, and no usable name")
end

local ok_tier0, result = pcall(load_tier0)
if not ok_tier0 then
	log.notifyError("download.lua (x64): " .. tostring(result))
	return
end
tier0 = result

ffi.cdef[[
	void snprintf(const char*, size_t size, const char*, ...);
	unsigned long long strtoull(const char*, char*, int);

	void* Plat_Alloc(int);
	void Plat_Free(void*);

	void* place_lua_hook(const int, const void*);

	typedef struct
	{
		uint32_t* mem;      /* pointer, 8 bytes on x64 */
		uint32_t alloc;     /* 0x8 */
		uint32_t grow;      /* 0xC */
		uint32_t size;      /* 0x10, struct is 0x18 with padding */
	} CUtlVector64;

	typedef struct
	{
		uint32_t packageId;            /* 0x0 */
		uint8_t __pad0x4[0x54];        /* pad to 0x58 */
		CUtlVector64 depots;           /* 0x58: AdditionalDepots (x86 plugin patched +0x48) */
	} PackageInfo_t64;

	typedef PackageInfo_t64*(*GetPackage_t)(void*, uint32_t, uint64_t);
	typedef int(*GetBinary_t)(void*, uint32_t, const char*, int8_t*, uint32_t);
	typedef bool(*GetMRC_t)(void*, uint32_t, uint32_t, uint64_t, const char*, uint64_t*);
]]

local steamClientMod = memhlp.getModule("steamclient.so")

-- x64 call-site patterns, from steamclient.so 1792618285.
-- Each is unique in the 64-bit .text and is resolved through getJmpTarget to the
-- actual function, matching the x86 approach.
--
-- GetPackage: call followed by `cmp dword [rax+0x18], 3; je` in the caller.
--   1 hit at VA 0x18ea900 -> target 0x10544c0 (CPackageInfoCache::GetPackage).
-- GetMRC: call followed by `cmp eax,1; jne; xor esi,esi; mov rdi,rbx`.
--   1 hit at VA 0x13c7352 -> target 0x13af120 (GetManifestRequestCode).
local getPackageInfoPtr = memhlp.getJmpTarget(
	memhlp.patternScan("E8 ? ? ? ? 83 78 18 03 0F 84", steamClientMod)
)
local getMRCPtr = memhlp.getJmpTarget(
	memhlp.patternScan("E8 ? ? ? ? 83 F8 01 0F 85 ? ? ? ? 31 F6 48 89 DF", steamClientMod)
)

local configStoreMapGetBinary = VFTableInfo_t("21IClientConfigStoreMap", "GetBinary")
if not configStoreMapGetBinary:init() then
	log.notifyError("Failed to find GetBinary on x64!")
	return
end

local configStoreGetBinary = VFTableInfo_t("12CConfigStore", "GetBinary", configStoreMapGetBinary.index)
if not configStoreGetBinary:init() then
	log.notifyError("Failed to find GetBinary on x64!")
	return
end

-- Every hook holds LuaMutex while it runs. An error used to leave it locked and stall Steam, so the whole
-- body is wrapped: the fallback is returned and the mutex is unlocked even if a hook throws.
Downloader.callInHook = function(label, fallback, fn)
	local ok, mutex = pcall(LuaMutex)
	if not ok then
		log.error("download.lua (x64): " .. label .. " could not lock LuaMutex: " .. tostring(mutex))
		return type(fallback) == "function" and fallback() or fallback
	end

	local completed, result = pcall(fn, mutex)
	if not completed then
		log.error("download.lua (x64): " .. label .. " failed: " .. tostring(result))
		result = type(fallback) == "function" and fallback() or fallback
	end

	local unlocked, unlockError = pcall(function() mutex:unlock() end)
	if not unlocked then
		log.error("download.lua (x64): " .. label .. " could not unlock LuaMutex: " .. tostring(unlockError))
	end
	return result
end

-- GetPackage methods --------------------------------------------------------------------------
Downloader.getAllDepots = function()
	-- Keep the original order, drop duplicates, and never put a bad id into the vector.
	local merged, seen = {}, {}

	local function append(list)
		for _, id in ipairs(list) do
			if type(id) == "number" and id > 0 and id == math.floor(id) and not seen[id] then
				seen[id] = true
				merged[#merged + 1] = id
			end
		end
	end

	append(Downloader.PackageDepotIds)
	append(Downloader.AdditionalDepots)
	return merged
end

Downloader.writeDepotIds = function()
	local pkg = Downloader.Package

	if pkg == nil or pkg.packageId ~= 0 then
		return
	end

	-- PackageInfo_t has two CUtlVector<uint32> fields. The first (+0x40) is the dependency/status list;
	-- the second (+0x58, x86 +0x48) is the AdditionalDepots list the download loop reads. Patch only
	-- the second, exactly like the x86 plugin.
	local depots = pkg.depots
	if depots == nil or depots.mem == nil then
		log.warn("Package 0 has no depot vector, leaving it alone")
		return
	end

	local mem = depots.mem
	local size = tonumber(depots.size) or 0
	local grow = depots.grow

	if size < 0 or size > 0x10000 or (tonumber(depots.alloc) or 0) < size then
		log.warn("Package 0 depot vector looks corrupt (size " .. size .. "), leaving it alone")
		return
	end

	log.debug("writeDepotIds into Package " .. pkg.packageId .. " at " .. tostring(pkg))

	if not Downloader.OriginalDepotCaptured then
		for i = 0, size - 1 do
			table.insert(Downloader.PackageDepotIds, mem[i])
		end
		Downloader.OriginalDepotCaptured = true
		log.debug("Backed up " .. size .. " original depot ids")
	end

	local merged = Downloader.getAllDepots()
	if #merged < 1 then
		log.warn("Refusing to write an empty depot vector")
		return
	end

	-- The config reload path calls this with no additional depots, which is already the restored list.
	local same = (#merged == size)
	if same then
		for i = 0, size - 1 do
			if mem[i] ~= merged[i + 1] then
				same = false
				break
			end
		end
	end
	if same then
		log.debug("Depot vector is already the merged list, leaving it alone")
		return
	end

	local new = ffi.cast("uint32_t*", tier0.Plat_Alloc(4 * #merged))
	if new == nil then
		log.error("Plat_Alloc failed for " .. #merged .. " depots, keeping the original vector")
		return
	end

	for i = 0, #merged - 1 do
		new[i] = merged[i + 1]
	end

	depots.mem = new
	depots.size = #merged
	depots.alloc = depots.size
	depots.grow = grow

	tier0.Plat_Free(mem)
end

Downloader.hkGetPackage = ffi.cast("GetPackage_t", function(pPkgInfoCache, pkgId, mask)
	local trampResult = nil

	return Downloader.callInHook("GetPackage", function() return trampResult end, function()
		local pPkg = Downloader.getPackageTramp(pPkgInfoCache, pkgId, mask)
		trampResult = pPkg

		-- We only want to modify package 0
		if pkgId ~= 0 or pPkg == nil then
			return pPkg
		end

		-- Steam can recreate the package object. Never patch a stale pointer.
		if Downloader.Package ~= nil and Downloader.Package ~= pPkg then
			log.debug("Package 0 pointer moved, re-baselining the depot backup")
			Downloader.Package = nil
			Downloader.PackageDepotIds = {}
			Downloader.OriginalDepotCaptured = false
		end

		if not Downloader.RewriteDepots then
			return pPkg
		end

		if Downloader.Package == nil then
			Downloader.Package = pPkg
		end

		Downloader.writeDepotIds()
		Downloader.RewriteDepots = false
		return pPkg
	end)
end)

-- GetBinary methods ---------------------------------------------------------------------------
Downloader.keyToBinary = function(depotId, key)
	if #key ~= 64 then
		log.error("Invalid key for " .. depotId)
		return nil
	end

	local bytes = {}

	for i = 1, #key, 2 do
		local sub = key:sub(i, i + 1)
		local byte = tonumber(sub, 16)

		if byte == nil then
			log.error("Invalid digit in " .. sub .. " in key for " .. depotId)
			return nil
		end

		table.insert(bytes, byte)
	end

	return bytes
end

Downloader.hkGetBinary = ffi.cast("GetBinary_t", function(pConfigStore, store, pChName, pOut, outSize)
	local trampSize = 0

	return Downloader.callInHook("GetBinary", function() return trampSize end, function()
		trampSize = Downloader.getBinaryTramp(pConfigStore, store, pChName, pOut, outSize)

		local nameMatch = ffi.string(pChName):match("%d+\\DecryptionKey")
		if nameMatch == nil then
			return trampSize
		end

		local depotId = tonumber(nameMatch:match("%d+"))
		local key = Downloader.DecryptionKeys[depotId]

		if key == nil then
			-- No key in SLSsteam config & no key in ConfigStore
			if trampSize < 1 then
				log.warn("Missing decryptionkey for " .. depotId)
			end
			return trampSize
		end

		local bytes = Downloader.keyToBinary(depotId, key)
		if bytes == nil then
			return trampSize
		end

		log.debug("Using config key for " .. depotId)
		for i = 0, #bytes - 1 do
			pOut[i] = bytes[i + 1]
		end
		return #bytes
	end)
end)

-- GetManifestRequestCode ----------------------------------------------------------------------
-- MRC resolution is deliberately independent of the 32-bit SpaceBunny implementation: same robustness
-- ideas (sanity checks, caching, backoff, a request budget) but written for this x64 plugin.
Downloader.u64str = function(value)
	local buf = ffi.new("char[24]")
	ffi.C.snprintf(buf, 24, "%llu", ffi.cast("uint64_t", value))
	return ffi.string(buf)
end

-- A manifest request code is a random uint64. Short numbers, zeroes, HTML and echoed manifest ids are
-- provider errors, not codes. strtoull is used instead of tonumber so 18-20 digit codes keep precision.
Downloader.validateMRC = function(raw, manifestIdStr)
	if raw == nil then
		return nil
	end

	local s = tostring(raw):gsub("^%s+", ""):gsub("%s+$", "")
	if #s >= 2 and s:sub(1, 1) == '"' and s:sub(-1) == '"' then
		s = s:sub(2, -2)
	end

	if not s:match("^%d+$") or s:match("^0+$") then
		return nil
	end

	local digits = s:gsub("^0+", "")
	if #digits < 8 or #s > 20 then
		return nil
	end

	if manifestIdStr ~= nil and digits == tostring(manifestIdStr):gsub("^0+", "") then
		return nil
	end

	local code = ffi.C.strtoull(s, ffi.cast("char*", 0), 10)
	if Downloader.u64str(code) ~= digits then
		return nil
	end

	return digits
end

Downloader.resetMRCCaches = function()
	Downloader.MRCCache = {}
	Downloader.MRCFail = {}
	Downloader.MRCProviderFail = {}
end

Downloader.pruneMRCCaches = function()
	local now = os.time()

	for k, v in pairs(Downloader.MRCCache) do
		if type(v) ~= "table" or now - (v.at or 0) >= Downloader.MRC_CACHE_TTL then
			Downloader.MRCCache[k] = nil
		end
	end

	for k, untilTime in pairs(Downloader.MRCFail) do
		if untilTime <= now then
			Downloader.MRCFail[k] = nil
		end
	end
end

Downloader.mrcProviderCooling = function(name)
	local state = Downloader.MRCProviderFail[name]
	if state == nil then
		return false
	end

	if state.untilTime <= os.time() then
		Downloader.MRCProviderFail[name] = nil
		return false
	end
	return true
end

Downloader.mrcRecordProviderFailure = function(name, reason)
	local now = os.time()
	local state = Downloader.MRCProviderFail[name]
	if state == nil then
		state = { count = 0, untilTime = 0 }
	end

	state.count = state.count + 1
	if state.count >= 3 then
		state.untilTime = now + Downloader.MRC_FAIL_TTL
		state.count = 0
		log.warn("MRC provider " .. name .. " skipped for " .. Downloader.MRC_FAIL_TTL
			.. "s after " .. reason)
	end
	Downloader.MRCProviderFail[name] = state
end

Downloader.fetchMRCFrom = function(provider, manifestIdStr, timeout)
	if Downloader.mrcProviderCooling(provider.name) then
		return nil, "cooling"
	end

	local url = tostring(provider.url):gsub("/+$", "") .. "/" .. manifestIdStr
	local ok, raw = pcall(curl.downloadString, url, timeout)
	if not ok then
		log.debug("MRC provider " .. provider.name .. " error: " .. tostring(raw))
		Downloader.mrcRecordProviderFailure(provider.name, "an error")
		return nil, "error"
	end

	local code = Downloader.validateMRC(raw, manifestIdStr)
	if code == nil then
		local reason = "bad-body"
		if raw == nil or raw == "" then
			reason = "empty"
		elseif type(raw) == "string" and raw:lower():find("<html", 1, true) then
			reason = "html"
		end
		log.debug("MRC provider " .. provider.name .. " returned " .. reason)
		Downloader.mrcRecordProviderFailure(provider.name, reason)
		return nil, reason
	end

	Downloader.MRCProviderFail[provider.name] = nil
	return code, "ok"
end

Downloader.getManifestRequestCode = function(manifestId)
	if manifestId == nil then
		return nil
	end

	local manifestIdStr = Downloader.u64str(manifestId)
	if manifestIdStr == "0" then
		return nil
	end

	Downloader.pruneMRCCaches()
	local now = os.time()

	local cached = Downloader.MRCCache[manifestIdStr]
	if cached ~= nil and now - (cached.at or 0) < Downloader.MRC_CACHE_TTL then
		return ffi.C.strtoull(cached.value, ffi.cast("char*", 0), 10)
	end

	local failUntil = Downloader.MRCFail[manifestIdStr]
	if failUntil ~= nil and failUntil > now then
		return nil
	end

	local deadline = now + Downloader.MRC_TOTAL_BUDGET_SEC
	local report = {}

	for _, provider in ipairs(Downloader.MRC_PROVIDERS) do
		local remaining = deadline - os.time()
		if remaining < 1 then
			report[#report + 1] = provider.name .. "=no-budget"
		else
			local timeout = math.max(1, math.min(provider.timeout or Downloader.MRC_TIMEOUT_SEC, remaining))
			local code, reason = Downloader.fetchMRCFrom(provider, manifestIdStr, timeout)
			report[#report + 1] = provider.name .. "=" .. reason

			if code ~= nil then
				Downloader.MRCCache[manifestIdStr] = { value = code, at = os.time(), provider = provider.name }
				Downloader.MRCFail[manifestIdStr] = nil
				log.debug("Using MRC " .. code .. " for manifest " .. manifestIdStr)
				return ffi.C.strtoull(code, ffi.cast("char*", 0), 10)
			end
		end
	end

	Downloader.MRCFail[manifestIdStr] = os.time() + Downloader.MRC_FAIL_TTL
	log.warn("Failed to get MRC for manifest " .. manifestIdStr .. " (" .. table.concat(report, ", ") .. ")")
	return nil
end

Downloader.hkGetMRC = ffi.cast("GetMRC_t", function(a1, appId, depotId, manifestId, pChBranch, pOutMRC)
	local trampSuccess = false

	return Downloader.callInHook("GetManifestRequestCode", function() return trampSuccess end, function()
		trampSuccess = Downloader.getMRCTramp(a1, appId, depotId, manifestId, pChBranch, pOutMRC)

		-- Don't rely on success. Check whether MRC has been written.
		if pOutMRC[0] ~= ffi.cast("uint64_t", 0) then
			return trampSuccess
		end

		local code = Downloader.getManifestRequestCode(manifestId)
		if code == nil then
			log.error("Failed to get MRC for " .. depotId)
			return trampSuccess
		end

		pOutMRC[0] = code
		return true
	end)
end)

-- Hooking ------------------------------------------------------------------------------------
Downloader.getPackageHook = LuaHook("GetPackage", getPackageInfoPtr)
Downloader.getPackageTramp = ffi.cast("GetPackage_t", ffi.C.place_lua_hook(Downloader.getPackageHook.index, Downloader.hkGetPackage))

Downloader.getBinaryHook = LuaHook("GetBinary", configStoreGetBinary.ptr)
Downloader.getBinaryTramp = ffi.cast("GetBinary_t", ffi.C.place_lua_hook(Downloader.getBinaryHook.index, Downloader.hkGetBinary))

Downloader.getMRCHook = LuaHook("GetManifestRequestCode", getMRCPtr)
Downloader.getMRCTramp = ffi.cast("GetMRC_t", ffi.C.place_lua_hook(Downloader.getMRCHook.index, Downloader.hkGetMRC))

-- Config -------------------------------------------------------------------------------------
Downloader.configLoaded = function()
	Downloader.resetSettings()

	-- DepotIds
	Downloader.AdditionalDepots = SLS.config:getIntList("AdditionalDepots")
	Downloader.RewriteDepots = true -- Lazy inject, Package may still be nil

	-- Decryptionkeys
	local keyNode = SLS.config:getNode("DecryptionKeys")
	if not keyNode.isDefined then
		log.notifyWarn("Missing DecryptionKeys in config!")
		return
	end

	local keys = keyNode:asPairList()
	for _, v in pairs(keys) do
		Downloader.DecryptionKeys[v[1]:asInt()] = v[2]:asString()
	end
end

Downloader.luaReload = function()
	Downloader.resetSettings()
	Downloader.resetMRCCaches()
	Downloader.writeDepotIds()
end

-- Callbacks
SLS.registerCallback("SLSsteam::configLoaded", Downloader.configLoaded)
SLS.registerCallback("SLSsteam::luaReload", Downloader.luaReload)

log.notify("download.lua (x64) loaded!")
