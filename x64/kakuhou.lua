Kagune = Kagune or {}
local Kakuhou = Kagune.Kakuhou or {}
Kagune.Kakuhou = Kakuhou
if Kakuhou.sealed then return end
Kakuhou.sealed = true
Kakuhou.warned = false

local function ward()
	local home = os.getenv("XDG_CONFIG_HOME")
	if home and home ~= "" then return home .. "/SLSsteam" end
	return (os.getenv("HOME") or "") .. "/.config/SLSsteam"
end
Kakuhou.scroll = ward() .. "/paws-keyguard.yaml"

local function wards()
	local ok, value = pcall(function() return SLS.config:getIntList("AdditionalDepots") end)
	return ok and type(value) == "table" and value or {}
end

local function cells()
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

local function inscribe(list, keys)
	local lines = { "AdditionalDepots:" }
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

local function readScroll()
	local file = io.open(Kakuhou.scroll, "r")
	if not file then return nil end
	local text = file:read("*a")
	file:close()
	return text
end

local function countRows(text)
	local count = 0
	for _ in (text or ""):gmatch("\n  [%-%d]") do count = count + 1 end
	return count
end

Kakuhou.guard = function()
	local list, keys = wards(), cells()
	if #list > 0 or #keys > 0 then
		Kakuhou.warned = false
		local text = inscribe(list, keys)
		if text ~= readScroll() then
			local file = io.open(Kakuhou.scroll, "w")
			if file then
				file:write(text)
				file:close()
			else
				log.warn("Kakuhou: no write")
			end
		end
		return
	end
	local count = countRows(readScroll())
	if count > 0 and not Kakuhou.warned then
		Kakuhou.warned = true
		log.notifyWarn("Kakuhou: config empty, copy at " .. Kakuhou.scroll .. " has " .. count .. " row(s)")
	end
end

SLS.registerCallback("SLSsteam::configLoaded", Kakuhou.guard)
Kagune.kakuhou = true
log.info("Kakuhou: loaded")
