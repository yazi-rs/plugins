-- main.lua
-- Orchestrates the full brace.yazi flow: prompt -> parse -> preview -> create.
local Parser = require("parser")
local Fs = require("fs")
local Preview = require("preview")
local Util = require("util")

local Main = {}

-- Ask the user for a brace-expansion pattern.
-- Returns the raw pattern string, or nil if the user cancelled.
local function prompt_pattern()
	local value, event = ya.input({
		title = "Create (brace expansion):",
		position = { "top-center", y = 3, w = 50 },
	})

	if event ~= 1 or Util.is_blank(value) then
		return nil
	end

	return Util.trim(value)
end

-- Resolve a list of relative paths against the current working directory.
local function resolve_paths(cwd, relatives)
	local base = tostring(cwd):gsub("/+$", "")
	local absolute = {}
	for _, rel in ipairs(relatives) do
		absolute[#absolute + 1] = base .. "/" .. rel
	end
	return absolute
end

function Main.run()
	local pattern = prompt_pattern()
	if not pattern then
		return
	end

	local expanded, err = Parser.expand(pattern)
	if not expanded then
		ya.notify({
			title = "brace.yazi: invalid pattern",
			content = err,
			level = "error",
			timeout = 5,
		})
		return
	end

	expanded = Util.sort(Util.dedup(expanded))

	local cwd = cx.active.current.cwd
	local absolute_paths = resolve_paths(cwd, expanded)

	if not Preview.confirm(expanded) then
		return
	end

	local created, failed = Fs.create_all(absolute_paths)

	if #failed == 0 then
		ya.notify({
			title = "brace.yazi",
			content = string.format("Created %d %s.", #created, #created == 1 and "directory" or "directories"),
			level = "info",
			timeout = 3,
		})
	else
		local lines = {}
		for _, f in ipairs(failed) do
			lines[#lines + 1] = f.path .. ": " .. f.error
		end
		ya.notify({
			title = string.format("brace.yazi: %d failed", #failed),
			content = table.concat(lines, "\n"),
			level = "error",
			timeout = 8,
		})
	end

	ya.manager_emit("refresh", {})
end

return Main