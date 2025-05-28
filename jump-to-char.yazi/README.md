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

Make sure the <kbd>f</kbd> key is not used elsewhere.

## License

This plugin is MIT-licensed. For more information check the [LICENSE](LICENSE) file.
