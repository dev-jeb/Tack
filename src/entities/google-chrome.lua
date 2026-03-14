local Application = dofile(_G.spoonPath.."/application.lua")

function Application.getSelectionItems()
    local choices = {}
    local script = Application.renderScriptTemplate("application-tab-titles", { application = "Google Chrome" })
    local isOk, tabList, rawTable = hs.osascript.applescript(script)

    if not isOk then
        Application.notifyError("Error fetching browser tab information", rawTable.NSLocalizedFailureReason)
        return {}
    end

    local windowIndex = 0

    for windowId, titleList in pairs(tabList) do
        windowIndex = windowIndex + 1
        for tabIndex, tabTitle in pairs(titleList) do
            local lastOpenParenIndex = tabTitle:match("^.*()%(")
            local title = tabTitle:sub(1, lastOpenParenIndex - 1)
            local url = tabTitle:sub(lastOpenParenIndex - #tabTitle - 1):match("%((.-)%)") or ""

            table.insert(choices, {
                text = title,
                subText = "Window "..windowIndex.." Tab #"..tabIndex.." - "..url,
                tabIndex = tabIndex,
                windowIndex = windowIndex,
                windowId = windowId,
            })
        end
    end

    return choices
end

local actions = {}

function actions.focus(app, choice)
    if choice then
        local viewModel = { target = "window id "..choice.windowId.." to "..choice.tabIndex }
        local script = Application.renderScriptTemplate("focus-chrome-tab", viewModel)
        local isOk, _, rawTable = hs.osascript.applescript(script)

        if not isOk then
            Application.notifyError("Error activating Google Chrome tab", rawTable.NSLocalizedFailureReason)
        end
    end

    Application.focus(app)
end

local shortcuts = {
    { nil, nil, actions.focus, { "Google Chrome", "Activate/Focus" } },
}

return Application:new("Google Chrome", shortcuts), shortcuts, actions
