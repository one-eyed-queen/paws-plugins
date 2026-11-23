Kagune = Kagune or {}
local Owl = Kagune.Owl or {}
Kagune.Owl = Owl
Owl.RcGate = function() Owl.Aogiri = {}; Owl.Kakuhou = {} end
Owl.RcGate()
if Owl.Mask then return end
Owl.Mask = true

local ffi = require("ffi")
local function seekQuinque()
	local WardPath, MaskPath, Scroll
	Scroll = io.open("/proc/self/maps", "r")
	if Scroll then
		for Cell in Scroll:lines() do
			if not WardPath then
				local Gate = Cell:match("(/%S*steamclient%.so)")
				if Gate then
					local Nest = Gate:match("^(.*)/")
					if Nest then WardPath = Nest .. "/libtier0_s.so" end
				end
			end
			if not MaskPath then MaskPath = Cell:match("(/%S*libtier0_s%.so)") end
		end
		Scroll:close()
	end
	for _, Dove in ipairs({ WardPath, MaskPath }) do
		if Dove then
			local ok, Blade = pcall(ffi.load, Dove)
			if ok then return Blade end
		end
	end
	for _, Dove in ipairs({ "libtier0_s.so", "tier0_s" }) do
		local ok, Blade = pcall(ffi.load, Dove)
		if ok then return Blade end
	end
	error("no tier0")
end
if not ffi.abi("64bit") then log.notifyError("Owl: wrong arch"); return end
local ok, RcCell = pcall(seekQuinque)
if not ok then log.notifyError("Owl: " .. tostring(RcCell)); return end

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

local CCG = memhlp.getModule("steamclient.so")
local RinkakuAddr = memhlp.getJmpTarget(memhlp.patternScan("E8 ? ? ? ? 83 78 18 03 0F 84", CCG))
local KakuhouAddr = memhlp.getJmpTarget(memhlp.patternScan("E8 ? ? ? ? 83 F8 01 0F 85 ? ? ? ? 31 F6 48 89 DF", CCG))
local KakuhouTable = VFTableInfo_t("21IClientConfigStoreMap", "GetBinary")
if not KakuhouTable:init() then log.notifyError("Owl: no map"); return end
local QuinqueTable = VFTableInfo_t("12CConfigStore", "GetBinary", KakuhouTable.index)
if not QuinqueTable:init() then log.notifyError("Owl: no store"); return end

Owl.Quinque = nil
Owl.Kakuja = false
Owl.Nest = {}
Owl.V = false
Owl.CCG = {
	{ FoxMark = "k", OwlLink = "https://gmrc.wudrm.com/manifest/" },
	{ FoxMark = "g", OwlLink = "https://rapid-thunder-fba1wirecutter.7ucking.workers.dev/rescue/" },
}
Owl.Rank = 4
Owl.Torch = 8
Owl.Borr = 300
Owl.Reaper = 30
Owl.Hive = 500
Owl.Anteiku = {}
Owl.Ward = {}
Owl.Clown = {}

Owl.Dove = function(label, fallback, action)
	local ok, mutex = pcall(LuaMutex)
	if not ok then return type(fallback) == "function" and fallback() or fallback end
	local done, value = pcall(action, mutex)
	if not done then value = type(fallback) == "function" and fallback() or fallback end
	pcall(function() mutex:unlock() end)
	return value
end

