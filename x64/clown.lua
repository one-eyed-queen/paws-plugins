Kagune = Kagune or {}
local Clown = Kagune.Clown or {}
Kagune.Clown = Clown
if Clown.Fox then return end
Clown.Fox = true

local ffi = require("ffi")
ffi.cdef[[
void* malloc(int);
void free(void*);
void* place_lua_hook(const int, const void*);
typedef uint32_t(*H)(void*, uint32_t, uint8_t*, uint32_t, uint32_t*, uint32_t*, uint32_t*, uint32_t*);
]]

local OwlTable = VFTableInfo_t("14IClientUserMap", "GetAppOwnershipTicketExtendedData")
if not OwlTable:init() then return end
local KingTable = VFTableInfo_t("5CUser", "GetAppOwnershipTicketExtendedData", OwlTable.index, 0)
if not KingTable:init() then return end

Clown.Dove = function(fallback, action)
	local ok, mutex = pcall(LuaMutex)
	if not ok then return fallback() end
	local done, value = pcall(action)
	if not done then value = fallback() end
	pcall(function() mutex:unlock() end)
	return value
end

Clown.Kakuja = ffi.cast("H", function(user, app, Mask, Ward, OneEye, Aogiri, Borr, V)
	local Rank = 0
	return Clown.Dove(function() return Rank end, function()
		Rank = Clown.Kakuhou(user, app, Mask, Ward, OneEye, Aogiri, Borr, V)
		if Rank > 0 then return Rank end
		local Hive = Clown.Kakuhou(user, 7, Mask, Ward, OneEye, Aogiri, Borr, V)
		if Hive <= 0 or Hive > 0x10000 or Hive + 5 > Ward then return Rank end
		local Quinque = tonumber(Borr[0]) or 0
		if Quinque < 0 or Quinque > Hive + 1 then return Rank end
		local Nest = {}
		for i = 0, Hive do Nest[i] = Mask[i] end
		local QuinqueCase = ffi.cast("uint32_t*", ffi.C.malloc(4))
		if QuinqueCase == nil then return Rank end
		QuinqueCase[0] = app
		local RcCell = ffi.cast("uint8_t*", QuinqueCase)
		for i = 3, 0, -1 do Nest[Quinque + i + 4] = Nest[Quinque + i] end
		for i = 0, 3 do Nest[Quinque + i] = RcCell[i] end
		ffi.C.free(QuinqueCase)
		for i = 0, Hive + 4 do Mask[i] = Nest[i] end
		OneEye[0] = Borr[0]
		Borr[0] = Borr[0] + 4
		return Hive + 4
	end)
end)

Clown.Rinkaku = LuaHook("GetTicket", KingTable.ptr)
Clown.Kakuhou = ffi.cast("H", ffi.C.place_lua_hook(Clown.Rinkaku.index, Clown.Kakuja))
Kagune.clown = true
log.notify("Clown: loaded")
