-- download.lua for the 64-bit (steamrt64) Steam client + SLSsteam.
-- Part of https://github.com/one-eyed-queen/paws-plugins
--
-- This is the x64 port of the 32-bit download.lua shipped with paws. The x86 plugin's
-- byte patterns and PackageInfo_t offsets do not exist in the 64-bit client.
-- Verified against steamclient.so build 1792618285 (sha256 dab8df0d...).
--
-- -- version: 2026.11.22-x64-2
-- -- steam-arch: 64
-- -- steam-build: 1792618285
-- -- pattern-source: steamrt64/steamclient.so
-- -- depots-offset: 0x58 (second CUtlVector in PackageInfo_t; x86 plugin used 0x48)

Downloader = Downloader or {
	setup = false,

	-- Hooks
	getPackageHook = nil, getPackageTramp = nil,
	getBinaryHook = nil, getBinaryTramp = nil,
	getMRCHook = nil, getMRCTramp = nil,

	-- GetPackage vars
	PackageDepotIds = {},
	Package = nil,
	RewriteDepots = false,

	-- GetMRC vars
	MAX_MANIFEST_STRING_SIZE = 32,
	MAX_MANIFEST_TRIES = 5,
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

Downloader.mutexReturn = function(value, mutex)
	mutex:unlock()
	return value
end

-- GetPackage methods --------------------------------------------------------------------------
Downloader.getAllDepots = function()
	-- Do not assign other table, iirc Lua creates a ref if you do
	local merged = {}

	for k, v in pairs(Downloader.PackageDepotIds) do
		table.insert(merged, v)
	end

	for k, v in pairs(Downloader.AdditionalDepots) do
		table.insert(merged, v)
	end

	return merged
end

Downloader.writeDepotIds = function()
	local pkg = Downloader.Package

	if pkg == nil then
		return
	end

	log.debug("writeDepotIds into Package " .. pkg.packageId .. " at " .. tostring(pkg))

	-- PackageInfo_t has two CUtlVector<uint32> fields. The first (+0x40) is the dependency/status list;
	-- the second (+0x58, x86 +0x48) is the AdditionalDepots list the download loop reads. Patch only
	-- the second, exactly like the x86 plugin.
	local depots = pkg.depots
	local mem = depots.mem
	local size = depots.size

	if #Downloader.PackageDepotIds < 1 then
		-- Back up original depot Ids
		for i = 0, size - 1 do
			table.insert(Downloader.PackageDepotIds, mem[i])
		end
	end

	local merged = Downloader.getAllDepots()
	local new = ffi.cast("uint32_t*", tier0.Plat_Alloc(4 * #merged))

	for i = 0, #merged - 1 do
		new[i] = merged[i + 1]
	end

	depots.mem = new
	depots.size = #merged
	depots.alloc = depots.size

	tier0.Plat_Free(mem)
end

Downloader.hkGetPackage = ffi.cast("GetPackage_t", function(pPkgInfoCache, pkgId, mask)
	local mutex = LuaMutex()
	local pPkg = Downloader.getPackageTramp(pPkgInfoCache, pkgId, mask)

	-- We only want to modify package 0
	if pkgId ~= 0 then
		return Downloader.mutexReturn(pPkg, mutex)
	end

	-- Pkg not cached yet, abort
	if pPkg == nil then
		return Downloader.mutexReturn(pPkg, mutex)
	end

	-- Nothing to inject
	if not Downloader.RewriteDepots then
		return Downloader.mutexReturn(pPkg, mutex)
	end

	if Downloader.Package == nil then
		-- Catch the pkg
		Downloader.Package = pPkg
	end

	Downloader.writeDepotIds()
	Downloader.RewriteDepots = false

	return Downloader.mutexReturn(pPkg, mutex)
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
	local mutex = LuaMutex()
	local size = Downloader.getBinaryTramp(pConfigStore, store, pChName, pOut, outSize)

	local nameMatch = ffi.string(pChName):match("%d+\\DecryptionKey")
	if nameMatch == nil then
		return Downloader.mutexReturn(size, mutex)
	end

	local depotId = tonumber(nameMatch:match("%d+"))
	local key = Downloader.DecryptionKeys[depotId]

	if key == nil then
		-- No key in SLSsteam config & no key in ConfigStore
		if size < 1 then
			log.warn("Missing decryptionkey for " .. depotId)
		end

		return Downloader.mutexReturn(size, mutex)
	end

	local bytes = Downloader.keyToBinary(depotId, key)
	if bytes == nil then
		return Downloader.mutexReturn(size, mutex)
	end

	log.debug("Using config key for " .. depotId)

	for i = 0, #bytes - 1 do
		pOut[i] = bytes[i + 1]
	end

	return Downloader.mutexReturn(#bytes, mutex)
end)

-- GetManifestRequestCode ----------------------------------------------------------------------
Downloader.getManifestRequestCode = function(manifestId, try)
	if try > Downloader.MAX_MANIFEST_TRIES then
		return nil
	end

	local manifestCStr = ffi.new("char[?]", Downloader.MAX_MANIFEST_STRING_SIZE)
	ffi.C.snprintf(manifestCStr, Downloader.MAX_MANIFEST_STRING_SIZE, "%llu", manifestId)

	local url = "http://gmrc.wudrm.com/manifest/" .. tostring(ffi.string(manifestCStr))
	local codeStr = tostring(curl.downloadString(url, 5))
	if #codeStr < 1 then
		log.warn("Failed to download manifest request code for " .. manifestId)
	end

	if tonumber(codeStr) == nil then
		log.error("Invalid MRC response " .. codeStr)
		return Downloader.getManifestRequestCode(manifestId, try + 1)
	end

	-- We don't use tonumber because of precision loss
	local mrc = ffi.C.strtoull(codeStr, ffi.cast("char*", 0), 10)
	return mrc
end

Downloader.hkGetMRC = ffi.cast("GetMRC_t", function(a1, appId, depotId, manifestId, pChBranch, pOutMRC)
	local mutex = LuaMutex()
	local success = Downloader.getMRCTramp(a1, appId, depotId, manifestId, pChBranch, pOutMRC)

	-- Don't rely on success. Check whether MRC has been written
	if pOutMRC[0] ~= ffi.cast("uint64_t", 0) then
		return Downloader.mutexReturn(success, mutex)
	end

	local code = Downloader.getManifestRequestCode(manifestId, 1)
	if code == nil then
		log.error("Failed to get MRC for " .. depotId)
		return Downloader.mutexReturn(success, mutex)
	end

	local codeCStr = ffi.new("char[?]", Downloader.MAX_MANIFEST_STRING_SIZE)
	ffi.C.snprintf(codeCStr, Downloader.MAX_MANIFEST_STRING_SIZE, "%llu", code)
	log.debug("Using MRC " .. tostring(ffi.string(codeCStr)) .. " for " .. depotId)

	pOutMRC[0] = code

	return Downloader.mutexReturn(true, mutex)
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
	Downloader.writeDepotIds()
end

-- Callbacks
SLS.registerCallback("SLSsteam::configLoaded", Downloader.configLoaded)
SLS.registerCallback("SLSsteam::luaReload", Downloader.luaReload)

log.notify("download.lua (x64) loaded!")
