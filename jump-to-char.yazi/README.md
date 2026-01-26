# jump-to-char.yazi

Vim-like `f<char>`, jump to the next file whose name starts with `<char>`.

https://github.com/yazi-rs/plugins/assets/17523360/aac9341c-b416-4e0c-aaba-889d48389869

## Installation

```sh
ya pkg add yazi-rs/plugins:jump-to-char
```

## Usage

Add this to your `~/.config/yazi/keymap.toml`:

```toml
[[mgr.prepend_keymap]]
on   = "f"
run  = "plugin jump-to-char"
desc = "Jump to char"
```

By default, this is case sensitive. If you want it to be case insensitive, you
can use `plugin jump-to-char -- --ignorecase`. Similarly, if you want smart
case, i.e. typing a lowercase letter will result in both lowercase and
uppercase characters to be matched, but not the other way around, then you can
use `plugin jump-to-char -- --smartcase`.


Note that, the keybindings above are just examples, please tune them up as needed to ensure they don't conflict with your other commands/plugins.

## License

This plugin is MIT-licensed. For more information check the [LICENSE](LICENSE) file.
