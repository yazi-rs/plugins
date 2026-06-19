# dir-rules.yazi

Directory-specific rules for yazi.

## Installation

```sh
ya pkg add yazi-rs/plugins:dir-rules
```

## Usage

Add the following to your `~/.config/yazi/init.lua`:

```lua
require("dir-rules"):setup {
  rules = {
    -- Any directory ending in `screenshots`
    screenshots = {
      -- See https://yazi-rs.github.io/docs/configuration/keymap#manager.sort
      -- for all options
      sort = { "alphabetical", reverse = true },
      hidden = { "hide" },
    },
    -- A little more specific with the directory structure
    ["Downloads/tmp/docs"] = {
      linemode = { "permissions" },
      hidden = { "show" },
    }
  }
}
```

## License

This plugin is MIT-licensed. For more information check the [LICENSE](LICENSE) file.
