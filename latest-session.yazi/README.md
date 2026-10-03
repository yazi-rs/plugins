# latest-session.yazi

Save and restore the latest Yazi tabs.

## Features

- Save the current tabs before quitting.
- Restore the latest saved tabs on startup.
- Skip directories that no longer exist.
- Save only tab directories and the active tab index.

## Installation

```sh
ya pkg add yazi-rs/plugins:latest-session
```

## Usage

Add this to your `~/.config/yazi/init.lua`:

```lua
require("latest-session"):setup()
```

Bind quit and close actions in your `~/.config/yazi/keymap.toml`:

```toml
[[mgr.prepend_keymap]]
on   = "q"
run  = "plugin latest-session -- close"
desc = "Close tab, or save tabs and quit"

[[mgr.prepend_keymap]]
on   = "<C-c>"
run  = "plugin latest-session -- quit"
desc = "Save tabs and quit"
```

## Commands

- `save` - Save the current tabs.
- `restore` - Restore the latest saved tabs.
- `quit` - Save the current tabs and quit Yazi.
- `close` - Close the current tab, or save and quit if it is the last tab.

## Session file

The session is stored at:

```text
${XDG_STATE_HOME:-~/.local/state}/yazi/latest-session.lua
```

The session file only stores each tab's directory and the active tab index. It does not store hovered files, selections, filters, sorting, or other UI state.

## License

This plugin is MIT-licensed. For more information check the [LICENSE](LICENSE) file.
