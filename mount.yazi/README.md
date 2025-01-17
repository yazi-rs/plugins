# mount.yazi

> [!NOTE]
> The plugin is currently very experimental, and the newest Yazi nightly is required for it to work.

A mount manager for Yazi, providing disk mount, unmount, and eject functionality.

Supported platforms:

- Linux with `udisksctl`
- macOS with `diskutil`

## Installation

```sh
ya pack -a yazi-rs/plugins:mount
```

## Usage

Add this to your `~/.config/yazi/keymap.toml`:

```toml
[[manager.prepend_keymap]]
on  = "M"
run = 'plugin mount'
```

Available keybindings:

| Key binding  | Action                |
| ------------ | --------------------- |
| <kbd>q</kbd> | Quit the plugin       |
| <kbd>k</kbd> | Move up               |
| <kbd>j</kbd> | Move down             |
| <kbd>l</kbd> | Enter the mount point |
| <kbd>m</kbd> | Mount the partition   |
| <kbd>M</kbd> | Unmount the partition |
| <kbd>e</kbd> | Eject the disk        |

## TODO

- Custom keybindings
- Windows support (I don't have an Windows machine for testing, PRs welcome!)
- Support mount, unmount, and eject the entire disk

## License

This plugin is MIT-licensed. For more information check the [LICENSE](LICENSE) file.
