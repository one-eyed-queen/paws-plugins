Kaneki = Kaneki or {}
local A = Kaneki.Arima or {}
Kaneki.Arima = A
if A.u then return end
A.u = true
A.last = nil
A.started = false

local function list(name)
	local ok, v = pcall(function() return SLS.config:getIntList(name) end)
	return ok and type(v) == "table" and v or {}
end

local function scalar(name, default)
	local ok, v = pcall(function() return SLS.config:getString(name, default) end)
	return string.lower(tostring(ok and v or default))
end

local function keys()
	local out = {}
	local ok, node = pcall(function() return SLS.config:getNode("DecryptionKeys") end)
	if not ok or not node or not node.isDefined or not node.isMap then return out end
	for _, pair in pairs(node:asPairList()) do
		local okPair, depot, key = pcall(function() return pair[1]:asInt(), pair[2]:asString() end)
		if okPair then out[depot] = key end
	end
	return out
end

local function good(v)
	return type(v) == "string" and #v == 64 and not v:find("[^0-9a-fA-F]")
end

local function few(items)
	table.sort(items)
	local shown = {}
	for i = 1, math.min(#items, 6) do shown[i] = tostring(items[i]) end
	return table.concat(shown, ", ") .. (#items > 6 and ", ..." or "")
end

A.p = function()
	local out = {}
	local depots, km = list("AdditionalDepots"), keys()
	local no = {}
	for _, depot in ipairs(depots) do
		if not good(km[depot]) then no[#no + 1] = depot end
	end
	if #no > 0 then out[#out + 1] = #no .. " depot(s) no key: " .. few(no) end
	local bad = {}
	for depot, key in pairs(km) do if not good(key) then bad[#bad + 1] = depot end end
	if #bad > 0 then out[#out + 1] = #bad .. " key(s) bad: " .. few(bad) end
	local rz, kz = Kaneki.rz == true, Kaneki.kz == true
	if rz and kz then out[#out + 1] = "Rize and Ken both loaded" end
	if #depots > 0 and not rz and not kz then out[#out + 1] = "depots with no download plugin" end
	local disable = scalar("DisableUpdates", "yes")
	if (rz or kz) and (disable == "yes" or disable == "true" or disable == "on" or disable == "1") then
		out[#out + 1] = "DisableUpdates on"
	end
	return out, #depots
end

A.c = function(why)
	local problems, depots = A.p()
	local summary = table.concat(problems, "\n")
	if #problems == 0 then
		log.info("Arima: ok " .. depots .. " depot(s) " .. why)
	else
		for _, problem in ipairs(problems) do log.warn("Arima: " .. problem) end
	end
	if summary ~= A.last then
		if #problems > 0 then log.notifyWarn("Arima:\n" .. summary)
		elseif A.last ~= nil then log.notify("Arima: ok again") end
		A.last = summary
	end
end

SLS.registerCallback("SLSsteam::initialized", function()
	A.started = true
	A.c("start")
end)

SLS.registerCallback("SLSsteam::configLoaded", function()
	if A.started then A.c("cfg") end
end)

Kaneki.ah = true
log.info("Arima: loaded")
