--- === Cheatsheet ===
---
--- Cheatsheet modal used to display keyboard shortcuts
---

local Cheatsheet = {}
Cheatsheet.__index = Cheatsheet
Cheatsheet.__name = "Cheatsheet"

local luaVersion = _VERSION:match("%d+%.%d+")

-- luacov: disable
if not _G.getSpoonPath then
    function _G.getSpoonPath()
        return debug.getinfo(2, "S").source:sub(2):match("(.*/)"):sub(1, -2)
    end
end

if not _G.requirePackage then
    function _G.requirePackage(name, isInternal)
        local location = not isInternal and "/deps/share/lua/"..luaVersion.."/" or "/"
        local packagePath = _G.getSpoonPath()..location..name..".lua"

        return dofile(packagePath)
    end
end
-- luacov: enable

local lustache = _G.requirePackage("lustache")

local MODIFIER_GLYPHS = {
    cmd = "⌘",
    alt = "⌥",
    shift = "⇧",
    ctrl = "⌃",
    fn = "fn",
}
local KEY_GLYPHS = {
    ["return"] = "↩",
    enter = "⌤",
    delete = "⌫",
    escape = "⎋",
    right = "→",
    left = "←",
    up = "↑",
    down = "↓",
    pageup = "⇞",
    pagedown = "⇟",
    home = "↖",
    ["end"] = "↘",
    tab = "⇥",
    space = "␣",
}

-- Format a hotkey string from modifier keys and key name
local function formatHotkey(modifierKeys, keyName)
    local hotkey = ""
    for modifierKey, glyph in pairs(MODIFIER_GLYPHS) do
        for _, shortcutModifierKey in pairs(modifierKeys or {}) do
            if modifierKey == shortcutModifierKey then
                hotkey = hotkey..glyph
                break
            end
        end
    end
    keyName = KEY_GLYPHS[keyName or ""] or (keyName or ""):gsub("^%l", string.upper)
    return hotkey..keyName
end

-- Mode categories that should appear as mode cards
local MODE_CATEGORIES = {
    ["Entities"] = { title = "Entity", hotkey = "⌘E", order = 1 },
    ["URL Events"] = { title = "URL", hotkey = "⌘U", order = 2 },
    ["Files"] = { title = "File", hotkey = "⌘F", order = 3 },
    ["Select Events"] = { title = "Select", hotkey = "⌘S", order = 4 },
    ["Normal Mode"] = { title = "Normal", hotkey = "⌘⎋", order = 5 },
}

-- Categories to show as common app shortcuts
local COMMON_CATEGORIES = {
    ["View"] = true,
}

-- Categories to skip entirely
local SKIP_CATEGORIES = {
    ["Cheat Sheet"] = true,
}

