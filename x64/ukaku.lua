Kagune = Kagune or {}
local Ukaku = Kagune.Ukaku or {}
Kagune.Ukaku = Ukaku
Ukaku.purge = function() Ukaku.wards = {}; Ukaku.cells = {} end
Ukaku.purge()
if Ukaku.sealed then return end
Ukaku.sealed = true

local ffi = require("ffi")
local function findCore()
	local clientDir, tierPath, handle
	handle = io.open("/proc/self/maps", "r")
	if handle then
		for line in handle:lines() do
			if not clientDir then
				local path = line:match("(/%S*steamclient%.so)")
				if path then
					local dir = path:match("^(.*)/")
					if dir then clientDir = dir .. "/libtier0_s.so" end
				end
			end
			if not tierPath then tierPath = line:match("(/%S*libtier0_s%.so)") end
		end
		handle:close()
	end
	for _, candidate in ipairs({ clientDir, tierPath }) do
		if candidate then
			local ok, lib = pcall(ffi.load, candidate)
			if ok then return lib end
		end
	end
	for _, candidate in ipairs({ "libtier0_s.so", "tier0_s" }) do
		local ok, lib = pcall(ffi.load, candidate)
		if ok then return lib end
	end
	error("no tier0")
end
if not ffi.abi("64bit") then log.notifyError("Ukaku: wrong arch"); return end
local ok, tier = pcall(findCore)
if not ok then log.notifyError("Ukaku: " .. tostring(tier)); return end

ffi.cdef[[
int snprintf(char*, size_t, const char*, ...);
unsigned long long strtoull(const char*, char*, int);
void* Plat_Alloc(int);
void Plat_Free(void*);
void* place_lua_hook(const int, const void*);
typedef struct { uint32_t* mem; uint32_t alloc; uint32_t grow; uint32_t size; } Q;
typedef struct { uint32_t id; uint8_t pad[0x54]; Q d; } W;
typedef W*(*H1)(void*, uint32_t, uint64_t);
typedef int(*H2)(void*, uint32_t, const char*, int8_t*, uint32_t);
typedef bool(*H3)(void*, uint32_t, uint32_t, uint64_t, const char*, uint64_t*);
]]

local client = memhlp.getModule("steamclient.so")
local packageAddr = memhlp.getJmpTarget(memhlp.patternScan("E8 ? ? ? ? 83 78 18 03 0F 84", client))
local manifestAddr = memhlp.getJmpTarget(memhlp.patternScan("E8 ? ? ? ? 83 F8 01 0F 85 ? ? ? ? 31 F6 48 89 DF", client))
local mapTable = VFTableInfo_t("21IClientConfigStoreMap", "GetBinary")
if not mapTable:init() then log.notifyError("Ukaku: no map"); return end
local storeTable = VFTableInfo_t("12CConfigStore", "GetBinary", mapTable.index)
if not storeTable:init() then log.notifyError("Ukaku: no store"); return end

Ukaku.core = nil
Ukaku.forge = false
Ukaku.hive = {}
Ukaku.molt = false
Ukaku.gates = {
	{ mark = "k", link = "https://gmrc.wudrm.com/manifest/" },
	{ mark = "g", link = "https://rapid-thunder-fba1wirecutter.7ucking.workers.dev/rescue/" },
}
Ukaku.pulse = 4
Ukaku.span = 8
Ukaku.life = 300
Ukaku.cool = 30
Ukaku.cap = 500
Ukaku.vault = {}
Ukaku.cage = {}
Ukaku.frost = {}

Ukaku.shield = function(label, fallback, action)
	local ok, mutex = pcall(LuaMutex)
	if not ok then return type(fallback) == "function" and fallback() or fallback end
	local done, value = pcall(action, mutex)
	if not done then value = type(fallback) == "function" and fallback() or fallback end
	pcall(function() mutex:unlock() end)
	return value
end

