# compress.yazi

Compress selected or hovered local files. Requires current nightly Yazi and maintained 7-Zip (`7zz` or `7z`).

## Installation

```sh
ya pkg add yazi-rs/plugins:compress
```

## Usage

```toml
[[mgr.prepend_keymap]]
on = "C"
run = "plugin compress"
desc = "Create archive"
```
