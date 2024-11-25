# max-preview.yazi

Maximize or restore the preview pane.

https://github.com/yazi-rs/plugins/assets/17523360/8976308e-ebfe-4e9e-babe-153eb1f87d61

## Installation

```sh
ya pack -a yazi-rs/plugins:max-preview
```

## Usage

Add this to your `~/.config/yazi/keymap.toml`:

```toml
[[manager.prepend_keymap]]
on   = "T"
run  = "plugin --sync max-preview"
# For upcoming Yazi 0.4 (nightly version):
# run  = "plugin max-preview"
desc = "Maximize or restore preview"
```

Make sure the <kbd>T</kbd> key is not used elsewhere.

## Tips

This plugin only maximizes the "available preview area", without actually changing the content size.

This means that the appearance of your preview largely depends on the previewer you are using.
However, most previewers tend to make the most of the available space, so this usually isn't an issue.

For image previews, you may want to tune up the [`max_width`][max-width] and [`max_height`][max-height] options in your `yazi.toml`:

```toml
[preview]
# Change them to your desired values
max_width  = 1000
max_height = 1000
```

[max-width]: https://yazi-rs.github.io/docs/configuration/yazi/#preview.max_width
[max-height]: https://yazi-rs.github.io/docs/configuration/yazi/#preview.max_height

## License

This plugin is MIT-licensed. For more information check the [LICENSE](LICENSE) file.
