# max-preview.yazi

Maximize or restore the preview pane.

## Installation

```sh
ya pack -a yazi-rs/plugins#max-preview
```

## Usage

Add this to your `~/.config/yazi/keymap.toml`:

```toml
[[manager.prepend_keymap]]
on   = [ "T" ]
run  = "plugin max-preview"
desc = "Maximize or restore preview"
```

Make sure the <kbd>T</kbd> key is not used elsewhere.
