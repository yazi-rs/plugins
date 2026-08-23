# visual-pivot.yazi

Vim-like `o` for Yazi visual selections.

Pressing the binding moves the cursor to the other end of the selection while keeping the selected files unchanged. Wrapped selections work too.

## Installation

```sh
ya pkg add yazi-rs/plugins:visual-pivot
```

## Usage

```toml
# keymap.toml
[[mgr.prepend_keymap]]
on   = "<C-o>"
run  = "plugin visual-pivot"
desc = "Move cursor to the other end of the selection"
```

Note that, the keybindings above are just examples, please tune them up as needed to ensure they don't conflict with your other actions/plugins.
