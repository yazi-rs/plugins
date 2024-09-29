# mime-ext.yazi

A mime-type provider based on a file extension database, replacing the builtin `file(1)` to speed up mime-type retrieval at the expense of accuracy.

See https://yazi-rs.github.io/docs/tips#make-yazi-even-faster for more information.

## Installation

```sh
ya pack -a yazi-rs/plugins:mime-ext
```

## Setup

Add the following to your `~/.config/yazi/init.lua`:
```lua
require("mime-ext"):setup()

-- Or you can customize some options
require("mime-ext"):setup {
    -- You can extend existing tables with your custom file names and extensions

    -- Table that maps case-insensitive file names to MIME types
    with_files = {
        makefile = "text/x-makefile",
        -- ...
    },

    -- Table that maps case-insensitive file extensions to MIME types
    with_exts = {
        -- match any file with extension, for example `config.mk`
        mk = "text/x-makefile",
        -- ...
    },

    -- If the MIME type is not found by extension or file name,
    -- then fallback to yazi's default MIME plugin, which uses file(1)
    fallback_mime = true,
}
```

Add this to your `~/.config/yazi/yazi.toml`:

```toml
[[plugin.prepend_fetchers]]
id   = "mime"
if   = "!mime"
name = "*"
run  = "mime-ext"
prio = "high"
```

## TODO

- Add more file types (PRs welcome!).
- Eliminating `x-` as part of Yazi v0.4 as it's discouraged as per [rfc6838#section-3.4](https://datatracker.ietf.org/doc/html/rfc6838#section-3.4)
- Compress mime-type tables.