-- Build the view model for the cheatsheet
function Cheatsheet._createViewModel(shortcutList)
    local modeItems = {}
    local commonItems = {}

    for _, shortcut in pairs(shortcutList) do
        local modifierKeys = shortcut[_G.SHORTCUT_MODKEY_INDEX] or {}
        local keyName = shortcut[_G.SHORTCUT_HOTKEY_INDEX] or ""
        local metadata = shortcut[_G.SHORTCUT_METADATA_INDEX]

        if metadata and #metadata > 0 and metadata[1] then
            local category = metadata[1]
            local name = metadata[2]

            if SKIP_CATEGORIES[category] then
                -- skip
            elseif MODE_CATEGORIES[category] then
                if not modeItems[category] then
                    modeItems[category] = {}
                end
                local hotkey = formatHotkey(modifierKeys, keyName)
                table.insert(modeItems[category], { name = name, hotkey = hotkey })
            elseif COMMON_CATEGORIES[category] then
                if not commonItems[category] then
                    commonItems[category] = {}
                end
                local hotkey = formatHotkey(modifierKeys, keyName)
                -- Deduplicate
                local found = false
                for _, item in pairs(commonItems[category]) do
                    if item.hotkey == hotkey then found = true break end
                end
                if not found then
                    table.insert(commonItems[category], { name = name, hotkey = hotkey })
                end
            end
        end
    end

    -- Build mode blocks sorted by order
    local modeBlocks = {}
    for category, items in pairs(modeItems) do
        local info = MODE_CATEGORIES[category]
        table.insert(modeBlocks, {
            title = info.title,
            hotkey = info.hotkey,
            order = info.order,
            items = items,
        })
    end
    table.sort(modeBlocks, function(a, b) return a.order < b.order end)

    -- Build common blocks
    local commonBlocks = {}
    for category, items in pairs(commonItems) do
        table.insert(commonBlocks, {
            title = category,
            items = items,
        })
    end
    table.sort(commonBlocks, function(a, b) return a.title < b.title end)

    -- Glyphs (only the ones you'd actually need)
    local glyphs = {
        { hotkey = "⌘", name = "Cmd" },
        { hotkey = "⌥", name = "Opt" },
        { hotkey = "⌃", name = "Ctrl" },
        { hotkey = "⇧", name = "Shift" },
        { hotkey = "⎋", name = "Esc" },
        { hotkey = "␣", name = "Space" },
        { hotkey = "↩", name = "Return" },
        { hotkey = "⌫", name = "Delete" },
    }

    return modeBlocks, commonBlocks, glyphs
end

--- Cheatsheet:show()
--- Method
--- Show the cheatsheet modal. Hit Escape to close.
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function Cheatsheet:show()
    local htmlFilePath = _G.getSpoonPath().."/cheatsheet.html"
    local htmlFile = assert(io.open(htmlFilePath, "rb"))
    local html = htmlFile:read("*all")
    htmlFile:close()

    local appIconUri = nil
    local app = hs.application.get(self.name)

    if app then
        local bundleId = app:bundleID()
        local iconImage = hs.image.imageFromAppBundle(bundleId)
        appIconUri = iconImage:encodeAsURLString()
    end

    local modeBlocks, commonBlocks, glyphs = self._createViewModel(self.shortcuts)

    local title = "Tack"
    local viewModel = {
        title = title,
        icon = appIconUri,
        description = self.description,
        modeBlocks = modeBlocks,
        commonBlocks = commonBlocks,
        glyphs = glyphs,
    }

    self.view:windowTitle(title)

    local frame = hs.screen.mainScreen():fullFrame()
    local w = math.min(frame.w * 0.45, 660)
    local h = math.min(frame.h * 0.7, 720)
    self.view:frame({
        x = frame.x + (frame.w - w) / 2,
        y = frame.y + (frame.h - h) / 2,
        w = w,
        h = h,
    })

    local cheatsheetHtml = lustache:render(html, viewModel)
    self.view:html(cheatsheetHtml)

    self.view:show()
    self.cheatsheetListener = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(event)
        local flags = event:getFlags()
        local keyName = hs.keycodes.map[event:getKeyCode()]

        if flags:containExactly({}) and keyName == "escape" then
            self.view:hide(0.5)
            self.cheatsheetListener:stop()
        end
    end)
    self.cheatsheetListener:start()
end

--- Cheatsheet:init(name, description, shortcuts[, view])
--- Method
--- Initialize the cheatsheet object
---
--- Parameters:
---  * `name` - The subject of the cheatsheet
---  * `description` - The description subtext
---  * `shortcuts` - A table containing the list of shortcuts to display
---  * `view` - An optional hs.webview instance
---
--- Returns:
---  * None
function Cheatsheet:init(name, description, shortcuts, view)
    self.name = name
    self.description = description
    self.shortcuts = shortcuts

    if not view then
        view = hs.webview.new({ x = 0, y = 0, w = 0, h = 0 })
        view:windowStyle({ "utility", "closable", "nonactivating" })
        view:level(hs.drawing.windowLevels.modalPanel)
        view:darkMode(true)
        view:shadow(true)
        view:allowTextEntry(false)
    end

    self.view = view
end

return Cheatsheet
