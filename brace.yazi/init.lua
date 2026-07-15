-- init.lua
-- Entry point for brace.yazi.
-- Yazi loads this when the plugin is invoked, e.g. via `plugin brace` in keymap.toml.
local Main = require("main")

return {
	entry = function()
		Main.run()
	end,
}