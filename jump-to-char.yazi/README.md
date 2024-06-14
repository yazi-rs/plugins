# jump-to-char.yazi

TODO: add description

## Installation

```sh
ya pack -a yazi-rs/plugins#jump-to-char
```

## Usage

Add this to your `~/.config/yazi/keymap.toml`:

```toml
[[manager.prepend_keymap]]
on = [ "f" ]
run = "plugin jump-to-char"
desc = "Jump to char"
```

Make sure the <kbd>f</kbd> key is not used elsewhere.
