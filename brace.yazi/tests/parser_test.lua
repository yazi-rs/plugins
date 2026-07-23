-- tests/parser_test.lua
-- Run with: cd tests && lua parser_test.lua
package.path = "../?.lua;./?.lua;" .. package.path
local Parser = require("parser")

local pass, fail = 0, 0

local function eq_list(a, b)
	if not a or #a ~= #b then
		return false
	end
	for i = 1, #a do
		if a[i] ~= b[i] then
			return false
		end
	end
	return true
end

local function check(name, got, want)
	if eq_list(got, want) then
		pass = pass + 1
		print("  ok   " .. name)
	else
		fail = fail + 1
		print("  FAIL " .. name)
		print("        got:  " .. table.concat(got or {}, ", "))
		print("        want: " .. table.concat(want, ", "))
	end
end

local function check_error(name, got, want_nil, err)
	if got == want_nil and type(err) == "string" then
		pass = pass + 1
		print("  ok   " .. name .. " (" .. err .. ")")
	else
		fail = fail + 1
		print("  FAIL " .. name .. " (expected an error, got a result)")
	end
end

print("parser_test.lua")

check("comma list", Parser.expand("project/{src,include,docs,tests}"), {
	"project/src", "project/include", "project/docs", "project/tests",
})

check("no braces", Parser.expand("plain/path"), { "plain/path" })

check("single-item brace is literal", Parser.expand("note-{v1}"), { "note-{v1}" })

check_error("unbalanced brace", Parser.expand("project/{src,docs"), nil, "err")

check_error("empty pattern", Parser.expand(""), nil, "err")

print(string.format("\n%d passed, %d failed", pass, fail))
os.exit(fail == 0 and 0 or 1)