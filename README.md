# Tack

A slim, opinionated fork of [Ki](https://github.com/andweeb/ki) — modal macOS automation via [Hammerspoon](http://www.hammerspoon.org). For the full philosophy and background, see the [Ki README](https://github.com/andweeb/ki#readme).

Tack strips Ki down to just the apps, URLs, and workflows I actually use daily.

## Supported Entities

Enter entity mode with `Cmd+Escape` then `Cmd+E`:

Key | App
:---: | :---
`c` | Cursor
`g` | Google Chrome
`t` | Ghostty

## URLs

Enter URL mode with `Cmd+Escape` then `Cmd+U`:

Key | URL
:---: | :---
`a` | AWS Console
`g` | GitHub
`h` | Hacker News
`p` | Pulumi

## Modes

Key | Mode | Purpose
:---: | :--- | :---
`Cmd+Esc` | Normal | Entry point from desktop
`Cmd+E` | Entity | Launch/focus an app
`Cmd+A` | Action | Pick an action, then an app
`Cmd+S` | Select | Choose from windows/tabs
`Cmd+F` | File | Browse files and folders
`Cmd+U` | URL | Open a saved URL

`Escape` exits back to desktop from any mode.

## Installation

1. Install [Hammerspoon](http://www.hammerspoon.org)
2. Download `Tack.spoon.zip` from the [latest release](../../releases/latest)
3. Unzip and move `Tack.spoon` to `~/.hammerspoon/Spoons/`
4. Add to `~/.hammerspoon/init.lua`:

```lua
hs.loadSpoon('Tack')
spoon.Tack:start()
```

5. Reload Hammerspoon

## Development

For contributors or anyone wanting to build from source:

```bash
# Prerequisites
brew install luarocks lua@5.4

# Clone and install dependencies
git clone <repo-url>
cd tack
luarocks --lua-dir=/opt/homebrew/opt/lua@5.4 install --lua-version 5.4 --tree deps fsm 1.1.0-1
luarocks --lua-dir=/opt/homebrew/opt/lua@5.4 install --lua-version 5.4 --tree deps lustache 1.3.1-0
luarocks --lua-dir=/opt/homebrew/opt/lua@5.4 install --lua-version 5.4 --tree deps middleclass 4.1.1-0

# Build and symlink to Spoons directory
make dev

# Auto-rebuild on file changes
make watch-dev
```

## License

MIT — forked from [Ki](https://github.com/andweeb/ki) by Andrew Kwon.
