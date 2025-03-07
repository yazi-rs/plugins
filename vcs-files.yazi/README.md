# vcs-files.yazi

> [!WARNING]
> The latest nightly build of Yazi is required at the moment, to use this plugin.

Show Git changed files in Yazi.

https://github.com/user-attachments/assets/465b801b-3516-4f57-be09-8405da21e34d

## Installation

```sh
ya pack -a yazi-rs/plugins:vcs-files
```

## Usage

```toml
# keymap.toml
[[manager.prepend_keymap]]
on   = [ "g", "c" ]
run  = "plugin vcs-files"
desc = "Show Git changed files"
```

## TODO

- [ ] Add support for other VCS (e.g. Mercurial, Subversion)
