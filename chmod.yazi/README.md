# chmod.yazi

Execute `chmod` on the selected files to change their mode. This plugin is only available on Unix platforms since it relies on [`chmod(2)`](https://man7.org/linux/man-pages/man2/chmod.2.html).

## Installation

```sh
ya pack -a yazi-rs/plugins#chmod
```

## Usage

Add this to your `~/.config/yazi/keymap.toml`:

```toml
[[manager.prepend_keymap]]
on   = [ "c", "m" ]
run  = "plugin chmod"
desc = "Chmod on selected files"
```

Make sure the <kbd>c</kbd> => <kbd>m</kbd> key is not used elsewhere.
