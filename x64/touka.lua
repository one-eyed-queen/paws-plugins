Kaneki = Kaneki or {}
local T = Kaneki.Touka or {}
Kaneki.Touka = T
if T.u then return end
T.u = true

local f = require("ffi")
f.cdef[[
void* malloc(int);
void free(void*);
void* place_lua_hook(const int, const void*);
typedef uint32_t(*H)(void*, uint32_t, uint8_t*, uint32_t, uint32_t*, uint32_t*, uint32_t*, uint32_t*);
]]

local v1 = VFTableInfo_t("14IClientUserMap", "GetAppOwnershipTicketExtendedData")
if not v1:init() then return end
local v2 = VFTableInfo_t("5CUser", "GetAppOwnershipTicketExtendedData", v1.index, 0)
if not v2:init() then return end

T.q = function(back, fn)
	local ok, m = pcall(LuaMutex)
	if not ok then return back() end
	local done, val = pcall(fn)
	if not done then val = back() end
	pcall(function() m:unlock() end)
	return val
end

T.h = f.cast("H", function(user, app, ticket, cap, offApp, offSteam, offSig, offSigSize)
	local first = 0
	return T.q(function() return first end, function()
		first = T.tramp(user, app, ticket, cap, offApp, offSteam, offSig, offSigSize)
		if first > 0 then return first end
		local base = T.tramp(user, 7, ticket, cap, offApp, offSteam, offSig, offSigSize)
		if base <= 0 or base > 0x10000 or base + 5 > cap then return first end
		local so = tonumber(offSig[0]) or 0
		if so < 0 or so > base + 1 then return first end
		local raw = {}
		for i = 0, base do raw[i] = ticket[i] end
		local buf = f.cast("uint32_t*", f.C.malloc(4))
		if buf == nil then return first end
		buf[0] = app
		local bytes = f.cast("uint8_t*", buf)
		for i = 3, 0, -1 do raw[so + i + 4] = raw[so + i] end
		for i = 0, 3 do raw[so + i] = bytes[i] end
		f.C.free(buf)
		for i = 0, base + 4 do ticket[i] = raw[i] end
		offApp[0] = offSig[0]
		offSig[0] = offSig[0] + 4
		return base + 4
	end)
end)

T.hook = LuaHook("GetTicket", v2.ptr)
T.tramp = f.cast("H", f.C.place_lua_hook(T.hook.index, T.h))
Kaneki.tt = true
log.notify("Touka: loaded")
