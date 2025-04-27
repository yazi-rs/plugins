# smart-paste.yazi

Paste files into the hovered directory or into the CWD if hovering over a file.

https://github-production-user-asset-6210df.s3.amazonaws.com/17523360/326047833-080212b5-43e7-4c36-83e8-312495d50383.mp4?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=AKIAVCODYLSA53PQK4ZA%2F20250424%2Fus-east-1%2Fs3%2Faws4_request&X-Amz-Date=20250424T201828Z&X-Amz-Expires=300&X-Amz-Signature=d8e7848297bec24d47cba97a7f8e0dd0722a268847f569d9a49a71192618f1a8&X-Amz-SignedHeaders=host

## Installation

```sh
ya pack -a yazi-rs/plugins:smart-paste
```

## Usage

Add this to your `~/.config/yazi/keymap.toml`:

```toml
[[manager.prepend_keymap]]
on   = "p"
run  = "plugin smart-paste"
desc = "Paste into the hovered directory or CWD"
```

## License

This plugin is MIT-licensed. For more information check the [LICENSE](LICENSE) file.
