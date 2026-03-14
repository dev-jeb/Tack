# Tack

A slim fork of [Ki](https://github.com/andweeb/ki) — modal macOS automation via Hammerspoon.

## Project structure

- `src/` — Main Lua source code
  - `init.lua` — Main orchestration, state machine, event handling
  - `application.lua` — Application base class (all entities inherit from this)
  - `entity.lua` — Base Entity class
  - `defaults.lua` — Entity, URL, file, and normal mode event definitions
  - `entities/` — Individual app entity files (ghostty.lua, google-chrome.lua, cursor.lua)
  - `osascripts/` — AppleScript templates for browser automation
  - `cheatsheet.lua` / `cheatsheet.html` / `cheatsheet.css` — Cheatsheet UI
  - `status-display.lua` — Floating pill mode indicator
- `build.sh` — Builds and symlinks to ~/.hammerspoon/Spoons/Tack.spoon
- `.github/workflows/release.yml` — Creates a release with Tack.spoon.zip on version tags

## Build and test

```bash
make dev        # build and symlink to Spoons directory
make watch-dev  # auto-rebuild on file changes
```

After building, reload Hammerspoon to pick up changes.

## Adding a new entity

1. Create `src/entities/<name>.lua` (see ghostty.lua for a simple example)
2. Register it in `src/defaults.lua`:
   - Add to the `entities` table
   - Add to `entityEvents` in `createEntityEvents()` with a keybinding
   - Optionally add to `entitySelectEvents` for select mode
3. Run `make dev` and reload Hammerspoon

## Adding common shortcuts (all entities)

Add to `commonShortcuts` in `src/application.lua` inside `Application:initialize()`.

## Key conventions

- Entity names passed to `Application:new("Name")` must match the macOS app name exactly
- Menu item names in `createMenuItemEvent()` must match the app's actual menu items
- Shortcut format: `{ modifiers_or_nil, key, handler, { "Category", "Description" } }`

## Important: keep README.md in sync

When adding/removing entities, URLs, modes, or common shortcuts, update the corresponding tables in README.md. The cheatsheet UI updates automatically from the shortcut definitions, but the README does not.

## Release process

Tag a commit and push the tag to trigger a GitHub Action that builds and publishes a release:
```bash
git tag v1.0.0
git push origin v1.0.0
```

## Lua/Hammerspoon gotchas

- Hammerspoon uses Lua 5.4
- `hs.styledtext` does NOT have a `:size()` method
- Use `hs.drawing.windowLevels.modalPanel` for canvas levels (not `hs.canvas.windowLevels`)
- `hs.screen:frame()` returns usable area below menu bar; `hs.screen:fullFrame()` includes menu bar
- Dependencies (fsm, lustache, middleclass) require `lua@5.4` via luarocks with `--lua-dir=/opt/homebrew/opt/lua@5.4`
