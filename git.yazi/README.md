# git.yazi

Show the status of Git file changes as linemode in the file list.

https://github.com/user-attachments/assets/34976be9-a871-4ffe-9d5a-c4cdd0bf4576

## Installation

```sh
ya pack -a yazi-rs/plugins:git
```

## Setup

Add the following to your `~/.config/yazi/init.lua`:

```lua
require("git"):setup()
```

And register it as fetchers in your `~/.config/yazi/yazi.toml`:

```toml
[[plugin.prepend_fetchers]]
id   = "git"
name = "*"
run  = "git"

[[plugin.prepend_fetchers]]
id   = "git"
name = "*/"
run  = "git"
```
