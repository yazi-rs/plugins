# mount.yazi

A mount manager for Yazi, providing disk mount, unmount, and eject functionality.

Supported platforms:

- Linux with [`udisksctl`](https://github.com/storaged-project/udisks), `lsblk` and `eject` both provided by [`util-linux`](https://github.com/util-linux/util-linux)
- macOS with `diskutil`, which is pre-installed

https://github.com/user-attachments/assets/c6f780ab-458b-420f-85cf-2fc45fcfe3a2

## Installation

```sh
ya pkg add yazi-rs/plugins:mount
```

## Usage

Add this to your `~/.config/yazi/keymap.toml`:

```toml
[[mgr.prepend_keymap]]
on  = "M"
run = "plugin mount"
```

Note that, the keybindings above are just examples, please tune them up as needed to ensure they don't conflict with your other commands/plugins.

## Configuration

You can customize the plugin by adding the following to your `~/.config/yazi/init.lua`:

```lua
require("mount"):setup({
    -- Customizable keybindings (all optional, showing defaults)
    keys = {
        quit = "q",
        up = "k",
        down = "j",
        enter = "l",
        mount = "m",
        unmount = "u",
        eject = "e",
    },

    -- Create symlinks to mounted drives (default: false)
    symlinks = false,

    -- Directory for symlinks (default: $HOME)
    symlink_dir = "/path/to/symlinks",

    -- Filter out the entire drive containing the root partition (default: true)
    exclude_root_drive = true,

    -- Filter out partitions mounted at these paths (default: {"/", "/boot", "/boot/efi"})
    exclude_mounts = { "/", "/boot", "/boot/efi" },

    -- Filter out partitions with these filesystem types (default: {})
    exclude_fstypes = { "swap" },

    -- Filter out devices matching these patterns (default: {})
    exclude_devices = { "^/dev/sda", "^/dev/nvme0n1" },

    -- Show keybinding hints at the bottom (default: true)
    show_help = true,
})
```

### Options

| Option               | Type    | Default                        | Description                                        |
| -------------------- | ------- | ------------------------------ | -------------------------------------------------- |
| `keys`               | table   | -                              | Custom keybindings for plugin actions              |
| `symlinks`           | boolean | `false`                        | Create symlinks to mounted drives                  |
| `symlink_dir`        | string  | `$HOME`                        | Directory where symlinks are created               |
| `exclude_root_drive` | boolean | `true`                         | Hide the entire drive containing the root (`/`) partition |
| `exclude_mounts`     | table   | `{"/", "/boot", "/boot/efi"}`  | Hide partitions mounted at these paths             |
| `exclude_fstypes`    | table   | `{}`                           | Hide partitions with these filesystem types        |
| `exclude_devices`    | table   | `{}`                           | Hide devices matching these Lua patterns           |
| `show_help`          | boolean | `true`                         | Show keybinding hints at the bottom of the window  |

### Filtering

By default, the plugin hides your OS drive to prevent accidental unmounting of system partitions. This is controlled by `exclude_root_drive = true`, which automatically detects and hides the entire drive (e.g., `/dev/sda` or `/dev/nvme0n1`) that contains your root filesystem.

For more granular control, you can:

- Use `exclude_mounts` to hide specific mount points
- Use `exclude_fstypes` to hide certain filesystem types (e.g., `{"swap", "tmpfs"}`)
- Use `exclude_devices` to hide devices by pattern (e.g., `{"^/dev/sda"}` to hide all `/dev/sda*` partitions)

To show all drives including your OS drive (use with caution):

```lua
require("mount"):setup({
    exclude_root_drive = false,
    exclude_mounts = {},
})
```

### Symlinks

When `symlinks` is enabled:

- A symlink is created in `symlink_dir` when a partition is mounted
- The symlink is named after the volume label (if available) or the partition name (e.g., `sda1`)
- The symlink is automatically removed when the partition is unmounted or ejected
- Only actual symlinks are removed (regular files/directories are never deleted)

## Actions

| Key binding  | Alternate key | Action                |
| ------------ | ------------- | --------------------- |
| <kbd>q</kbd> | -             | Quit the plugin       |
| <kbd>k</kbd> | <kbd>↑</kbd>  | Move up               |
| <kbd>j</kbd> | <kbd>↓</kbd>  | Move down             |
| <kbd>l</kbd> | <kbd>→</kbd>  | Smart action: mount if unmounted, or unmount+eject if mounted (then close) |
| <kbd>m</kbd> | -             | Mount the partition or disk |
| <kbd>u</kbd> | -             | Unmount the partition or disk |
| <kbd>e</kbd> | -             | Eject the partition or disk |

## Disk Operations

When a disk (main device) is selected instead of a partition, the actions work as follows:

| Action    | Behavior                                                      |
| --------- | ------------------------------------------------------------- |
| Mount     | Mounts all unmounted partitions on the disk that have a filesystem |
| Unmount   | Unmounts all mounted partitions on the disk                   |
| Eject     | Unmounts all partitions and powers off the disk               |

## TODO

- Windows support (I don't use Windows myself, PRs welcome!)

## License

This plugin is MIT-licensed. For more information check the [LICENSE](LICENSE) file.
