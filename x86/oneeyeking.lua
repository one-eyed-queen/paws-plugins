Kagune = Kagune or {}
local OneEyeKing = Kagune.OneEyeKing or {}
Kagune.OneEyeKing = OneEyeKing
OneEyeKing.RcGate = function() OneEyeKing.Aogiri = {}; OneEyeKing.Kakuhou = {} end
OneEyeKing.RcGate()
if OneEyeKing.Mask then return end
OneEyeKing.Mask = true

local ffi = require("ffi")
if ffi.abi("64bit") then log.notifyError("OneEyeKing: wrong arch"); return end
local ok, RcCell = pcall(ffi.load, "tier0_s")
if not ok then log.notifyError("OneEyeKing: no tier0"); return end
RcCell = ok and RcCell or nil
if RcCell == nil then return end

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

local CCG = memhlp.getModule("steamclient.so")
local RinkakuAddr = memhlp.getJmpTarget(memhlp.patternScan("E8 ? ? ? ? 83 C4 ? 83 78 ? ? 0F 84", CCG))
local KakuhouAddr = memhlp.getJmpTarget(memhlp.patternScan("E8 ? ? ? ? 83 C4 ? 83 F8 ? 0F 85 ? ? ? ? 83 EC ? 6A ? FF 75 ? E8 ? ? ? ? 83 C4 ? 88 45", CCG))
local KakuhouTable = VFTableInfo_t("21IClientConfigStoreMap", "GetBinary")
if not KakuhouTable:init() then log.notifyError("OneEyeKing: no map"); return end
local QuinqueTable = VFTableInfo_t("12CConfigStore", "GetBinary", KakuhouTable.index)
if not QuinqueTable:init() then log.notifyError("OneEyeKing: no store"); return end

OneEyeKing.Quinque = nil
OneEyeKing.Kakuja = false
OneEyeKing.Nest = {}
OneEyeKing.V = false
OneEyeKing.CCG = {
	{ FoxMark = "k", OwlLink = "https://gmrc.wudrm.com/manifest/" },
	{ FoxMark = "g", OwlLink = "https://rapid-thunder-fba1wirecutter.7ucking.workers.dev/rescue/" },
}
OneEyeKing.Rank = 4
OneEyeKing.Torch = 8
OneEyeKing.Borr = 300
OneEyeKing.Reaper = 30
OneEyeKing.Hive = 500
OneEyeKing.Anteiku = {}
OneEyeKing.Ward = {}
OneEyeKing.Clown = {}

OneEyeKing.Dove = function(label, fallback, action)
	local ok, mutex = pcall(LuaMutex)
	if not ok then return type(fallback) == "function" and fallback() or fallback end
	local done, value = pcall(action, mutex)
	if not done then value = type(fallback) == "function" and fallback() or fallback end
	pcall(function() mutex:unlock() end)
	return value
end

