# mime-ext.yazi

A _common_ file type MIME-type library specifically designed for Yazi. Ensuring strict compliance with IANA-registered media types is not its primary goal.

It is still in a very early stage and currently requires the [latest nightly build of Yazi](https://github.com/sxyazi/yazi/releases/tag/nightly).

## Installation

```sh
ya pack -a yazi-rs/plugins:mime-ext
```

## Usage

Add this to your `~/.config/yazi/yazi.toml`:

```toml
[[plugin.prepend_fetchers]]
id   = "mime"
if   = "!mime"
name = "*"
run  = "mime-ext"
prio = "high"
```

## TODO

- Add more file types (PRs welcome!).
- Allow configuring the plugin and overriding some of its rules.
- Eliminating `x-` as part of Yazi v0.4 as it's discouraged as per [rfc6838#section-3.4](https://datatracker.ietf.org/doc/html/rfc6838#section-3.4)
- Compress mime-type tables.
