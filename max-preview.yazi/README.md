# max-preview.yazi

Maximize or restore the preview pane.

https://github.com/yazi-rs/plugins/assets/17523360/8976308e-ebfe-4e9e-babe-153eb1f87d61

## Installation

```sh
ya pack -a yazi-rs/plugins#max-preview
```

## Usage

Add this to your `~/.config/yazi/keymap.toml`:

```toml
[[manager.prepend_keymap]]
on   = "T"
run  = "plugin --sync max-preview"
desc = "Maximize or restore preview"
```

Make sure the <kbd>T</kbd> key is not used elsewhere.
