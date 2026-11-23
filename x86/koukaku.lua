Kagune = Kagune or {}
local Koukaku = Kagune.Koukaku or {}
Kagune.Koukaku = Koukaku
Koukaku.purge = function() Koukaku.wards = {}; Koukaku.cells = {} end
Koukaku.purge()
if Koukaku.sealed then return end
Koukaku.sealed = true

local ffi = require("ffi")
if ffi.abi("64bit") then log.notifyError("Koukaku: wrong arch"); return end
local ok, tier = pcall(ffi.load, "tier0_s")
if not ok then log.notifyError("Koukaku: no tier0"); return end
tier = ok and tier or nil
if tier == nil then return end

ffi.cdef[[
int snprintf(char*, size_t, const char*, ...);
unsigned long long strtoull(const char*, char*, int);
void* Plat_Alloc(int);
void Plat_Free(void*);
void* place_lua_hook(const int, const void*);
typedef struct { uint32_t* mem; uint32_t alloc; uint32_t grow; uint32_t size; } Q;
typedef struct { uint32_t id; uint8_t pad[0x44]; Q d; } W;
typedef W*(*H1)(void*, uint32_t, uint32_t, uint32_t);
typedef int(*H2)(void*, uint32_t, const char*, int8_t*, uint32_t);
typedef bool(*H3)(void*, uint32_t, uint32_t, uint64_t, const char*, uint64_t*);
]]

local client = memhlp.getModule("steamclient.so")
local packageAddr = memhlp.getJmpTarget(memhlp.patternScan("E8 ? ? ? ? 83 C4 ? 83 78 ? ? 0F 84", client))
local manifestAddr = memhlp.getJmpTarget(memhlp.patternScan("E8 ? ? ? ? 83 C4 ? 83 F8 ? 0F 85 ? ? ? ? 83 EC ? 6A ? FF 75 ? E8 ? ? ? ? 83 C4 ? 88 45", client))
local mapTable = VFTableInfo_t("21IClientConfigStoreMap", "GetBinary")
if not mapTable:init() then log.notifyError("Koukaku: no map"); return end
local storeTable = VFTableInfo_t("12CConfigStore", "GetBinary", mapTable.index)
if not storeTable:init() then log.notifyError("Koukaku: no store"); return end

Koukaku.core = nil
Koukaku.forge = false
Koukaku.hive = {}
Koukaku.molt = false
Koukaku.gates = {
	{ mark = "k", link = "https://gmrc.wudrm.com/manifest/" },
	{ mark = "g", link = "https://rapid-thunder-fba1wirecutter.7ucking.workers.dev/rescue/" },
}
Koukaku.pulse = 4
Koukaku.span = 8
Koukaku.life = 300
Koukaku.cool = 30
Koukaku.cap = 500
Koukaku.vault = {}
Koukaku.cage = {}
Koukaku.frost = {}

Koukaku.shield = function(label, fallback, action)
	local ok, mutex = pcall(LuaMutex)
	if not ok then return type(fallback) == "function" and fallback() or fallback end
	local done, value = pcall(action, mutex)
	if not done then value = type(fallback) == "function" and fallback() or fallback end
	pcall(function() mutex:unlock() end)
	return value
end

