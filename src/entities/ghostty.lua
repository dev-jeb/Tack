local Application = dofile(_G.spoonPath.."/application.lua")

local actions = {
    newWindow = Application.createMenuItemEvent("New Window", { focusBefore = true }),
    newTab = Application.createMenuItemEvent("New Tab", { focusBefore = true }),
    close = Application.createMenuItemEvent({ "Close Tab", "Close Window" }, {
        isToggleable = true,
        focusBefore = true,
    }),
}

local shortcuts = {
    { nil, "n", actions.newWindow, { "Ghostty", "New Window" } },
    { nil, "t", actions.newTab, { "Ghostty", "New Tab" } },
    { nil, "w", actions.close, { "Ghostty", "Close Tab or Window" } },
}

return Application:new("Ghostty", shortcuts), shortcuts, actions
