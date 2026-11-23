Kagune = Kagune or {}
local Dove = Kagune.Dove or {}
Kagune.Dove = Dove
if Dove.sealed then return end
Dove.sealed = true
Dove.last = nil
Dove.started = false

local function wards(name)
	local ok, value = pcall(function() return SLS.config:getIntList(name) end)
	return ok and type(value) == "table" and value or {}
end

local function decree(name, default)
	local ok, value = pcall(function() return SLS.config:getString(name, default) end)
	return string.lower(tostring(ok and value or default))
end

local function cells()
	local result = {}
	local ok, node = pcall(function() return SLS.config:getNode("DecryptionKeys") end)
	if not ok or not node or not node.isDefined or not node.isMap then return result end
	for _, pair in pairs(node:asPairList()) do
		local okPair, depot, key = pcall(function() return pair[1]:asInt(), pair[2]:asString() end)
		if okPair then result[depot] = key end
	end
	return result
end

local function pure(value)
	return type(value) == "string" and #value == 64 and not value:find("[^0-9a-fA-F]")
end

local function brief(items)
	table.sort(items)
	local shown = {}
	for i = 1, math.min(#items, 6) do shown[i] = tostring(items[i]) end
	return table.concat(shown, ", ") .. (#items > 6 and ", ..." or "")
end

Dove.inspect = function()
	local result = {}
	local depots, keys = wards("AdditionalDepots"), cells()
	local absent = {}
	for _, depot in ipairs(depots) do
		if not pure(keys[depot]) then absent[#absent + 1] = depot end
	end
	if #absent > 0 then result[#result + 1] = #absent .. " depot(s) no key: " .. brief(absent) end
	local bad = {}
	for depot, key in pairs(keys) do if not pure(key) then bad[#bad + 1] = depot end end
	if #bad > 0 then result[#result + 1] = #bad .. " key(s) bad: " .. brief(bad) end
	local ukaku, koukaku = Kagune.ukaku == true, Kagune.koukaku == true
	if ukaku and koukaku then result[#result + 1] = "Ukaku and Koukaku both loaded" end
	if #depots > 0 and not ukaku and not koukaku then result[#result + 1] = "depots with no download plugin" end
	local disable = decree("DisableUpdates", "yes")
	if (ukaku or koukaku) and (disable == "yes" or disable == "true" or disable == "on" or disable == "1") then
		result[#result + 1] = "DisableUpdates on"
	end
	return result, #depots
end

Dove.report = function(why)
	local problems, depots = Dove.inspect()
	local summary = table.concat(problems, "\n")
	if #problems == 0 then
		log.info("Dove: ok " .. depots .. " depot(s) " .. why)
	else
		for _, problem in ipairs(problems) do log.warn("Dove: " .. problem) end
	end
	if summary ~= Dove.last then
		if #problems > 0 then log.notifyWarn("Dove:\n" .. summary)
		elseif Dove.last ~= nil then log.notify("Dove: ok again") end
		Dove.last = summary
	end
end

SLS.registerCallback("SLSsteam::initialized", function()
	Dove.started = true
	Dove.report("start")
end)

SLS.registerCallback("SLSsteam::configLoaded", function()
	if Dove.started then Dove.report("cfg") end
end)

Kagune.dove = true
log.info("Dove: loaded")
