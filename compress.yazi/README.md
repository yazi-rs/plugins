# compress.yazi

Compress one or more selected files within Yazi:

- Supports [10 archive formats](#available-extensions), with more to be added in the future
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

## Available formats

| Format      | Extension | Backend     |
| ----------- | --------- | ----------- |
| 7z          | `7z`      | [7-Zip][7z] |
| TAR + BZIP2 | `tar.bz2` | [7-Zip][7z] |
| TAR + GZIP  | `tar.gz`  | [7-Zip][7z] |
| TAR + XZ    | `tar.xz`  | [7-Zip][7z] |
| BZIP2       | `bz2`     | [7-Zip][7z] |
| GZIP        | `gz`      | [7-Zip][7z] |
| TAR         | `tar`     | [7-Zip][7z] |
| WIM         | `wim`     | [7-Zip][7z] |
| XZ          | `xz`      | [7-Zip][7z] |
| ZIP         | `zip`     | [7-Zip][7z] |

[7z]: https://www.7-zip.org/
