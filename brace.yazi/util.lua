-- util.lua
-- Small stateless helper functions shared across brace.yazi modules.
local Util = {}

-- Remove leading/trailing whitespace.
function Util.trim(s)
	return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Return true if `s` is nil, empty, or only whitespace.
function Util.is_blank(s)
	return s == nil or Util.trim(s) == ""
end

-- Deduplicate a list of strings while preserving first-seen order.
function Util.dedup(list)
	local seen = {}
	local result = {}
	for _, v in ipairs(list) do
		if not seen[v] then
			seen[v] = true
			result[#result + 1] = v
		end
	end
	return result
end

-- Sort a list of strings alphabetically, in place, and return it.
function Util.sort(list)
	table.sort(list)
	return list
end

return Util