# compress.yazi

Compress one or more selected files within Yazi:

- Supports [14 archive formats](https://github.com/yazi-rs/plugins/tree/main/compress.yazi), with more to be added in the future
- Real-time compression progress reporting
- Password protection
- Cross-directory compression

This plugin is currently experimental and requires Yazi nightly. If you run into any issues, please [file a bug report](https://github.com/yazi-rs/plugins/issues/new?template=bug.yml).

https://github.com/user-attachments/assets/aeede387-f0cb-42bd-9df1-33c51e433779

## Installation

```sh
ya pkg add yazi-rs/plugins:compress
```

## Usage

Create a key binding in your `keymap.toml`, for example:

```toml
[[mgr.prepend_keymap]]
on   = "C"
run  = "plugin compress"
desc = "Compress selected files"
```

Then select some files, click <kbd>C</kbd>, and enter a filename that includes a valid archive extension.

## Available extensions

| Ext        | Backend     |
| ---------- | ----------- |
| `7z`       | [7-Zip][7z] |
| `tar.bz2`  | [7-Zip][7z] |
| `tar.gz`   | [7-Zip][7z] |
| `tar.gzip` | [7-Zip][7z] |
| `tar.xz`   | [7-Zip][7z] |
| `bz2`      | [7-Zip][7z] |
| `gz`       | [7-Zip][7z] |
| `tar`      | [7-Zip][7z] |
| `tbz`      | [7-Zip][7z] |
| `tbz2`     | [7-Zip][7z] |
| `tgz`      | [7-Zip][7z] |
| `txz`      | [7-Zip][7z] |
| `xz `      | [7-Zip][7z] |
| `zip`      | [7-Zip][7z] |

[7z]: https://www.7-zip.org/
