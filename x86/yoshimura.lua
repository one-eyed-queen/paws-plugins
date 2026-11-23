Kaneki = Kaneki or {}
local Y = Kaneki.Yoshimura or {}
Kaneki.Yoshimura = Y
if Y.u then return end
Y.u = true

Y.a = "https://api.993499094.xyz/depotkeys.json"
Y.b = 30
local function d()
	local x = os.getenv("XDG_CONFIG_HOME")
	if x and x ~= "" then return x .. "/SLSsteam" end
	return (os.getenv("HOME") or "") .. "/.config/SLSsteam"
end
Y.c = d() .. "/paws-freshen.yaml"

local function k(v)
	return type(v) == "string" and #v == 64 and not v:find("[^0-9a-fA-F]")
end

local function n()
	local out = {}
	local ok, node = pcall(function() return SLS.config:getNode("DecryptionKeys") end)
	if not ok or not node or not node.isDefined or not node.isMap then return out end
	for _, pair in pairs(node:asPairList()) do
		local okPair, depot, key = pcall(function() return pair[1]:asInt(), pair[2]:asString() end)
		if okPair then out[depot] = key end
	end
	return out
end

Y.m = function()
	local ok, depots = pcall(function() return SLS.config:getIntList("AdditionalDepots") end)
	if not ok or type(depots) ~= "table" then return {} end
	local keys, missing = n(), {}
	for _, depot in ipairs(depots) do
		if not k(keys[depot]) then missing[#missing + 1] = depot end
	end
	table.sort(missing)
	return missing
end

Y.l = function(text, depots)
	local found = {}
	for _, depot in ipairs(depots) do
		local key = text:match('"' .. depot .. '"%s*:%s*"(%x+)"')
		if k(key) then found[#found + 1] = { depot, key:lower() } end
	end
	return found
end

local function s(found)
	local lines = {
		"# Yoshimura " .. os.date("%Y-%m-%d %H:%M") .. " " .. Y.a,
		"# paste under DecryptionKeys",
		"",
		"DecryptionKeys:",
	}
	for _, pair in ipairs(found) do lines[#lines + 1] = "  " .. pair[1] .. ': "' .. pair[2] .. '"' end
	local file = io.open(Y.c, "w")
	if not file then return false end
	file:write(table.concat(lines, "\n") .. "\n")
	file:close()
	return true
end

Y.check = function()
	local missing = Y.m()
	if #missing == 0 then return end
	local ok, text = pcall(curl.downloadString, Y.a, Y.b)
	if not ok or type(text) ~= "string" or #text < 2 then return end
	local found = Y.l(text, missing)
	if #found == 0 then
		log.notifyWarn("Yoshimura: " .. #missing .. " key(s) missing")
		return
	end
	if not s(found) then return end
	log.notify("Yoshimura: " .. #found .. "/" .. #missing .. " key(s) in " .. Y.c)
end

SLS.registerCallback("SLSsteam::initialized", Y.check)
Kaneki.yt = true
log.info("Yoshimura: loaded")
