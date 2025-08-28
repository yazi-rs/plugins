# jj.yazi

Show the status of Jujutsu (jj) file changes as linemode in the file list.

## Installation

```sh
ya pkg add yazi-rs/plugins:jj
```

## Setup

Add the following to your `~/.config/yazi/init.lua`:

```lua
require("jj"):setup()
```

And register it as fetchers in your `~/.config/yazi/yazi.toml`:

```toml
[[plugin.prepend_fetchers]]
id   = "jj"
name = "*"
run  = "jj"

[[plugin.prepend_fetchers]]
id   = "jj"
name = "*/"
run  = "jj"
```

## Advanced

> [!NOTE]  
> The following configuration must be put before `require("jj"):setup()`

You can customize the [Style](https://yazi-rs.github.io/docs/plugins/layout#style) of the status sign with:

- `th.jj.conflicted`
- `th.jj.renamed`
- `th.jj.modified`
- `th.jj.added`
- `th.jj.deleted`
- `th.jj.updated`

For example:

```lua
-- ~/.config/yazi/init.lua
th.jj = th.jj or {}
th.jj.modified = ui.Style():fg("blue")
th.jj.deleted = ui.Style():fg("red"):bold()
```

You can also customize the text of the status sign with:

- `th.jj.conflicted_sign`
- `th.jj.renamed_sign`
- `th.jj.modified_sign`
- `th.jj.added_sign`
- `th.jj.deleted_sign`
- `th.jj.updated_sign`

For example:

```lua
-- ~/.config/yazi/init.lua
th.jj = th.jj or {}
th.jj.modified_sign = "M"
th.jj.deleted_sign = "D"
```

## License

This plugin is MIT-licensed. For more information check the [LICENSE](LICENSE) file.
