# compress.yazi

Compress selected files via [7-Zip](https://www.7-zip.org/).

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

Then select one or more files to compress, click <kbd>C</kbd>, and enter a filename that includes a valid archive extension.

## Available extensions

|            |
| ---------- |
| `7z`       |
| `tar.bz2`  |
| `tar.gz`   |
| `tar.gzip` |
| `tar.xz`   |
| `bz2`      |
| `gz `      |
| `tar`      |
| `tbz`      |
| `tbz2`     |
| `tgz`      |
| `txz`      |
| `xz `      |
| `zip`      |