Ukaku.weave = function()
	local result, marked = {}, {}
	for _, list in ipairs({ Ukaku.hive, Ukaku.wards }) do
		for _, id in ipairs(list) do
			if type(id) == "number" and id > 0 and id == math.floor(id) and not marked[id] then
				marked[id] = true
				result[#result + 1] = id
			end
		end
	end
	return result
end

Ukaku.graft = function()
	local package = Ukaku.core
	if package == nil or package.id ~= 0 then return end
	local vector = package.d
	if vector == nil or vector.mem == nil then return end
	local memory = vector.mem
	local count = tonumber(vector.size) or 0
	local growth = vector.grow
	if count < 0 or count > 0x10000 or (tonumber(vector.alloc) or 0) < count then return end
	if not Ukaku.molt then
		for i = 0, count - 1 do Ukaku.hive[#Ukaku.hive + 1] = memory[i] end
		Ukaku.molt = true
	end
	local merged = Ukaku.weave()
	if #merged < 1 then return end
	local same = #merged == count
	if same then
		for i = 0, count - 1 do
			if memory[i] ~= merged[i + 1] then same = false; break end
		end
	end
	if same then return end
	local replacement = ffi.cast("uint32_t*", tier.Plat_Alloc(4 * #merged))
	if replacement == nil then return end
	for i = 0, #merged - 1 do replacement[i] = merged[i + 1] end
	vector.mem = replacement
	vector.size = #merged
	vector.alloc = vector.size
	vector.grow = growth
	tier.Plat_Free(memory)
end

Ukaku.claw = ffi.cast("H1", function(vault, id, veil)
	local result = nil
	return Ukaku.shield("P", function() return result end, function()
		result = Ukaku.packageTramp(vault, id, veil)
		if id ~= 0 or result == nil then return result end
		if Ukaku.core ~= nil and Ukaku.core ~= result then Ukaku.core, Ukaku.hive, Ukaku.molt = nil, {}, false end
		if not Ukaku.forge then return result end
		if Ukaku.core == nil then Ukaku.core = result end
		Ukaku.graft()
		Ukaku.forge = false
		return result
	end)
end)

Ukaku.melt = function(depot, key)
	if #key ~= 64 then return nil end
	local bytes = {}
	for i = 1, 64, 2 do
		local n = tonumber(key:sub(i, i + 1), 16)
		if n == nil then return nil end
		bytes[#bytes + 1] = n
	end
	return bytes
end

Ukaku.fang = ffi.cast("H2", function(store, bank, name, out, size)
	local count = 0
	return Ukaku.shield("B", function() return count end, function()
		count = Ukaku.binaryTramp(store, bank, name, out, size)
		local hit = ffi.string(name):match("%d+\\DecryptionKey")
		if hit == nil then return count end
		local key = Ukaku.cells[tonumber(hit:match("%d+"))]
		if key == nil then return count end
		local bytes = Ukaku.melt(0, key)
		if bytes == nil then return count end
		for i = 0, #bytes - 1 do out[i] = bytes[i + 1] end
		return #bytes
	end)
end)

Ukaku.echo = function(value)
	local buf = ffi.new("char[24]")
	ffi.C.snprintf(buf, 24, "%llu", ffi.cast("uint64_t", value))
	return ffi.string(buf)
end

Ukaku.sift = function(raw, manifest)
	if raw == nil then return nil end
	local trimmed = tostring(raw):gsub("^%s+", ""):gsub("%s+$", "")
	if #trimmed >= 2 and trimmed:sub(1, 1) == '"' and trimmed:sub(-1) == '"' then trimmed = trimmed:sub(2, -2) end
	if not trimmed:match("^%d+$") or trimmed:match("^0+$") then return nil end
	local digits = trimmed:gsub("^0+", "")
	if #digits < 8 or #trimmed > 20 then return nil end
	if manifest ~= nil and digits == tostring(manifest):gsub("^0+", "") then return nil end
	local value = ffi.C.strtoull(trimmed, ffi.cast("char*", 0), 10)
	if Ukaku.echo(value) ~= digits then return nil end
	return digits
end

Ukaku.wash = function() Ukaku.vault, Ukaku.cage, Ukaku.frost = {}, {}, {} end

Ukaku.shed = function()
	local now = os.time()
	for key, value in pairs(Ukaku.vault) do
		if type(value) ~= "table" or now - (value.t or 0) >= Ukaku.life then Ukaku.vault[key] = nil end
	end
	for key, value in pairs(Ukaku.cage) do if value <= now then Ukaku.cage[key] = nil end end
	local count = 0
	for _ in pairs(Ukaku.vault) do count = count + 1 end
	if count > Ukaku.cap then Ukaku.vault = {} end
end

Ukaku.chill = function(name)
	local state = Ukaku.frost[name]
	if state == nil then return false end
	if state.e <= os.time() then Ukaku.frost[name] = nil; return false end
	return true
end

Ukaku.scar = function(name, reason)
	local now = os.time()
	local state = Ukaku.frost[name] or { c = 0, e = 0 }
	state.c = state.c + 1
	if state.c >= 3 then state.e = now + Ukaku.cool; state.c = 0 end
	Ukaku.frost[name] = state
end

Ukaku.torch = function(gate, manifest, timeout)
	if Ukaku.chill(gate.mark) then return nil, "cold" end
	local url = tostring(gate.link):gsub("/+$", "") .. "/" .. manifest
	local ok, raw = pcall(curl.downloadString, url, timeout)
	if not ok then Ukaku.scar(gate.mark, "err"); return nil, "err" end
	local code = Ukaku.sift(raw, manifest)
	if code == nil then
		local reason = "bad"
		if raw == nil or raw == "" then reason = "empty" end
		Ukaku.scar(gate.mark, reason)
		return nil, reason
	end
	Ukaku.frost[gate.mark] = nil
	return code, "ok"
end

Ukaku.seek = function(id)
	if id == nil then return nil end
	local manifest = Ukaku.echo(id)
	if manifest == "0" then return nil end
	Ukaku.shed()
	local now = os.time()
	local hit = Ukaku.vault[manifest]
	if hit ~= nil and now - (hit.t or 0) < Ukaku.life then
		return ffi.C.strtoull(hit.v, ffi.cast("char*", 0), 10)
	end
	local untilTime = Ukaku.cage[manifest]
	if untilTime ~= nil and untilTime > now then return nil end
	local deadline = now + Ukaku.span
	local notes = {}
	for _, gate in ipairs(Ukaku.gates) do
		local left = deadline - os.time()
		if left < 1 then
			notes[#notes + 1] = gate.mark .. "=none"
		else
			local timeout = math.max(1, math.min(gate.timeout or Ukaku.pulse, left))
			local code, reason = Ukaku.torch(gate, manifest, timeout)
			notes[#notes + 1] = gate.mark .. "=" .. reason
			if code ~= nil then
				Ukaku.vault[manifest] = { v = code, t = os.time() }
				Ukaku.cage[manifest] = nil
				return ffi.C.strtoull(code, ffi.cast("char*", 0), 10)
			end
		end
	end
	Ukaku.cage[manifest] = os.time() + Ukaku.cool
	return nil
end

Ukaku.talon = ffi.cast("H3", function(a, app, depot, manifest, branch, out)
	local ok = false
	return Ukaku.shield("M", function() return ok end, function()
		ok = Ukaku.manifestTramp(a, app, depot, manifest, branch, out)
		if out[0] ~= ffi.cast("uint64_t", 0) then return ok end
		local code = Ukaku.seek(manifest)
		if code == nil then return ok end
		out[0] = code
		return true
	end)
end)

Ukaku.packageHook = LuaHook("GetPackage", packageAddr)
Ukaku.packageTramp = ffi.cast("H1", ffi.C.place_lua_hook(Ukaku.packageHook.index, Ukaku.claw))
Ukaku.binaryHook = LuaHook("GetBinary", storeTable.ptr)
Ukaku.binaryTramp = ffi.cast("H2", ffi.C.place_lua_hook(Ukaku.binaryHook.index, Ukaku.fang))
Ukaku.manifestHook = LuaHook("GetManifestRequestCode", manifestAddr)
Ukaku.manifestTramp = ffi.cast("H3", ffi.C.place_lua_hook(Ukaku.manifestHook.index, Ukaku.talon))

Ukaku.configured = function()
	Ukaku.purge()
	Ukaku.wards = SLS.config:getIntList("AdditionalDepots")
	Ukaku.forge = true
	local node = SLS.config:getNode("DecryptionKeys")
	if not node.isDefined then return end
	for _, pair in pairs(node:asPairList()) do
		Ukaku.cells[pair[1]:asInt()] = pair[2]:asString()
	end
end

Ukaku.reloaded = function() Ukaku.purge(); Ukaku.wash(); Ukaku.graft() end
SLS.registerCallback("SLSsteam::configLoaded", Ukaku.configured)
SLS.registerCallback("SLSsteam::luaReload", Ukaku.reloaded)
Kagune.ukaku = true
log.notify("Ukaku: loaded")
