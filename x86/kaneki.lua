Kaneki = Kaneki or {}
local R = Kaneki.Ken or {}
Kaneki.Ken = R
R.r = function() R.z = {}; R.aa = {} end
R.r()
if R.u then return end
R.u = true

local f = require("ffi")
if f.abi("64bit") then log.notifyError("Ken: wrong arch"); return end
local ok, t = pcall(f.load, "tier0_s")
if not ok then log.notifyError("Ken: no tier0"); return end
t = ok and t or nil
if t == nil then return end

f.cdef[[
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

local c = memhlp.getModule("steamclient.so")
local a1 = memhlp.getJmpTarget(memhlp.patternScan("E8 ? ? ? ? 83 C4 ? 83 78 ? ? 0F 84", c))
local a2 = memhlp.getJmpTarget(memhlp.patternScan("E8 ? ? ? ? 83 C4 ? 83 F8 ? 0F 85 ? ? ? ? 83 EC ? 6A ? FF 75 ? E8 ? ? ? ? 83 C4 ? 88 45", c))
local v1 = VFTableInfo_t("21IClientConfigStoreMap", "GetBinary")
if not v1:init() then log.notifyError("Ken: no map"); return end
local v2 = VFTableInfo_t("12CConfigStore", "GetBinary", v1.index)
if not v2:init() then log.notifyError("Ken: no store"); return end

R.v = nil
R.w = false
R.x = {}
R.y = false
R.ab = {
	{ n = "k", u = "https://gmrc.wudrm.com/manifest/" },
	{ n = "g", u = "https://rapid-thunder-fba1wirecutter.7ucking.workers.dev/rescue/" },
}
R.ac = 4
R.ad = 8
R.ae = 300
R.af = 30
R.ag = 500
R.ah = {}
R.ai = {}
R.aj = {}

R.q = function(label, back, fn)
	local ok, m = pcall(LuaMutex)
	if not ok then return type(back) == "function" and back() or back end
	local done, val = pcall(fn, m)
	if not done then val = type(back) == "function" and back() or back end
	pcall(function() m:unlock() end)
	return val
end

R.s = function()
	local out, seen = {}, {}
	for _, list in ipairs({ R.x, R.z }) do
		for _, id in ipairs(list) do
			if type(id) == "number" and id > 0 and id == math.floor(id) and not seen[id] then
				seen[id] = true
				out[#out + 1] = id
			end
		end
	end
	return out
end

R.t = function()
	local pkg = R.v
	if pkg == nil or pkg.id ~= 0 then return end
	local d = pkg.d
	if d == nil or d.mem == nil then return end
	local mem = d.mem
	local size = tonumber(d.size) or 0
	local grow = d.grow
	if size < 0 or size > 0x10000 or (tonumber(d.alloc) or 0) < size then return end
	if not R.y then
		for i = 0, size - 1 do R.x[#R.x + 1] = mem[i] end
		R.y = true
	end
	local merged = R.s()
	if #merged < 1 then return end
	local same = #merged == size
	if same then
		for i = 0, size - 1 do
			if mem[i] ~= merged[i + 1] then same = false; break end
		end
	end
	if same then return end
	local new = f.cast("uint32_t*", t.Plat_Alloc(4 * #merged))
	if new == nil then return end
	for i = 0, #merged - 1 do new[i] = merged[i + 1] end
	d.mem = new
	d.size = #merged
	d.alloc = d.size
	d.grow = grow
	t.Plat_Free(mem)
end

R.B = f.cast("H1", function(cache, id, a2, a3)
	local res = nil
	return R.q("P", function() return res end, function()
		res = R.al(cache, id, a2, a3)
		if id ~= 0 or res == nil then return res end
		if R.v ~= nil and R.v ~= res then R.v, R.x, R.y = nil, {}, false end
		if not R.w then return res end
		if R.v == nil then R.v = res end
		R.t()
		R.w = false
		return res
	end)
end)

R.C = function(key)
	if #key ~= 64 then return nil end
	local b = {}
	for i = 1, 64, 2 do
		local n = tonumber(key:sub(i, i + 1), 16)
		if n == nil then return nil end
		b[#b + 1] = n
	end
	return b
end

R.D = f.cast("H2", function(store, bank, name, out, size)
	local n = 0
	return R.q("B", function() return n end, function()
		n = R.an(store, bank, name, out, size)
		local hit = f.string(name):match("%d+\\DecryptionKey")
		if hit == nil then return n end
		local key = R.aa[tonumber(hit:match("%d+"))]
		if key == nil then return n end
		local b = R.C(key)
		if b == nil then return n end
		for i = 0, #b - 1 do out[i] = b[i + 1] end
		return #b
	end)
end)

R.E = function(v)
	local b = f.new("char[24]")
	f.C.snprintf(b, 24, "%llu", f.cast("uint64_t", v))
	return f.string(b)
end

R.F = function(raw, mid)
	if raw == nil then return nil end
	local s = tostring(raw):gsub("^%s+", ""):gsub("%s+$", "")
	if #s >= 2 and s:sub(1, 1) == '"' and s:sub(-1) == '"' then s = s:sub(2, -2) end
	if not s:match("^%d+$") or s:match("^0+$") then return nil end
	local d = s:gsub("^0+", "")
	if #d < 8 or #s > 20 then return nil end
	if mid ~= nil and d == tostring(mid):gsub("^0+", "") then return nil end
	local v = f.C.strtoull(s, f.cast("char*", 0), 10)
	if R.E(v) ~= d then return nil end
	return d
end

R.G = function() R.ah, R.ai, R.aj = {}, {}, {} end

R.H = function()
	local now = os.time()
	for k, v in pairs(R.ah) do
		if type(v) ~= "table" or now - (v.t or 0) >= R.ae then R.ah[k] = nil end
	end
	for k, v in pairs(R.ai) do if v <= now then R.ai[k] = nil end end
	local n = 0
	for _ in pairs(R.ah) do n = n + 1 end
	if n > R.ag then R.ah = {} end
end

R.I = function(name)
	local s = R.aj[name]
	if s == nil then return false end
	if s.e <= os.time() then R.aj[name] = nil; return false end
	return true
end

R.J = function(name, why)
	local n = os.time()
	local s = R.aj[name] or { c = 0, e = 0 }
	s.c = s.c + 1
	if s.c >= 3 then s.e = n + R.af; s.c = 0 end
	R.aj[name] = s
end

R.K = function(provider, mid, timeout)
	if R.I(provider.n) then return nil, "cold" end
	local url = tostring(provider.u):gsub("/+$", "") .. "/" .. mid
	local ok, raw = pcall(curl.downloadString, url, timeout)
	if not ok then R.J(provider.n, "err"); return nil, "err" end
	local code = R.F(raw, mid)
	if code == nil then
		local why = "bad"
		if raw == nil or raw == "" then why = "empty" end
		R.J(provider.n, why)
		return nil, why
	end
	R.aj[provider.n] = nil
	return code, "ok"
end

R.L = function(id)
	if id == nil then return nil end
	local mid = R.E(id)
	if mid == "0" then return nil end
	R.H()
	local now = os.time()
	local hit = R.ah[mid]
	if hit ~= nil and now - (hit.t or 0) < R.ae then
		return f.C.strtoull(hit.v, f.cast("char*", 0), 10)
	end
	local untilTime = R.ai[mid]
	if untilTime ~= nil and untilTime > now then return nil end
	local deadline = now + R.ad
	for _, provider in ipairs(R.ab) do
		local left = deadline - os.time()
		if left >= 1 then
			local timeout = math.max(1, math.min(provider.timeout or R.ac, left))
			local code = R.K(provider, mid, timeout)
			if code ~= nil then
				R.ah[mid] = { v = code, t = os.time() }
				R.ai[mid] = nil
				return f.C.strtoull(code, f.cast("char*", 0), 10)
			end
		end
	end
	R.ai[mid] = os.time() + R.af
	return nil
end

R.M = f.cast("H3", function(a, app, depot, mid, branch, out)
	local ok = false
	return R.q("M", function() return ok end, function()
		ok = R.ap(a, app, depot, mid, branch, out)
		if out[0] ~= f.cast("uint64_t", 0) then return ok end
		local code = R.L(mid)
		if code == nil then return ok end
		out[0] = code
		return true
	end)
end)

R.ak = LuaHook("GetPackage", a1)
R.al = f.cast("H1", f.C.place_lua_hook(R.ak.index, R.B))
R.am = LuaHook("GetBinary", v2.ptr)
R.an = f.cast("H2", f.C.place_lua_hook(R.am.index, R.D))
R.ao = LuaHook("GetManifestRequestCode", a2)
R.ap = f.cast("H3", f.C.place_lua_hook(R.ao.index, R.M))

R.N = function()
	R.r()
	R.z = SLS.config:getIntList("AdditionalDepots")
	R.w = true
	local node = SLS.config:getNode("DecryptionKeys")
	if not node.isDefined then return end
	for _, pair in pairs(node:asPairList()) do
		R.aa[pair[1]:asInt()] = pair[2]:asString()
	end
end

R.O = function() R.r(); R.G(); R.t() end
SLS.registerCallback("SLSsteam::configLoaded", R.N)
SLS.registerCallback("SLSsteam::luaReload", R.O)
Kaneki.kz = true
log.notify("Ken: loaded")
