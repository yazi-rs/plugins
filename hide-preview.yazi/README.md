# hide-preview.yazi

Switch the preview pane between hidden and shown.

## Installation

```sh
ya pack -a yazi-rs/plugins#hide-preview
```

## Usage

Add this to your `~/.config/yazi/keymap.toml`:

```toml
[[manager.prepend_keymap]]
on   = [ "T" ]
run  = "plugin hide-preview"
desc = "Hide or show preview"
```

Make sure the <kbd>T</kbd> key is not used elsewhere.
