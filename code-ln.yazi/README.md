# code-ln.yazi

Preview text files with line numbers in the preview pane.

## Installation

```sh
ya pkg add yazi-rs/plugins:code-ln
```

## Usage

Add to your `yazi.toml`:

**Default mode** — syntax highlighting via `bat`:

```toml
[[plugin.prepend_previewers]]
mime = "text/*"
run = "code-ln"
```

**Fast mode** — plain text with line numbers, near-zero latency:

```toml
[[plugin.prepend_previewers]]
mime = "text/*"
run = "code-ln --fast"
```

## Dependencies

- [bat](https://github.com/sharkdp/bat) — optional. Provides syntax highlighting in default mode. If not installed, automatically falls back to plain text with line numbers.

## License

MIT
