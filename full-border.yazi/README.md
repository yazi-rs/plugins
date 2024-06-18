# full-border.yazi

Add a full border to Yazi to make it look fancier.

## Installation

```sh
ya pack -a yazi-rs/plugins#full-border
```

## Usage

Add this to your `init.lua` to enable the plugin:

```lua
require("full-border"):setup()
```

This plugin overrides the [`Manager.render`](https://github.com/sxyazi/yazi/blob/latest/yazi-plugin/preset/components/manager.lua) method,
you might need to check if any other plugins that also need to override it are enabled.
