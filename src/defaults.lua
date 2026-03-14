--- === Defaults ===
---
--- Definitions of default events and entities
---
-- luacov: disable

local Defaults = {}
Defaults.__index = Defaults
Defaults.__name = "default"

Defaults.events = {}
Defaults.entities = {}

if not _G.requirePackage then
    function _G.requirePackage(name, isInternal)
        local luaVersion = _VERSION:match("%d+%.%d+")
        local location = not isInternal and "/deps/share/lua/" .. luaVersion .. "/" or "/"
        local spoonPath = debug.getinfo(2, "S").source:sub(2):match("(.*/)"):sub(1, -2)
        local packagePath = spoonPath .. location .. name .. ".lua"

        return dofile(packagePath)
    end
end

local File = _G.requirePackage("file", true)


local entities = {
    Cursor = _G.requirePackage("entities/cursor", true),
    Ghostty = _G.requirePackage("entities/ghostty", true),
    GoogleChrome = _G.requirePackage("entities/google-chrome", true),
}

--- Defaults.createFileEvents()
--- Method
--- Defines the initial set of actions with predefined keybindings for `file` mode
---
--- Parameters:
---  * None
---
--- Returns:
---  * A list of `file` workflow events
function Defaults.createFileEvents()
    local fileEvents = {
        { nil, "a", File:new("/Applications"), { "Files", "Applications" } },
        { nil, "d", File:new("~/Desktop"),     { "Files", "Desktop" } },
    }

    return fileEvents
end

--- Defaults.createEntityEvents()
--- Method
--- Defines the initial set of actions with predefined keybindings for `entity` and `select` mode
---
--- Parameters:
---  * None
---
--- Returns:
---  * A list of `entity` workflow events
---  * A list of `select` workflow events
function Defaults.createEntityEvents()
    local entityEvents = {
        { nil, "c", entities.Cursor,       { "Entities", "Cursor" } },
        { nil, "g", entities.GoogleChrome, { "Entities", "Google Chrome" } },
        { nil, "t", entities.Ghostty,      { "Entities", "Ghostty" } },
    }

    local entitySelectEvents = {
        { nil, "c", entities.Cursor,       { "Select Events", "Select a Cursor window" } },
        { nil, "g", entities.GoogleChrome, { "Select Events", "Select a Google Chrome tab or window" } },
        { nil, "t", entities.Ghostty,      { "Select Events", "Select a Ghostty window" } },
    }

    return entityEvents, entitySelectEvents
end

--- Defaults.createUrlEvents()
--- Method
--- Defines the initial set of actions with predefined keybindings for `url` mode
---
--- Parameters:
---  * None
---
--- Returns:
---  * A list of `url` workflow events
---  * A table of `url` entities
function Defaults.createUrlEvents(URL)
    local urls = {
        AWSConsole = URL:new("https://console.aws.amazon.com"),
        GitHub = URL:new("https://github.com"),
        HackerNews = URL:new("https://news.ycombinator.com"),
        Pulumi = URL:new("https://app.pulumi.com"),
    }

    urls.HackerNews.paths = {
        { name = "Hacker News", path = "https://news.ycombinator.com" },
        { name = "New",         path = "/newest" },
        { name = "Threads",     path = "/threads" },
        { name = "Past",        path = "/front" },
        { name = "Comments",    path = "/newcomments" },
        { name = "Ask",         path = "/ask" },
        { name = "Show",        path = "/show" },
        { name = "Jobs",        path = "/jobs" },
        { name = "Submit",      path = "/submit" },
    }

    local urlEvents = {
        { nil, "a", urls.AWSConsole, { "URL Events", "AWS Console" } },
        { nil, "g", urls.GitHub,     { "URL Events", "GitHub" } },
        { nil, "h", urls.HackerNews, { "URL Events", "Hacker News" } },
        { nil, "p", urls.Pulumi,     { "URL Events", "Pulumi" } },
    }

    return urlEvents, urls
end

