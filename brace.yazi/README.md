# brace.yazi

Yazi plugin for creating directories using Bash-like brace expansion — pure Lua,
no shell calls, no external dependencies.

## Features

- **Comma list**: `project/{src,include,docs,tests}`
- **Nested braces**: `project/{src/{main,test},docs}`
- **Numeric ranges** (with zero-padding & reverse): `chapter{1..5}`, `img{01..03}`
- **Alphabetic ranges**: `{A..D}`, `{a..d}`
- **Cartesian product**: `{android,desktop}/{debug,release}`
- **Recursive mkdir** (`mkdir -p` equivalent) using Yazi's filesystem API
- **Preview before execution** with Enter/Esc confirmation
- **Clear error messages** for invalid patterns — no crashes

## Installation

```bash
ya pkg add brace
```
Or with author prefix:
```bash
ya pkg add hastagaming/brace
```

## Keymap Configuration

in keymap.toml, add this key:
```bash
[[manager.prepend_keymap]]
on   = ["c", "b"]
run  = "plugin brace"
desc = "Create directories with brace expansion"
```
Press c then b inside Yazi to open the brace expansion prompt.

## Usage

- 1.Press cb in Yazi.
- 2.Type a pattern, e.g.:
    ```Code
    project/{src,include,docs,tests}
    ```
- 3.Plugin displays a preview and asks for confirmation.
- 4.Press Enter to create, Esc or CTRL + c to cancel.

## Supported Patterns

|Pattern | Output|
|---|---|
|project/{src,include,docs} | project/src, project/include, project/docs|<
|project/{src/{main,test},docs} | project/src/main, project/src/test, project/docs|
|chapter{1..5} | chapter1, chapter2, ..., chapter5|
|img{01..05} | img01, img02, ..., img05|
|{A..D} | A, B, C, D|
|{a..d} | a, b, c, d|
|{ios,android}/{arm64,x86} | ios/arm64, ios/x86, android/arm64, android/x86|

## License
see the [MIT](./LICENSE) License