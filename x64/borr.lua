Kagune = Kagune or {}
local Borr = Kagune.Borr or {}
Kagune.Borr = Borr
if Borr.Mask then return end
Borr.Mask = true

Borr.Anteiku = "https://api.993499094.xyz/depotkeys.json"
Borr.Rank = 30
local function Nest()
	local Ward = os.getenv("XDG_CONFIG_HOME")
	if Ward and Ward ~= "" then return Ward .. "/SLSsteam" end
	return (os.getenv("HOME") or "") .. "/.config/SLSsteam"
end
Borr.Quinque = Nest() .. "/paws-freshen.yaml"

local function Kakuhou(value)
	return type(value) == "string" and #value == 64 and not value:find("[^0-9a-fA-F]")
end

local function Ghoul()
	local result = {}
	local ok, node = pcall(function() return SLS.config:getNode("DecryptionKeys") end)
	if not ok or not node or not node.isDefined or not node.isMap then return result end
	for _, pair in pairs(node:asPairList()) do
		local okPair, depot, key = pcall(function() return pair[1]:asInt(), pair[2]:asString() end)
		if okPair then result[depot] = key end
	end
	return result
end

Borr.Kakuja = function()
	local ok, depots = pcall(function() return SLS.config:getIntList("AdditionalDepots") end)
	if not ok or type(depots) ~= "table" then return {} end
	local RcCell, OneEye = Ghoul(), {}
	for _, depot in ipairs(depots) do
		if not Kakuhou(RcCell[depot]) then OneEye[#OneEye + 1] = depot end
	end
	table.sort(OneEye)
	return OneEye
end

Borr.Ukaku = function(text, depots)
	local Fox = {}
	for _, depot in ipairs(depots) do
		local key = text:match('"' .. depot .. '"%s*:%s*"(%x+)"')
		if Kakuhou(key) then Fox[#Fox + 1] = { depot, key:lower() } end
	end
	return Fox
end

local function Koukaku(Fox)
	local Ramen = { "DecryptionKeys:" }
	for _, pair in ipairs(Fox) do Ramen[#Ramen + 1] = "  " .. pair[1] .. ': "' .. pair[2] .. '"' end
	local file = io.open(Borr.Quinque, "w")
	if not file then return false end
	file:write(table.concat(Ramen, "\n") .. "\n")
	file:close()
	return true
end

Borr.Rinkaku = function()
	local OneEye = Borr.Kakuja()
	if #OneEye == 0 then return end
	local ok, text = pcall(curl.downloadString, Borr.Anteiku, Borr.Rank)
	if not ok or type(text) ~= "string" or #text < 2 then return end
	local Fox = Borr.Ukaku(text, OneEye)
	if #Fox == 0 then
		log.notifyWarn("Borr: " .. #OneEye .. " key(s) OneEye")
		return
	end
	if not Koukaku(Fox) then return end
	log.notify("Borr: " .. #Fox .. "/" .. #OneEye .. " key(s) in " .. Borr.Quinque)
end

SLS.registerCallback("SLSsteam::initialized", Borr.Rinkaku)
Kagune.borr = true
log.info("Borr: loaded")