--- Defaults.createNormalEvents()
--- Method
--- Defines the initial set of actions with predefined keybindings for `normal` mode
---
--- Parameters:
---  * None
---
--- Returns:
---  * A list of `normal` workflow events
function Defaults.createNormalEvents(Tack)
    local actions = {}

    function actions.logout()
        Tack.state:exitMode()

        hs.timer.doAfter(0, function()
            hs.focus()

            local answer = hs.dialog.blockAlert("Log out from your computer?", "", "Log out", "Cancel")

            if answer == "Log out" then
                hs.osascript.applescript([[ tell application "System Events" to log out ]])
            end
        end)
    end

    function actions.startScreenSaver()
        hs.osascript.applescript([[
            tell application "System Events" to start current screen saver
        ]])

        return true
    end

    function actions.sleep()
        Tack.state:exitMode()
        hs.osascript.applescript([[ tell application "Finder" to sleep ]])
    end

    function actions.restart()
        Tack.state:exitMode()

        hs.timer.doAfter(0, function()
            hs.focus()

            local answer = hs.dialog.blockAlert("Restart your computer?", "", "Restart", "Cancel")

            if answer == "Restart" then
                hs.osascript.applescript([[ tell application "Finder" to restart ]])
            end
        end)
    end

    function actions.shutdown()
        Tack.state:exitMode()

        hs.timer.doAfter(0, function()
            hs.focus()

            local answer = hs.dialog.blockAlert("Shut down your computer?", "", "Shut Down", "Cancel")

            if answer == "Shut Down" then
                hs.osascript.applescript([[ tell application "System Events" to shut down ]])
            end
        end)
    end

    local desktopVisible = false
    local hiddenApps = {}

    function actions.showDesktop()
        if not desktopVisible then
            hiddenApps = {}
            local apps = hs.application.runningApplications()
            for _, app in ipairs(apps) do
                if app:kind() == 1 and not app:isHidden() and app:name() ~= "Finder" then
                    table.insert(hiddenApps, app)
                    app:hide()
                end
            end
            desktopVisible = true
        else
            for _, app in ipairs(hiddenApps) do
                app:unhide()
            end
            hiddenApps = {}
            desktopVisible = false
        end
        return true
    end

    function actions.screenshot()
        hs.task.new("/usr/bin/open", nil, { "-a", "Screenshot" }):start()
        return true
    end

    local normalEvents = {
        { nil,               "d", actions.showDesktop,      { "Normal Mode", "Show Desktop" } },
        { nil,               "p", actions.screenshot,       { "Normal Mode", "Screenshot" } },
        { { "ctrl" },        "l", actions.logout,           { "Normal Mode", "Log Out" } },
        { { "ctrl" },        "q", actions.shutdown,         { "Normal Mode", "Shut Down" } },
        { { "ctrl" },        "r", actions.restart,          { "Normal Mode", "Restart" } },
        { { "ctrl" },        "s", actions.sleep,            { "Normal Mode", "Sleep" } },
        { { "cmd", "ctrl" }, "s", actions.startScreenSaver, { "Normal Mode", "Enter Screen Saver" } },
    }

    return normalEvents
end

--- Defaults.create(Tack) -> events, entities
--- Method
--- Creates the default Tack events and entities
---
--- Parameters:
---  * Tack - the Tack object
---
--- Returns:
---   * A table containing events for `url`, `select`, `entity`, and `normal` modes
---   * A table containing all default desktop entity objects
function Defaults.create(Tack)
    local urlEvents, urlEntities = Defaults.createUrlEvents(Tack.URL)
    local entityEvents, entitySelectEvents = Defaults.createEntityEvents()
    local fileEvents = Defaults.createFileEvents()
    local normalEvents = Defaults.createNormalEvents(Tack)
    local events = {
        url = urlEvents,
        select = entitySelectEvents,
        entity = entityEvents,
        file = fileEvents,
        normal = normalEvents,
    }

    return events, entities, urlEntities
end

return Defaults
