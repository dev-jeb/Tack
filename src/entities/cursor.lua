local Application = dofile(_G.spoonPath.."/application.lua")

local actions = {
    newWindow = Application.createMenuItemEvent("New Window", { focusBefore = true }),
    newTab = Application.createMenuItemEvent("New Tab", { focusBefore = true }),
    closeTab = Application.createMenuItemEvent("Close Editor", { focusBefore = true }),
    closeWindow = Application.createMenuItemEvent("Close Window", { focusBefore = true }),
    toggleTerminal = Application.createMenuItemEvent("Terminal", {
        focusBefore = true,
        isRegex = false,
    }),
    nextTab = Application.createMenuItemEvent("Next Editor", { focusBefore = true }),
    previousTab = Application.createMenuItemEvent("Previous Editor", { focusBefore = true }),
}

local shortcuts = {
    { nil, "n", actions.newWindow, { "Cursor", "New Window" } },
    { nil, "t", actions.newTab, { "Cursor", "New Tab" } },
    { nil, "w", actions.closeTab, { "Cursor", "Close Editor" } },
    { { "shift" }, "w", actions.closeWindow, { "Cursor", "Close Window" } },
    { nil, "`", actions.toggleTerminal, { "Cursor", "Toggle Terminal" } },
    { nil, "l", actions.nextTab, { "Cursor", "Next Editor" } },
    { nil, "h", actions.previousTab, { "Cursor", "Previous Editor" } },
}

return Application:new("Cursor", shortcuts), shortcuts, actions