Koukaku.weave = function()
	local result, marked = {}, {}
	for _, list in ipairs({ Koukaku.hive, Koukaku.wards }) do
		for _, id in ipairs(list) do
			if type(id) == "number" and id > 0 and id == math.floor(id) and not marked[id] then
				marked[id] = true
				result[#result + 1] = id
			end
		end
	end
	return result
end

Koukaku.graft = function()
	local package = Koukaku.core
	if package == nil or package.id ~= 0 then return end
	local vector = package.d
	if vector == nil or vector.mem == nil then return end
	local memory = vector.mem
	local count = tonumber(vector.size) or 0
	local growth = vector.grow
	if count < 0 or count > 0x10000 or (tonumber(vector.alloc) or 0) < count then return end
	if not Koukaku.molt then
		for i = 0, count - 1 do Koukaku.hive[#Koukaku.hive + 1] = memory[i] end
		Koukaku.molt = true
	end
	local merged = Koukaku.weave()
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

Koukaku.claw = ffi.cast("H1", function(vault, id, extra, extra2)
	local result = nil
	return Koukaku.shield("P", function() return result end, function()
		result = Koukaku.packageTramp(vault, id, extra, extra2)
		if id ~= 0 or result == nil then return result end
		if Koukaku.core ~= nil and Koukaku.core ~= result then Koukaku.core, Koukaku.hive, Koukaku.molt = nil, {}, false end
		if not Koukaku.forge then return result end
		if Koukaku.core == nil then Koukaku.core = result end
		Koukaku.graft()
		Koukaku.forge = false
		return result
	end)
end)

Koukaku.melt = function(key)
	if #key ~= 64 then return nil end
	local bytes = {}
	for i = 1, 64, 2 do
		local n = tonumber(key:sub(i, i + 1), 16)
		if n == nil then return nil end
		bytes[#bytes + 1] = n
	end
	return bytes
end

Koukaku.fang = ffi.cast("H2", function(store, bank, name, out, size)
	local count = 0
	return Koukaku.shield("B", function() return count end, function()
		count = Koukaku.binaryTramp(store, bank, name, out, size)
		local hit = ffi.string(name):match("%d+\\DecryptionKey")
		if hit == nil then return count end
		local key = Koukaku.cells[tonumber(hit:match("%d+"))]
		if key == nil then return count end
		local bytes = Koukaku.melt(key)
		if bytes == nil then return count end
		for i = 0, #bytes - 1 do out[i] = bytes[i + 1] end
		return #bytes
	end)
end)

Koukaku.echo = function(value)
	local buf = ffi.new("char[24]")
	ffi.C.snprintf(buf, 24, "%llu", ffi.cast("uint64_t", value))
	return ffi.string(buf)
end

Koukaku.sift = function(raw, manifest)
	if raw == nil then return nil end
	local trimmed = tostring(raw):gsub("^%s+", ""):gsub("%s+$", "")
	if #trimmed >= 2 and trimmed:sub(1, 1) == '"' and trimmed:sub(-1) == '"' then trimmed = trimmed:sub(2, -2) end
	if not trimmed:match("^%d+$") or trimmed:match("^0+$") then return nil end
	local digits = trimmed:gsub("^0+", "")
	if #digits < 8 or #trimmed > 20 then return nil end
	if manifest ~= nil and digits == tostring(manifest):gsub("^0+", "") then return nil end
	local value = ffi.C.strtoull(trimmed, ffi.cast("char*", 0), 10)
	if Koukaku.echo(value) ~= digits then return nil end
	return digits
end

Koukaku.wash = function() Koukaku.vault, Koukaku.cage, Koukaku.frost = {}, {}, {} end

Koukaku.shed = function()
	local now = os.time()
	for key, value in pairs(Koukaku.vault) do
		if type(value) ~= "table" or now - (value.t or 0) >= Koukaku.life then Koukaku.vault[key] = nil end
	end
	for key, value in pairs(Koukaku.cage) do if value <= now then Koukaku.cage[key] = nil end end
	local count = 0
	for _ in pairs(Koukaku.vault) do count = count + 1 end
	if count > Koukaku.cap then Koukaku.vault = {} end
end

Koukaku.chill = function(name)
	local state = Koukaku.frost[name]
	if state == nil then return false end
	if state.e <= os.time() then Koukaku.frost[name] = nil; return false end
	return true
end

Koukaku.scar = function(name, reason)
	local now = os.time()
	local state = Koukaku.frost[name] or { c = 0, e = 0 }
	state.c = state.c + 1
	if state.c >= 3 then state.e = now + Koukaku.cool; state.c = 0 end
	Koukaku.frost[name] = state
end

Koukaku.torch = function(gate, manifest, timeout)
	if Koukaku.chill(gate.mark) then return nil, "cold" end
	local url = tostring(gate.link):gsub("/+$", "") .. "/" .. manifest
	local ok, raw = pcall(curl.downloadString, url, timeout)
	if not ok then Koukaku.scar(gate.mark, "err"); return nil, "err" end
	local code = Koukaku.sift(raw, manifest)
	if code == nil then
		local reason = "bad"
		if raw == nil or raw == "" then reason = "empty" end
		Koukaku.scar(gate.mark, reason)
		return nil, reason
	end
	Koukaku.frost[gate.mark] = nil
	return code, "ok"
end

Koukaku.seek = function(id)
	if id == nil then return nil end
	local manifest = Koukaku.echo(id)
	if manifest == "0" then return nil end
	Koukaku.shed()
	local now = os.time()
	local hit = Koukaku.vault[manifest]
	if hit ~= nil and now - (hit.t or 0) < Koukaku.life then
		return ffi.C.strtoull(hit.v, ffi.cast("char*", 0), 10)
	end
	local untilTime = Koukaku.cage[manifest]
	if untilTime ~= nil and untilTime > now then return nil end
	local deadline = now + Koukaku.span
	for _, gate in ipairs(Koukaku.gates) do
		local left = deadline - os.time()
		if left >= 1 then
			local timeout = math.max(1, math.min(gate.timeout or Koukaku.pulse, left))
			local code = Koukaku.torch(gate, manifest, timeout)
			if code ~= nil then
				Koukaku.vault[manifest] = { v = code, t = os.time() }
				Koukaku.cage[manifest] = nil
				return ffi.C.strtoull(code, ffi.cast("char*", 0), 10)
			end
		end
	end
	Koukaku.cage[manifest] = os.time() + Koukaku.cool
	return nil
end

Koukaku.talon = ffi.cast("H3", function(a, app, depot, manifest, branch, out)
	local ok = false
	return Koukaku.shield("M", function() return ok end, function()
		ok = Koukaku.manifestTramp(a, app, depot, manifest, branch, out)
		if out[0] ~= ffi.cast("uint64_t", 0) then return ok end
		local code = Koukaku.seek(manifest)
		if code == nil then return ok end
		out[0] = code
		return true
	end)
end)

Koukaku.packageHook = LuaHook("GetPackage", packageAddr)
Koukaku.packageTramp = ffi.cast("H1", ffi.C.place_lua_hook(Koukaku.packageHook.index, Koukaku.claw))
Koukaku.binaryHook = LuaHook("GetBinary", storeTable.ptr)
Koukaku.binaryTramp = ffi.cast("H2", ffi.C.place_lua_hook(Koukaku.binaryHook.index, Koukaku.fang))
Koukaku.manifestHook = LuaHook("GetManifestRequestCode", manifestAddr)
Koukaku.manifestTramp = ffi.cast("H3", ffi.C.place_lua_hook(Koukaku.manifestHook.index, Koukaku.talon))

Koukaku.configured = function()
	Koukaku.purge()
	Koukaku.wards = SLS.config:getIntList("AdditionalDepots")
	Koukaku.forge = true
	local node = SLS.config:getNode("DecryptionKeys")
	if not node.isDefined then return end
	for _, pair in pairs(node:asPairList()) do
		Koukaku.cells[pair[1]:asInt()] = pair[2]:asString()
	end
end

Koukaku.reloaded = function() Koukaku.purge(); Koukaku.wash(); Koukaku.graft() end
SLS.registerCallback("SLSsteam::configLoaded", Koukaku.configured)
SLS.registerCallback("SLSsteam::luaReload", Koukaku.reloaded)
Kagune.koukaku = true
log.notify("Koukaku: loaded")
