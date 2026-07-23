-- parser.lua
-- Pure Lua brace expansion parser (Bash-like), no shell dependency.
local Parser = {}

-- Find the first "{" in `str` and the position of its matching "}".
-- Returns start_pos, end_pos (both 1-based, inclusive).
-- If the opening brace has no matching close, end_pos is nil.
local function find_matching_brace(str)
	local start_pos = str:find("{", 1, true)
	if not start_pos then
		return nil
	end

	local depth = 0
	local i = start_pos
	local len = #str
	while i <= len do
		local c = str:sub(i, i)
		if c == "{" then
			depth = depth + 1
		elseif c == "}" then
			depth = depth - 1
			if depth == 0 then
				return start_pos, i
			end
		end
		i = i + 1
	end

	return start_pos, nil -- unbalanced: opening found, no matching close
end

-- Split `body` on top-level commas (commas not nested inside inner braces).
local function split_top_level(body)
	local parts = {}
	local depth = 0
	local buf = {}

	for i = 1, #body do
		local c = body:sub(i, i)
		if c == "{" then
			depth = depth + 1
			buf[#buf + 1] = c
		elseif c == "}" then
			depth = depth - 1
			buf[#buf + 1] = c
		elseif c == "," and depth == 0 then
			parts[#parts + 1] = table.concat(buf)
			buf = {}
		else
			buf[#buf + 1] = c
		end
	end
	parts[#parts + 1] = table.concat(buf)

	return parts
end

-- Try to parse `body` as a numeric range, e.g. "1..5", "05..01".
-- Preserves zero-padding width when either bound has a leading zero.
local function try_numeric_range(body)
	local a, b = body:match("^(%-?%d+)%.%.(%-?%d+)$")
	if not a then
		return nil
	end

	local pad = false
	local width = 0
	if a:match("^%-?0%d") or b:match("^%-?0%d") then
		pad = true
		width = math.max(#a, #b)
	end

	local from, to = tonumber(a), tonumber(b)
	local step = from <= to and 1 or -1
	local values = {}

	local n = from
	while true do
		local s = tostring(math.abs(n))
		if pad then
			s = string.rep("0", math.max(0, width - #s)) .. s
		end
		if n < 0 then
			s = "-" .. s
		end
		values[#values + 1] = s
		if n == to then
			break
		end
		n = n + step
	end

	return values
end

-- Try to parse `body` as a single-character alphabetic range, e.g. "a..d".
local function try_alpha_range(body)
	local a, b = body:match("^(%a)%.%.(%a)$")
	if not a then
		return nil
	end

	local from, to = string.byte(a), string.byte(b)
	local step = from <= to and 1 or -1
	local values = {}

	local n = from
	while true do
		values[#values + 1] = string.char(n)
		if n == to then
			break
		end
		n = n + step
	end

	return values
end

-- Recursively expand a single pattern string.
-- Returns a list of expanded strings, or nil + error message on failure.
local function expand(str)
	local start_pos, end_pos = find_matching_brace(str)

	if not start_pos then
		return { str }
	end

	if not end_pos then
		return nil, "unbalanced brace: missing '}' for '{' at position " .. start_pos
	end

	local prefix = str:sub(1, start_pos - 1)
	local body = str:sub(start_pos + 1, end_pos - 1)
	local suffix = str:sub(end_pos + 1)

	local suffix_expanded, serr = expand(suffix)
	if not suffix_expanded then
		return nil, serr
	end

	-- A brace group is either a range, a comma-list, or (if neither) literal text.
	local atoms = try_numeric_range(body) or try_alpha_range(body)

	if not atoms then
		local parts = split_top_level(body)
		if #parts > 1 then
			atoms = parts
		else
			-- Not valid brace syntax (e.g. "{foo}") — bash keeps it literal.
			local literal_result = {}
			for _, se in ipairs(suffix_expanded) do
				literal_result[#literal_result + 1] = prefix .. "{" .. body .. "}" .. se
			end
			return literal_result
		end
	end

	local results = {}
	for _, atom in ipairs(atoms) do
		local atom_expanded, aerr = expand(atom)
		if not atom_expanded then
			return nil, aerr
		end
		for _, ae in ipairs(atom_expanded) do
			for _, se in ipairs(suffix_expanded) do
				results[#results + 1] = prefix .. ae .. se
			end
		end
	end

	return results
end

-- Public entry point.
-- Returns a list of expanded path strings, or nil + error message.
function Parser.expand(input)
	if type(input) ~= "string" or input == "" then
		return nil, "empty pattern"
	end

	-- Quick top-level balance check for a clear, early error message.
	local open_count, close_count = 0, 0
	for c in input:gmatch("[{}]") do
		if c == "{" then
			open_count = open_count + 1
		else
			close_count = close_count + 1
		end
	end
	if open_count ~= close_count then
		return nil, "unbalanced braces: " .. open_count .. " '{' vs " .. close_count .. " '}'"
	end

	local ok, result_or_err, err = pcall(expand, input)
	if not ok then
		return nil, "parser error: " .. tostring(result_or_err)
	end
	if not result_or_err then
		return nil, err
	end

	return result_or_err
end

return Parser