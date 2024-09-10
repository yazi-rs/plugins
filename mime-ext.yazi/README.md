# mime-ext.yazi

A mime-type provider based on a file extension database, replacing the builtin `file(1)` to speed up mime-type retrieval at the expense of accuracy.

See https://yazi-rs.github.io/docs/tips#make-yazi-even-faster for more information.

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
