# mactag.yazi

Bring macOS's awesome tagging feature to Yazi! The plugin it's only available for macOS just like the name says.

Authors: [@AnirudhG07](https://github.com/AnirudhG07), and [@sxyazi](https://github.com/sxyazi)

## Installation

Install the plugin itself, and [jdberry/tag](https://github.com/jdberry/tag) used to tag files:

```sh
ya pack -a yazi-rs/plugins:mactag
brew update && brew install tag
```

## Setup

Add the following to your `~/.config/yazi/init.lua`:

```lua
require("mactag"):setup {
	-- You can change the colors of the tags here
	keys = {
		r = "Red",
		o = "Orange",
		y = "Yellow",
		g = "Green",
		b = "Blue",
		p = "Purple",
	},
	colors = {
		Red    = "#ee7b70",
		Orange = "#f5bd5c",
		Yellow = "#fbe764",
		Green  = "#91fc87",
		Blue   = "#5fa3f8",
		Purple = "#cb88f8",
	},
}
```

And register it as fetchers in your `~/.config/yazi/yazi.toml`:

```toml
[[plugin.prepend_fetchers]]
id   = "mactag"
name = "*"
run  = "mactag"

[[plugin.prepend_fetchers]]
id   = "mactag"
name = "*/"
run  = "mactag"
```

## Usage

This plugin also provides the functionality to add and remove tags. Add following keybindings to your `~/.config/yazi/keymap.toml` to enable it:

```toml
[[manager.prepend_keymap]]
on   = [ "b", "a" ]
run  = 'plugin mactag --args="add"'
desc = "Add tag to selected files"

[[manager.prepend_keymap]]
on   = [ "b", "r" ]
run  = 'plugin mactag --args="remove"'
desc = "Remove tag from selected files"
```