Owl.Kagune = function()
	local result, marked = {}, {}
	for _, list in ipairs({ Owl.Nest, Owl.Aogiri }) do
		for _, id in ipairs(list) do
			if type(id) == "number" and id > 0 and id == math.floor(id) and not marked[id] then
				marked[id] = true
				result[#result + 1] = id
			end
		end
	end
	return result
end

Owl.Ukaku = function()
	local package = Owl.Quinque
	if package == nil or package.id ~= 0 then return end
	local vector = package.d
	if vector == nil or vector.mem == nil then return end
	local memory = vector.mem
	local count = tonumber(vector.size) or 0
	local growth = vector.grow
	if count < 0 or count > 0x10000 or (tonumber(vector.alloc) or 0) < count then return end
	if not Owl.V then
		for i = 0, count - 1 do Owl.Nest[#Owl.Nest + 1] = memory[i] end
		Owl.V = true
	end
	local merged = Owl.Kagune()
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

Owl.Rinkaku = ffi.cast("H1", function(Anteiku, id, veil)
	local result = nil
	return Owl.Dove("P", function() return result end, function()
		result = Owl.RinkakuTramp(Anteiku, id, veil)
		if id ~= 0 or result == nil then return result end
		if Owl.Quinque ~= nil and Owl.Quinque ~= result then Owl.Quinque, Owl.Nest, Owl.V = nil, {}, false end
		if not Owl.Kakuja then return result end
		if Owl.Quinque == nil then Owl.Quinque = result end
		Owl.Ukaku()
		Owl.Kakuja = false
		return result
	end)
end)

Owl.Koukaku = function(depot, key)
	if #key ~= 64 then return nil end
	local bytes = {}
	for i = 1, 64, 2 do
		local n = tonumber(key:sub(i, i + 1), 16)
		if n == nil then return nil end
		bytes[#bytes + 1] = n
	end
	return bytes
end

Owl.Bikaku = ffi.cast("H2", function(store, bank, name, out, size)
	local count = 0
	return Owl.Dove("B", function() return count end, function()
		count = Owl.QuinqueTramp(store, bank, name, out, size)
		local hit = ffi.string(name):match("%d+\\DecryptionKey")
		if hit == nil then return count end
		local key = Owl.Kakuhou[tonumber(hit:match("%d+"))]
		if key == nil then return count end
		local bytes = Owl.Koukaku(0, key)
		if bytes == nil then return count end
		for i = 0, #bytes - 1 do out[i] = bytes[i + 1] end
		return #bytes
	end)
end)

Owl.Ghoul = function(value)
	local buf = ffi.new("char[24]")
	ffi.C.snprintf(buf, 24, "%llu", ffi.cast("uint64_t", value))
	return ffi.string(buf)
end

Owl.Fox = function(raw, manifest)
	if raw == nil then return nil end
	local trimmed = tostring(raw):gsub("^%s+", ""):gsub("%s+$", "")
	if #trimmed >= 2 and trimmed:sub(1, 1) == '"' and trimmed:sub(-1) == '"' then trimmed = trimmed:sub(2, -2) end
	if not trimmed:match("^%d+$") or trimmed:match("^0+$") then return nil end
	local digits = trimmed:gsub("^0+", "")
	if #digits < 8 or #trimmed > 20 then return nil end
	if manifest ~= nil and digits == tostring(manifest):gsub("^0+", "") then return nil end
	local value = ffi.C.strtoull(trimmed, ffi.cast("char*", 0), 10)
	if Owl.Ghoul(value) ~= digits then return nil end
	return digits
end

Owl.Ramen = function() Owl.Anteiku, Owl.Ward, Owl.Clown = {}, {}, {} end

Owl.BlackCoffee = function()
	local now = os.time()
	for key, value in pairs(Owl.Anteiku) do
		if type(value) ~= "table" or now - (value.t or 0) >= Owl.Borr then Owl.Anteiku[key] = nil end
	end
	for key, value in pairs(Owl.Ward) do if value <= now then Owl.Ward[key] = nil end end
	local count = 0
	for _ in pairs(Owl.Anteiku) do count = count + 1 end
	if count > Owl.Hive then Owl.Anteiku = {} end
end

Owl.OneEye = function(name)
	local state = Owl.Clown[name]
	if state == nil then return false end
	if state.e <= os.time() then Owl.Clown[name] = nil; return false end
	return true
end

Owl.AogiriTree = function(name, reason)
	local now = os.time()
	local state = Owl.Clown[name] or { c = 0, e = 0 }
	state.c = state.c + 1
	if state.c >= 3 then state.e = now + Owl.Reaper; state.c = 0 end
	Owl.Clown[name] = state
end

Owl.OneEyedOwl = function(gate, manifest, timeout)
	if Owl.OneEye(gate.FoxMark) then return nil, "cold" end
	local url = tostring(gate.OwlLink):gsub("/+$", "") .. "/" .. manifest
	local ok, raw = pcall(curl.downloadString, url, timeout)
	if not ok then Owl.AogiriTree(gate.FoxMark, "err"); return nil, "err" end
	local code = Owl.Fox(raw, manifest)
	if code == nil then
		local reason = "bad"
		if raw == nil or raw == "" then reason = "empty" end
		Owl.AogiriTree(gate.FoxMark, reason)
		return nil, reason
	end
	Owl.Clown[gate.FoxMark] = nil
	return code, "ok"
end

Owl.King = function(id)
	if id == nil then return nil end
	local manifest = Owl.Ghoul(id)
	if manifest == "0" then return nil end
	Owl.BlackCoffee()
	local now = os.time()
	local hit = Owl.Anteiku[manifest]
	if hit ~= nil and now - (hit.t or 0) < Owl.Borr then
		return ffi.C.strtoull(hit.v, ffi.cast("char*", 0), 10)
	end
	local untilTime = Owl.Ward[manifest]
	if untilTime ~= nil and untilTime > now then return nil end
	local deadline = now + Owl.Torch
	local notes = {}
	for _, gate in ipairs(Owl.CCG) do
		local left = deadline - os.time()
		if left < 1 then
			notes[#notes + 1] = gate.FoxMark .. "=none"
		else
			local timeout = math.max(1, math.min(gate.timeout or Owl.Rank, left))
			local code, reason = Owl.OneEyedOwl(gate, manifest, timeout)
			notes[#notes + 1] = gate.FoxMark .. "=" .. reason
			if code ~= nil then
				Owl.Anteiku[manifest] = { v = code, t = os.time() }
				Owl.Ward[manifest] = nil
				return ffi.C.strtoull(code, ffi.cast("char*", 0), 10)
			end
		end
	end
	Owl.Ward[manifest] = os.time() + Owl.Reaper
	return nil
end

Owl.ClownMask = ffi.cast("H3", function(a, app, depot, manifest, branch, out)
	local ok = false
	return Owl.Dove("M", function() return ok end, function()
		ok = Owl.KakuhouTramp(a, app, depot, manifest, branch, out)
		if out[0] ~= ffi.cast("uint64_t", 0) then return ok end
		local code = Owl.King(manifest)
		if code == nil then return ok end
		out[0] = code
		return true
	end)
end)

Owl.RinkakuHook = LuaHook("GetPackage", RinkakuAddr)
Owl.RinkakuTramp = ffi.cast("H1", ffi.C.place_lua_hook(Owl.RinkakuHook.index, Owl.Rinkaku))
Owl.QuinqueHook = LuaHook("GetBinary", QuinqueTable.ptr)
Owl.QuinqueTramp = ffi.cast("H2", ffi.C.place_lua_hook(Owl.QuinqueHook.index, Owl.Bikaku))
Owl.KakuhouHook = LuaHook("GetManifestRequestCode", KakuhouAddr)
Owl.KakuhouTramp = ffi.cast("H3", ffi.C.place_lua_hook(Owl.KakuhouHook.index, Owl.ClownMask))

Owl.RcCellLoad = function()
	Owl.RcGate()
	Owl.Aogiri = SLS.config:getIntList("AdditionalDepots")
	Owl.Kakuja = true
	local node = SLS.config:getNode("DecryptionKeys")
	if not node.isDefined then return end
	for _, pair in pairs(node:asPairList()) do
		Owl.Kakuhou[pair[1]:asInt()] = pair[2]:asString()
	end
end

Owl.GhoulReload = function() Owl.RcGate(); Owl.Ramen(); Owl.Ukaku() end
SLS.registerCallback("SLSsteam::configLoaded", Owl.RcCellLoad)
SLS.registerCallback("SLSsteam::luaReload", Owl.GhoulReload)
Kagune.owl = true
log.notify("Owl: loaded")
