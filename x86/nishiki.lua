Kaneki = Kaneki or {}
local N = Kaneki.Nishiki or {}
Kaneki.Nishiki = N
if N.u then return end
N.u = true
N.w = false

local function d()
	local x = os.getenv("XDG_CONFIG_HOME")
	if x and x ~= "" then return x .. "/SLSsteam" end
	return (os.getenv("HOME") or "") .. "/.config/SLSsteam"
end
N.c = d() .. "/paws-keyguard.yaml"

local function a()
	local ok, v = pcall(function() return SLS.config:getIntList("AdditionalDepots") end)
	return ok and type(v) == "table" and v or {}
end

local function b()
	local out = {}
	local ok, node = pcall(function() return SLS.config:getNode("DecryptionKeys") end)
	if not ok or not node or not node.isDefined or not node.isMap then return out end
	for _, pair in pairs(node:asPairList()) do
		local okPair, depot, key = pcall(function() return pair[1]:asInt(), pair[2]:asString() end)
		if okPair then out[#out + 1] = { depot, key } end
	end
	table.sort(out, function(p, q) return p[1] < q[1] end)
	return out
end

local function r(list, keys)
	local lines = { "# Nishiki", "", "AdditionalDepots:" }
	local sorted = {}
	for i, depot in ipairs(list) do sorted[i] = depot end
	table.sort(sorted)
	for _, depot in ipairs(sorted) do lines[#lines + 1] = "  - " .. tostring(depot) end
	lines[#lines + 1] = ""
	lines[#lines + 1] = "DecryptionKeys:"
	for _, pair in ipairs(keys) do
		lines[#lines + 1] = "  " .. tostring(pair[1]) .. ': "' .. tostring(pair[2]) .. '"'
	end
	return table.concat(lines, "\n") .. "\n"
end

local function read()
	local file = io.open(N.c, "r")
	if not file then return nil end
	local text = file:read("*a")
	file:close()
	return text
end

local function rows(text)
	local n = 0
	for _ in (text or ""):gmatch("\n  [%-%d]") do n = n + 1 end
	return n
end

N.check = function()
	local list, keys = a(), b()
	if #list > 0 or #keys > 0 then
		N.w = false
		local text = r(list, keys)
		if text ~= read() then
			local file = io.open(N.c, "w")
			if file then
				file:write(text)
				file:close()
			else
				log.warn("Nishiki: no write")
			end
		end
		return
	end
	local n = rows(read())
	if n > 0 and not N.w then
		N.w = true
		log.notifyWarn("Nishiki: config empty, copy at " .. N.c .. " has " .. n .. " row(s)")
	end
end

SLS.registerCallback("SLSsteam::configLoaded", N.check)
Kaneki.ng = true
log.info("Nishiki: loaded")
