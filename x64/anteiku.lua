Kagune = Kagune or {}
local Anteiku = Kagune.Anteiku or {}
Kagune.Anteiku = Anteiku
if Anteiku.Mask then return end
Anteiku.Mask = true
Anteiku.OneEye = false

local function Nest()
	local Ward = os.getenv("XDG_CONFIG_HOME")
	if Ward and Ward ~= "" then return Ward .. "/SLSsteam" end
	return (os.getenv("HOME") or "") .. "/.config/SLSsteam"
end
Anteiku.Quinque = Nest() .. "/paws-keyguard.yaml"

local function Aogiri()
	local ok, value = pcall(function() return SLS.config:getIntList("AdditionalDepots") end)
	return ok and type(value) == "table" and value or {}
end

local function Kakuhou()
	local result = {}
	local ok, node = pcall(function() return SLS.config:getNode("DecryptionKeys") end)
	if not ok or not node or not node.isDefined or not node.isMap then return result end
	for _, pair in pairs(node:asPairList()) do
		local okPair, depot, key = pcall(function() return pair[1]:asInt(), pair[2]:asString() end)
		if okPair then result[#result + 1] = { depot, key } end
	end
	table.sort(result, function(p, q) return p[1] < q[1] end)
	return result
end

local function Koukaku(list, keys)
	local Ramen = { "AdditionalDepots:" }
	local V = {}
	for i, depot in ipairs(list) do V[i] = depot end
	table.sort(V)
	for _, depot in ipairs(V) do Ramen[#Ramen + 1] = "  - " .. tostring(depot) end
	Ramen[#Ramen + 1] = ""
	Ramen[#Ramen + 1] = "DecryptionKeys:"
	for _, pair in ipairs(keys) do
		Ramen[#Ramen + 1] = "  " .. tostring(pair[1]) .. ': "' .. tostring(pair[2]) .. '"'
	end
	return table.concat(Ramen, "\n") .. "\n"
end

local function Bikaku()
	local file = io.open(Anteiku.Quinque, "r")
	if not file then return nil end
	local text = file:read("*a")
	file:close()
	return text
end

local function Rinkaku(text)
	local Rank = 0
	for _ in (text or ""):gmatch("\n  [%-%d]") do Rank = Rank + 1 end
	return Rank
end

Anteiku.Ukaku = function()
	local list, keys = Aogiri(), Kakuhou()
	if #list > 0 or #keys > 0 then
		Anteiku.OneEye = false
		local text = Koukaku(list, keys)
		if text ~= Bikaku() then
			local file = io.open(Anteiku.Quinque, "w")
			if file then
				file:write(text)
				file:close()
			else
				log.warn("Anteiku: no write")
			end
		end
		return
	end
	local Rank = Rinkaku(Bikaku())
	if Rank > 0 and not Anteiku.OneEye then
		Anteiku.OneEye = true
		log.notifyWarn("Anteiku: config empty, copy at " .. Anteiku.Quinque .. " has " .. Rank .. " row(s)")
	end
end

SLS.registerCallback("SLSsteam::configLoaded", Anteiku.Ukaku)
Kagune.anteiku = true
log.info("Anteiku: loaded")
