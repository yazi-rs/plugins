-- tests/nested_test.lua
-- Run with: cd tests && lua nested_test.lua
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

print("nested_test.lua")

check("basic nested", Parser.expand("project/{src/{main,test},docs}"), {
	"project/src/main", "project/src/test", "project/docs",
})

check("deep nested", Parser.expand("a/{b/{c,d},e/{f,g}}"), {
	"a/b/c", "a/b/d", "a/e/f", "a/e/g",
})

check("nested with range", Parser.expand("ch{1..2}/{intro,body}"), {
	"ch1/intro", "ch1/body", "ch2/intro", "ch2/body",
})

print(string.format("\n%d passed, %d failed", pass, fail))
os.exit(fail == 0 and 0 or 1)