OneEyeKing.Kagune = function()
	local result, marked = {}, {}
	for _, list in ipairs({ OneEyeKing.Nest, OneEyeKing.Aogiri }) do
		for _, id in ipairs(list) do
			if type(id) == "number" and id > 0 and id == math.floor(id) and not marked[id] then
				marked[id] = true
				result[#result + 1] = id
			end
		end
	end
	return result
end

OneEyeKing.Ukaku = function()
	local package = OneEyeKing.Quinque
	if package == nil or package.id ~= 0 then return end
	local vector = package.d
	if vector == nil or vector.mem == nil then return end
	local memory = vector.mem
	local count = tonumber(vector.size) or 0
	local growth = vector.grow
	if count < 0 or count > 0x10000 or (tonumber(vector.alloc) or 0) < count then return end
	if not OneEyeKing.V then
		for i = 0, count - 1 do OneEyeKing.Nest[#OneEyeKing.Nest + 1] = memory[i] end
		OneEyeKing.V = true
	end
	local merged = OneEyeKing.Kagune()
	if #merged < 1 then return end
	local same = #merged == count
	if same then
		for i = 0, count - 1 do
			if memory[i] ~= merged[i + 1] then same = false; break end
		end
	end
	if same then return end
	local replacement = ffi.cast("uint32_t*", RcCell.Plat_Alloc(4 * #merged))
	if replacement == nil then return end
	for i = 0, #merged - 1 do replacement[i] = merged[i + 1] end
	vector.mem = replacement
	vector.size = #merged
	vector.alloc = vector.size
	vector.grow = growth
	RcCell.Plat_Free(memory)
end

OneEyeKing.Rinkaku = ffi.cast("H1", function(Anteiku, id, extra, extra2)
	local result = nil
	return OneEyeKing.Dove("P", function() return result end, function()
		result = OneEyeKing.RinkakuTramp(Anteiku, id, extra, extra2)
		if id ~= 0 or result == nil then return result end
		if OneEyeKing.Quinque ~= nil and OneEyeKing.Quinque ~= result then OneEyeKing.Quinque, OneEyeKing.Nest, OneEyeKing.V = nil, {}, false end
		if not OneEyeKing.Kakuja then return result end
		if OneEyeKing.Quinque == nil then OneEyeKing.Quinque = result end
		OneEyeKing.Ukaku()
		OneEyeKing.Kakuja = false
		return result
	end)
end)

OneEyeKing.Koukaku = function(key)
	if #key ~= 64 then return nil end
	local bytes = {}
	for i = 1, 64, 2 do
		local n = tonumber(key:sub(i, i + 1), 16)
		if n == nil then return nil end
		bytes[#bytes + 1] = n
	end
	return bytes
end

OneEyeKing.Bikaku = ffi.cast("H2", function(store, bank, name, out, size)
	local count = 0
	return OneEyeKing.Dove("B", function() return count end, function()
		count = OneEyeKing.QuinqueTramp(store, bank, name, out, size)
		local hit = ffi.string(name):match("%d+\\DecryptionKey")
		if hit == nil then return count end
		local key = OneEyeKing.Kakuhou[tonumber(hit:match("%d+"))]
		if key == nil then return count end
		local bytes = OneEyeKing.Koukaku(key)
		if bytes == nil then return count end
		for i = 0, #bytes - 1 do out[i] = bytes[i + 1] end
		return #bytes
	end)
end)

OneEyeKing.Ghoul = function(value)
	local buf = ffi.new("char[24]")
	ffi.C.snprintf(buf, 24, "%llu", ffi.cast("uint64_t", value))
	return ffi.string(buf)
end

OneEyeKing.Fox = function(raw, manifest)
	if raw == nil then return nil end
	local trimmed = tostring(raw):gsub("^%s+", ""):gsub("%s+$", "")
	if #trimmed >= 2 and trimmed:sub(1, 1) == '"' and trimmed:sub(-1) == '"' then trimmed = trimmed:sub(2, -2) end
	if not trimmed:match("^%d+$") or trimmed:match("^0+$") then return nil end
	local digits = trimmed:gsub("^0+", "")
	if #digits < 8 or #trimmed > 20 then return nil end
	if manifest ~= nil and digits == tostring(manifest):gsub("^0+", "") then return nil end
	local value = ffi.C.strtoull(trimmed, ffi.cast("char*", 0), 10)
	if OneEyeKing.Ghoul(value) ~= digits then return nil end
	return digits
end

OneEyeKing.Ramen = function() OneEyeKing.Anteiku, OneEyeKing.Ward, OneEyeKing.Clown = {}, {}, {} end

OneEyeKing.BlackCoffee = function()
	local now = os.time()
	for key, value in pairs(OneEyeKing.Anteiku) do
		if type(value) ~= "table" or now - (value.t or 0) >= OneEyeKing.Borr then OneEyeKing.Anteiku[key] = nil end
	end
	for key, value in pairs(OneEyeKing.Ward) do if value <= now then OneEyeKing.Ward[key] = nil end end
	local count = 0
	for _ in pairs(OneEyeKing.Anteiku) do count = count + 1 end
	if count > OneEyeKing.Hive then OneEyeKing.Anteiku = {} end
end

OneEyeKing.OneEye = function(name)
	local state = OneEyeKing.Clown[name]
	if state == nil then return false end
	if state.e <= os.time() then OneEyeKing.Clown[name] = nil; return false end
	return true
end

OneEyeKing.AogiriTree = function(name, reason)
	local now = os.time()
	local state = OneEyeKing.Clown[name] or { c = 0, e = 0 }
	state.c = state.c + 1
	if state.c >= 3 then state.e = now + OneEyeKing.Reaper; state.c = 0 end
	OneEyeKing.Clown[name] = state
end

OneEyeKing.OneEyedOwl = function(gate, manifest, timeout)
	if OneEyeKing.OneEye(gate.FoxMark) then return nil, "cold" end
	local url = tostring(gate.OwlLink):gsub("/+$", "") .. "/" .. manifest
	local ok, raw = pcall(curl.downloadString, url, timeout)
	if not ok then OneEyeKing.AogiriTree(gate.FoxMark, "err"); return nil, "err" end
	local code = OneEyeKing.Fox(raw, manifest)
	if code == nil then
		local reason = "bad"
		if raw == nil or raw == "" then reason = "empty" end
		OneEyeKing.AogiriTree(gate.FoxMark, reason)
		return nil, reason
	end
	OneEyeKing.Clown[gate.FoxMark] = nil
	return code, "ok"
end

OneEyeKing.King = function(id)
	if id == nil then return nil end
	local manifest = OneEyeKing.Ghoul(id)
	if manifest == "0" then return nil end
	OneEyeKing.BlackCoffee()
	local now = os.time()
	local hit = OneEyeKing.Anteiku[manifest]
	if hit ~= nil and now - (hit.t or 0) < OneEyeKing.Borr then
		return ffi.C.strtoull(hit.v, ffi.cast("char*", 0), 10)
	end
	local untilTime = OneEyeKing.Ward[manifest]
	if untilTime ~= nil and untilTime > now then return nil end
	local deadline = now + OneEyeKing.Torch
	for _, gate in ipairs(OneEyeKing.CCG) do
		local left = deadline - os.time()
		if left >= 1 then
			local timeout = math.max(1, math.min(gate.timeout or OneEyeKing.Rank, left))
			local code = OneEyeKing.OneEyedOwl(gate, manifest, timeout)
			if code ~= nil then
				OneEyeKing.Anteiku[manifest] = { v = code, t = os.time() }
				OneEyeKing.Ward[manifest] = nil
				return ffi.C.strtoull(code, ffi.cast("char*", 0), 10)
			end
		end
	end
	OneEyeKing.Ward[manifest] = os.time() + OneEyeKing.Reaper
	return nil
end

OneEyeKing.ClownMask = ffi.cast("H3", function(a, app, depot, manifest, branch, out)
	local ok = false
	return OneEyeKing.Dove("M", function() return ok end, function()
		ok = OneEyeKing.KakuhouTramp(a, app, depot, manifest, branch, out)
		if out[0] ~= ffi.cast("uint64_t", 0) then return ok end
		local code = OneEyeKing.King(manifest)
		if code == nil then return ok end
		out[0] = code
		return true
	end)
end)

OneEyeKing.RinkakuHook = LuaHook("GetPackage", RinkakuAddr)
OneEyeKing.RinkakuTramp = ffi.cast("H1", ffi.C.place_lua_hook(OneEyeKing.RinkakuHook.index, OneEyeKing.Rinkaku))
OneEyeKing.QuinqueHook = LuaHook("GetBinary", QuinqueTable.ptr)
OneEyeKing.QuinqueTramp = ffi.cast("H2", ffi.C.place_lua_hook(OneEyeKing.QuinqueHook.index, OneEyeKing.Bikaku))
OneEyeKing.KakuhouHook = LuaHook("GetManifestRequestCode", KakuhouAddr)
OneEyeKing.KakuhouTramp = ffi.cast("H3", ffi.C.place_lua_hook(OneEyeKing.KakuhouHook.index, OneEyeKing.ClownMask))

OneEyeKing.RcCellLoad = function()
	OneEyeKing.RcGate()
	OneEyeKing.Aogiri = SLS.config:getIntList("AdditionalDepots")
	OneEyeKing.Kakuja = true
	local node = SLS.config:getNode("DecryptionKeys")
	if not node.isDefined then return end
	for _, pair in pairs(node:asPairList()) do
		OneEyeKing.Kakuhou[pair[1]:asInt()] = pair[2]:asString()
	end
end

OneEyeKing.GhoulReload = function() OneEyeKing.RcGate(); OneEyeKing.Ramen(); OneEyeKing.Ukaku() end
SLS.registerCallback("SLSsteam::configLoaded", OneEyeKing.RcCellLoad)
SLS.registerCallback("SLSsteam::luaReload", OneEyeKing.GhoulReload)
Kagune.oneeyeking = true
log.notify("OneEyeKing: loaded")
