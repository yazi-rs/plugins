# git.yazi

> [!NOTE]
> Yazi v0.3.3 or later is required for this plugin to work.

Show the status of Git file changes as linemode in the file list.

https://github.com/user-attachments/assets/34976be9-a871-4ffe-9d5a-c4cdd0bf4576

## Installation

```sh
ya pack -a yazi-rs/plugins:git
```

## Setup

Add the following to your `~/.config/yazi/init.lua`:

```lua
require("git"):setup()
```

And register it as fetchers in your `~/.config/yazi/yazi.toml`:

```toml
[[plugin.prepend_fetchers]]
id   = "git"
name = "*"
run  = "git"

[[plugin.prepend_fetchers]]
id   = "git"
name = "*/"
run  = "git"
```

## Advanced

> [!NOTE]
> This section currently requires Yazi nightly that includes https://github.com/sxyazi/yazi/pull/1637

You can customize the [Style](https://yazi-rs.github.io/docs/plugins/layout#style) of the status sign with:

- `THEME.git_modified`
- `THEME.git_added`
- `THEME.git_untracked`
- `THEME.git_ignored`
- `THEME.git_deleted`
- `THEME.git_updated`

For example:

```lua
-- ~/.config/yazi/init.lua
THEME.git_modified = ui.Style():fg("blue")
THEME.git_deleted = ui.Style():fg("red"):bold()
```

You can also customize the text of the status sign with:

- `THEME.git_modified_sign`
- `THEME.git_added_sign`
- `THEME.git_untracked_sign`
- `THEME.git_ignored_sign`
- `THEME.git_deleted_sign`
- `THEME.git_updated_sign`

For example:

```lua
-- ~/.config/yazi/init.lua
THEME.git_modified_sign = "M"
THEME.git_deleted_sign = "D"
```
