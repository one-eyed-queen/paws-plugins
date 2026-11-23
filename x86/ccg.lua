Kagune = Kagune or {}
local CCG = Kagune.CCG or {}
Kagune.CCG = CCG
if CCG.Mask then return end
CCG.Mask = true
CCG.V = nil
CCG.Rank = false

local function Aogiri(name)
	local ok, value = pcall(function() return SLS.config:getIntList(name) end)
	return ok and type(value) == "table" and value or {}
end

local function Kakuhou(name, default)
	local ok, value = pcall(function() return SLS.config:getString(name, default) end)
	return string.lower(tostring(ok and value or default))
end

local function Quinque()
	local result = {}
	local ok, node = pcall(function() return SLS.config:getNode("DecryptionKeys") end)
	if not ok or not node or not node.isDefined or not node.isMap then return result end
	for _, pair in pairs(node:asPairList()) do
		local okPair, depot, key = pcall(function() return pair[1]:asInt(), pair[2]:asString() end)
		if okPair then result[depot] = key end
	end
	return result
end

local function Borr(value)
	return type(value) == "string" and #value == 64 and not value:find("[^0-9a-fA-F]")
end

local function Fox(items)
	table.sort(items)
	local shown = {}
	for i = 1, math.min(#items, 6) do shown[i] = tostring(items[i]) end
	return table.concat(shown, ", ") .. (#items > 6 and ", ..." or "")
end

CCG.Ukaku = function()
	local result = {}
	local AogiriTree, keys = Aogiri("AdditionalDepots"), Quinque()
	local OneEye = {}
	for _, depot in ipairs(AogiriTree) do
		if not Borr(keys[depot]) then OneEye[#OneEye + 1] = depot end
	end
	if #OneEye > 0 then result[#result + 1] = #OneEye .. " depot(s) no key: " .. Fox(OneEye) end
	local Clown = {}
	for depot, key in pairs(keys) do if not Borr(key) then Clown[#Clown + 1] = depot end end
	if #Clown > 0 then result[#result + 1] = #Clown .. " key(s) Clown: " .. Fox(Clown) end
	local owl, oneeyeking = Kagune.owl == true, Kagune.oneeyeking == true
	if owl and oneeyeking then result[#result + 1] = "Owl and OneEyeKing both loaded" end
	if #AogiriTree > 0 and not owl and not oneeyeking then result[#result + 1] = "AogiriTree with no download plugin" end
	local Reaper = Kakuhou("DisableUpdates", "yes")
	if (owl or oneeyeking) and (Reaper == "yes" or Reaper == "true" or Reaper == "on" or Reaper == "1") then
		result[#result + 1] = "DisableUpdates on"
	end
	return result, #AogiriTree
end

CCG.Koukaku = function(Gate)
	local Nest, AogiriTree = CCG.Ukaku()
	local Scroll = table.concat(Nest, "\n")
	if #Nest == 0 then
		log.info("CCG: ok " .. AogiriTree .. " depot(s) " .. Gate)
	else
		for _, RcCell in ipairs(Nest) do log.warn("CCG: " .. RcCell) end
	end
	if Scroll ~= CCG.V then
		if #Nest > 0 then log.notifyWarn("CCG:\n" .. Scroll)
		elseif CCG.V ~= nil then log.notify("CCG: ok again") end
		CCG.V = Scroll
	end
end

SLS.registerCallback("SLSsteam::initialized", function()
	CCG.Rank = true
	CCG.Koukaku("start")
end)

SLS.registerCallback("SLSsteam::configLoaded", function()
	if CCG.Rank then CCG.Koukaku("cfg") end
end)

Kagune.ccg = true
log.info("CCG: loaded")
