# diff.yazi

Diff the selected file with the hovered file, create a living patch, and copy it to the clipboard.

## Installation

```sh
ya pack -a yazi-rs/plugins#diff
```

## Usage

Add this to your `~/.config/yazi/keymap.toml`:

```toml
[[manager.prepend_keymap]]
on   = [ "<C-d>" ]
run  = "plugin diff"
desc = "Diff the selected with the hovered file"
```

Make sure the <kbd>C</kbd> + <kbd>d</kbd> key is not used elsewhere.
