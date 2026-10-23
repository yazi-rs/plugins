# which-delay.yazi

Show the which component only when the next key of a chord does not come quickly, like which-key in Neovim.

## Installation

```sh
ya pkg add yazi-rs/plugins:which-delay
```

## Usage

Add this to your `init.lua` to enable the plugin:

```lua
require("which-delay"):setup()
```

Or you can set how long the which component waits, in milliseconds:

```lua
require("which-delay"):setup {
	timeout = 300,
}
```

A chord that you complete before the timeout runs at once, and the which component does not show. A which component that a plugin opens with `ya.which()` shows without a delay.

## License

This plugin is MIT-licensed. For more information check the [LICENSE](LICENSE) file.
