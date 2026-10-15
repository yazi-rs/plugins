-- tests/range_test.lua
-- Run with: cd tests && lua range_test.lua
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

print("range_test.lua")

check("numeric ascending", Parser.expand("chapter{1..5}"), {
	"chapter1", "chapter2", "chapter3", "chapter4", "chapter5",
})

check("numeric descending", Parser.expand("count{5..1}"), {
	"count5", "count4", "count3", "count2", "count1",
})

check("numeric zero-padded", Parser.expand("img{01..03}"), {
	"img01", "img02", "img03",
})

check("alpha uppercase", Parser.expand("{A..D}"), { "A", "B", "C", "D" })

check("alpha lowercase", Parser.expand("{a..d}"), { "a", "b", "c", "d" })

check("alpha descending", Parser.expand("{d..a}"), { "d", "c", "b", "a" })

print(string.format("\n%d passed, %d failed", pass, fail))
os.exit(fail == 0 and 0 or 1)