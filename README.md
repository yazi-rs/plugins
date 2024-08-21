> [!WARNING]
> The plugin system is still in the early stage, and most of the plugins below only guarantee compatibility with the latest code of Yazi!
>
> Please make sure that both your Yazi and plugins are on the `HEAD` to ensure proper functionality!

# Plugins

The following plugins can be installed using the `ya pack` package manager introduced in Yazi v0.3.

For specific installation commands and configuration instructions, check the individual `README.md` of each plugin by clicking the link below:

- [full-border.yazi](full-border.yazi) - Add a full border to Yazi to make it look fancier.
- [chmod.yazi](chmod.yazi) - Execute `chmod` on the selected files to change their mode.
- [max-preview.yazi](max-preview.yazi) - Maximize or restore the preview pane.
- [hide-preview.yazi](hide-preview.yazi) - Switch the preview pane between hidden and shown.
- [smart-filter.yazi](smart-filter.yazi) - Makes filters smarter: continuous filtering, automatically enter unique directory, open file on submitting.
- [jump-to-char.yazi](jump-to-char.yazi) - Vim-like `f<char>`, jump to the next file whose name starts with `<char>`.
- [mime-ext.yazi](mime-ext.yazi) - A _common_ file type MIME-type library specifically designed for Yazi.
- [diff.yazi](diff.yazi) - Diff the selected file with the hovered file, create a living patch, and copy it to the clipboard.
- [no-status.yazi](no-status.yazi) - Remove the status bar.
- [mactag.yazi](mactag.yazi) - Bring macOS's awesome tagging feature to Yazi! The plugin is only available for macOS just like the name says.

Note that `ya` is a newly introduced standalone CLI binary, not a shell alias for Yazi (See https://github.com/sxyazi/yazi/issues/914 for details)

If you don't have it, you can also copy each directory ending with `.yazi` to your `~/.config/yazi/plugins` and manually keep them up to date.
