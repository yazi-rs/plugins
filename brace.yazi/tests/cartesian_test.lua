-- tests/cartesian_test.lua
-- Run with: cd tests && lua cartesian_test.lua
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

print("cartesian_test.lua")

check("basic cartesian", Parser.expand("{android,desktop}/{debug,release}"), {
	"android/debug", "android/release", "desktop/debug", "desktop/release",
})

check("triple cartesian", Parser.expand("{a,b}/{c,d}/{e,f}"), {
	"a/c/e", "a/c/f", "a/d/e", "a/d/f",
	"b/c/e", "b/c/f", "b/d/e", "b/d/f",
})

check("cartesian with literal glue", Parser.expand("build/{ios,android}-{arm64,x86}"), {
	"build/ios-arm64", "build/ios-x86",
	"build/android-arm64", "build/android-x86",
})

print(string.format("\n%d passed, %d failed", pass, fail))
os.exit(fail == 0 and 0 or 1)