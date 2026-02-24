# git-nav.yazi

Helper plugin for Yazi to navigate through Git repo
- go to git root `git-top`
- go to git superproject root `git-super`
- go to git directory `.git`
- open lazygit `lazygit` (if installed)
- go to next changed file `git-next`
- go to previous changed file `git-prev`


## Installation

```sh
ya pkg add yazi-rs/plugins:git-nav
```

## Setup

prerequirements:
- Yazi installed
- Git installed
- (optional) lazygit installed


### Keymaps

Add the following to your `~/.config/yazi/keymap.toml` to enable keymaps for git navigation:
modify the file to your liking.

```keymap.toml
[mgr]
prepend_keymap = [
  { on = ["g", "t"], run = "plugin git-nav root",  desc = "Git root" },
  { on = ["g", "s"], run = "plugin git-nav super", desc = "Git superproject root" },
  { on = ["g", "g"], run = "plugin git-nav gitdir", desc = "Git directory" },
  { on = ["g", "l"], run = "plugin git-nav lazygit", desc = "Open lazygit" },
  { on = ["]", "g"], run = "plugin git-nav next", desc = "Next changed file" },
  { on = ["[", "g"], run = "plugin git-nav prev", desc = "Previous changed file" },
...
]
```

## License

This plugin is MIT-licensed. For more information check the [LICENSE](LICENSE) file.
