Kagune = Kagune or {}
local Mask = Kagune.Mask or {}
Kagune.Mask = Mask
if Mask.sealed then return end
Mask.sealed = true

local ffi = require("ffi")
if ffi.abi("64bit") then log.notifyError("Mask: wrong arch"); return end
ffi.cdef[[
void* malloc(int);
void free(void*);
void* place_lua_hook(const int, const void*);
typedef uint32_t(*H)(void*, uint32_t, uint8_t*, uint32_t, uint32_t*, uint32_t*, uint32_t*, uint32_t*);
]]

local mapTable = VFTableInfo_t("14IClientUserMap", "GetAppOwnershipTicketExtendedData")
if not mapTable:init() then return end
local userTable = VFTableInfo_t("5CUser", "GetAppOwnershipTicketExtendedData", mapTable.index, 0)
if not userTable:init() then return end

Mask.shield = function(fallback, action)
	local ok, mutex = pcall(LuaMutex)
	if not ok then return fallback() end
	local done, value = pcall(action)
	if not done then value = fallback() end
	pcall(function() mutex:unlock() end)
	return value
end

Mask.wear = ffi.cast("H", function(user, app, pass, limit, appMark, steamMark, sealMark, sealSize)
	local first = 0
	return Mask.shield(function() return first end, function()
		first = Mask.tramp(user, app, pass, limit, appMark, steamMark, sealMark, sealSize)
		if first > 0 then return first end
		local base = Mask.tramp(user, 7, pass, limit, appMark, steamMark, sealMark, sealSize)
		if base <= 0 or base > 0x10000 or base + 5 > limit then return first end
		local sealAt = tonumber(sealMark[0]) or 0
		if sealAt < 0 or sealAt > base + 1 then return first end
		local draft = {}
		for i = 0, base do draft[i] = pass[i] end
		local stamp = ffi.cast("uint32_t*", ffi.C.malloc(4))
		if stamp == nil then return first end
		stamp[0] = app
		local digits = ffi.cast("uint8_t*", stamp)
		for i = 3, 0, -1 do draft[sealAt + i + 4] = draft[sealAt + i] end
		for i = 0, 3 do draft[sealAt + i] = digits[i] end
		ffi.C.free(stamp)
		for i = 0, base + 4 do pass[i] = draft[i] end
		appMark[0] = sealMark[0]
		sealMark[0] = sealMark[0] + 4
		return base + 4
	end)
end)

Mask.hook = LuaHook("GetTicket", userTable.ptr)
Mask.tramp = ffi.cast("H", ffi.C.place_lua_hook(Mask.hook.index, Mask.wear))
Kagune.mask = true
log.notify("Mask: loaded")
