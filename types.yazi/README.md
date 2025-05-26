# types.yazi

Type definitions for Yazi's Lua API, empowering an efficient plugin development experience.

## Installation

```sh
ya pack -a yazi-rs/plugins:types
```

## Usage

### Neovim

```lua
require("lspconfig").lua_ls.setup {
  settings = {
    Lua = {
      workspace = {
        library = {
          vim.fn.expand("$HOME/.config/yazi/plugins/types.yazi"),
        },
      },
    },
  },
}
```

### Other editors

PRs are welcome!

## Contributing

All type definitions are automatically generated using [typegen.js][typegen.js] based on the latest [plugin documentation][plugin documentation],
so contributions should be made in the [`yazi-rs.github.io` repository][doc-repo].

[typegen.js]: https://github.com/yazi-rs/yazi-rs.github.io/blob/main/scripts/typegen.js
[plugin documentation]: https://yazi-rs.github.io/docs/plugins/overview
[doc-repo]: https://github.com/yazi-rs/yazi-rs.github.io

## License

This plugin is MIT-licensed. For more information, check the [LICENSE](LICENSE) file.
