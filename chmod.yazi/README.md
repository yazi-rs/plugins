# chmod.yazi

Execute `chmod` on the selected files to change their mode. This plugin is only available on Unix platforms since it relies on [`chmod(2)`](https://man7.org/linux/man-pages/man2/chmod.2.html).

https://github.com/yazi-rs/plugins/assets/17523360/7aa3abc2-d057-498c-8473-a6282c59c464

## Installation

```sh
ya pkg add yazi-rs/plugins:chmod
```

## Usage

Add this to your `~/.config/yazi/keymap.toml`:

```toml
[[mgr.prepend_keymap]]
on   = [ "c", "m" ]
run  = "plugin chmod"
desc = "Chmod on selected files"
```

Make sure the <kbd>c</kbd> => <kbd>m</kbd> key is not used elsewhere.

## License

This plugin is MIT-licensed. For more information check the [LICENSE](LICENSE) file.
