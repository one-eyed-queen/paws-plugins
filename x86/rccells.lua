Kagune = Kagune or {}
local RcCells = Kagune.RcCells or {}
Kagune.RcCells = RcCells
if RcCells.sealed then return end
RcCells.sealed = true

RcCells.source = "https://api.993499094.xyz/depotkeys.json"
RcCells.pulse = 30
local function ward()
	local home = os.getenv("XDG_CONFIG_HOME")
	if home and home ~= "" then return home .. "/SLSsteam" end
	return (os.getenv("HOME") or "") .. "/.config/SLSsteam"
end
RcCells.scroll = ward() .. "/paws-freshen.yaml"

local function pure(value)
	return type(value) == "string" and #value == 64 and not value:find("[^0-9a-fA-F]")
end

local function harvest()
	local result = {}
	local ok, node = pcall(function() return SLS.config:getNode("DecryptionKeys") end)
	if not ok or not node or not node.isDefined or not node.isMap then return result end
	for _, pair in pairs(node:asPairList()) do
		local okPair, depot, key = pcall(function() return pair[1]:asInt(), pair[2]:asString() end)
		if okPair then result[depot] = key end
	end
	return result
end

RcCells.wanted = function()
	local ok, depots = pcall(function() return SLS.config:getIntList("AdditionalDepots") end)
	if not ok or type(depots) ~= "table" then return {} end
	local cells, missing = harvest(), {}
	for _, depot in ipairs(depots) do
		if not pure(cells[depot]) then missing[#missing + 1] = depot end
	end
	table.sort(missing)
	return missing
end

RcCells.pick = function(text, depots)
	local found = {}
	for _, depot in ipairs(depots) do
		local key = text:match('"' .. depot .. '"%s*:%s*"(%x+)"')
		if pure(key) then found[#found + 1] = { depot, key:lower() } end
	end
	return found
end

local function inscribe(found)
	local lines = { "DecryptionKeys:" }
	for _, pair in ipairs(found) do lines[#lines + 1] = "  " .. pair[1] .. ': "' .. pair[2] .. '"' end
	local file = io.open(RcCells.scroll, "w")
	if not file then return false end
	file:write(table.concat(lines, "\n") .. "\n")
	file:close()
	return true
end

RcCells.gather = function()
	local missing = RcCells.wanted()
	if #missing == 0 then return end
	local ok, text = pcall(curl.downloadString, RcCells.source, RcCells.pulse)
	if not ok or type(text) ~= "string" or #text < 2 then return end
	local found = RcCells.pick(text, missing)
	if #found == 0 then
		log.notifyWarn("RcCells: " .. #missing .. " key(s) missing")
		return
	end
	if not inscribe(found) then return end
	log.notify("RcCells: " .. #found .. "/" .. #missing .. " key(s) in " .. RcCells.scroll)
end

SLS.registerCallback("SLSsteam::initialized", RcCells.gather)
Kagune.rccells = true
log.info("RcCells: loaded")
