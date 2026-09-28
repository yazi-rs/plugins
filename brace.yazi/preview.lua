-- preview.lua
-- Shows a preview of the directories that will be created and asks the
-- user to confirm via Yazi's own input popup (Enter = create, Esc = cancel).
local Preview = {}

local MAX_LINES = 20

-- Build a human-readable preview body from a list of paths.
local function build_body(paths)
	local lines = {}
	for i, path in ipairs(paths) do
		if i > MAX_LINES then
			lines[#lines + 1] = string.format("  ... and %d more", #paths - MAX_LINES)
			break
		end
		lines[#lines + 1] = "  \xe2\x9c\x93 " .. path -- "✓ path"
	end
	return table.concat(lines, "\n")
end

-- Show the preview notification and ask the user to confirm.
-- Returns true if the user pressed Enter, false if cancelled or Esc.
function Preview.confirm(paths)
	if #paths == 0 then
		ya.notify({
			title = "brace.yazi",
			content = "Nothing to create.",
			level = "warn",
			timeout = 3,
		})
		return false
	end

	ya.notify({
		title = string.format("Will create %d %s", #paths, #paths == 1 and "directory" or "directories"),
		content = build_body(paths),
		level = "info",
		timeout = 6,
	})

	local _, event = ya.input({
		title = "Press Enter to create, Esc to cancel",
		position = { "top-center", y = 3, w = 60 },
	})

	return event == 1
end

return Preview