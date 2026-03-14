--- === Tack ===
---
--- **Expressive modal macOS automation, inspired by vi**
---
--- Tack uses some particular terminology in its API and documentation:
--- * **event** - a step in a desktop workflow, consisting of the event handler and assigned shortcut keybinding. The table structure matches the argument list for hotkey bindings in Hammerspoon: modifier keys, key name, and event handler. For example, the following events open applications on keydown events on `s` and `⇧⌘s`:
--- ```lua
--- local openSafari = function() hs.application.launchOrFocus("Safari") end
--- local openSpotify = function() hs.application.launchOrFocus("Spotify") end
--- local shortcuts = {
---     { nil, "s", openSafari, { "Safari", "Activate/Focus" } },
---     { { "cmd", "shift" }, "s", openSpotify, { "Spotify", "Activate/Focus" } },
--- }
--- ```
--- An [`Entity`](#Entity) instance can be also used as an event handler:
--- ```lua
--- local shortcuts = {
---     { nil, "s", Tack.createApplication("Safari"), { "Safari", "Activate/Focus" } },
---     { { "cmd", "shift" }, "e", Tack.createApplication("Spotify"), { "Spotify", "Activate/Focus" } },
--- }
--- ```
--- The boolean return value of the event handler or an entity's `dispatchAction` function indicates whether to automatically exit back to `desktop` mode after the action has completed.
---
--- * **state event** - a unidirectional link between two states in the [finite state machine](https://github.com/unindented/lua-fsm#usage) (structured differently from workflow/transition events). The state events below allow the user to transition from `desktop` mode to `normal` mode to `entity` mode and back to `desktop` mode:
---  ```
---  local stateEvents = {
---      { name = "enterNormalMode", from = "desktop", to = "normal" },
---      { name = "enterEntityMode", from = "normal", to = "entity" },
---      { name = "exitMode", from = "entity", to = "desktop" },
---  }
---  ```
---
--- * **transition event** - an event that represents a mode transition. Its event handler invokes some state change through the finite state machine. Assuming state events have been initialized correctly, the following transition events invoke methods on `Tack.state` to allow the user to enter `entity` and `action` mode:
---  ```
---  { {"cmd"}, "e", function() Tack.state:enterEntityMode() end },
---  { {"cmd"}, "a", function() Tack.state:enterActionMode() end },
---  ```
---
--- * **workflow** - a series of transition and workflow events that execute some desktop task, cycling from `desktop` mode back to `desktop` mode
---
--- * **workflow event** - an event that carries out the automative aspect in a workflow; basically an event that's not a transition or state event

local Tack = {}
Tack.__index = Tack

Tack.name = "Tack"
Tack.version = "1.6.4"
Tack.author = "Andrew Kwon"
Tack.homepage = "https://github.com/andweeb/ki"
Tack.license = "MIT - https://opensource.org/licenses/MIT"

local luaVersion = _VERSION:match("%d+%.%d+")

if not _G.getSpoonPath then
    function _G.getSpoonPath()
        return debug.getinfo(2, "S").source:sub(2):match("(.*/)"):sub(1, -2)
    end
end

_G.spoonPath = _G.getSpoonPath()
package.cpath = _G.spoonPath.."/deps/lib/lua/"..luaVersion.."/?.so;"..package.cpath
package.path = _G.spoonPath.."/deps/share/lua/"..luaVersion.."/?.lua;deps/share/lua/"..luaVersion.."/?/init.lua;"..package.path

-- luacov: disable
if not _G.requirePackage then
    function _G.requirePackage(name, isInternal)
        local location = not isInternal and "/deps/share/lua/"..luaVersion.."/" or "/"
        local packagePath = _G.spoonPath..location..name..".lua"

        return dofile(packagePath)
    end
end
-- luacov: enable

_G.SHORTCUT_MODKEY_INDEX = 1
_G.SHORTCUT_HOTKEY_INDEX = 2
_G.SHORTCUT_EVENT_HANDLER_INDEX = 3
_G.SHORTCUT_METADATA_INDEX = 4

local fsm = _G.requirePackage("fsm")
local util = _G.requirePackage("util", true)

-- Allow Spotlight to be used to find alternate names for applications
hs.application.enableSpotlightForNameSearches(true)

--- Tack.Entity
--- Variable
--- A [middleclass](https://github.com/kikito/middleclass/wiki) class that represents some generic automatable desktop entity. Class methods and properties are documented [here](Entity.html).
Tack.Entity = _G.requirePackage("entity", true)

--- Tack.Application
--- Variable
--- A [middleclass](https://github.com/kikito/middleclass/wiki) class that subclasses [Entity](Entity.html) to represent some automatable desktop application. Class methods and properties are documented [here](Application.html).
Tack.Application = _G.requirePackage("application", true)

--- Tack.File
--- Variable
--- A [middleclass](https://github.com/kikito/middleclass/wiki) class that represents some file or directory at an existing file path. Class methods and properties are documented [here](File.html).
Tack.File = _G.requirePackage("file", true)

--- Tack.URL
--- Variable
--- A [middleclass](https://github.com/kikito/middleclass/wiki) class that represents some url. Class methods and properties are documented [here](URL.html).
Tack.URL = _G.requirePackage("url", true)

local Defaults = _G.requirePackage("defaults", true)
local defaultWorkflowEvents, defaultEntities, defaultUrlEntities = Defaults.create(Tack)

--- Tack.defaultWorkflowEvents
--- Variable
--- A table containing the default workflow events for all default modes in Tack.
Tack.defaultWorkflowEvents = defaultWorkflowEvents

--- Tack.defaultEntities
--- Variable
--- A table containing the default automatable desktop entity instances in Tack.
Tack.defaultEntities = defaultEntities

--- Tack.defaultUrlEntities
--- Variable
--- A table containing the default automatable URL entity instances in Tack.
Tack.defaultUrlEntities = defaultUrlEntities

--- Tack.state
--- Variable
--- The internal [finite state machine](https://github.com/unindented/lua-fsm#usage) used to manage modes in Tack.
Tack.state = {}

-- Create a metatable defined with state events operations
function Tack._createStatesMetatable()
    return {
        __add = function(lhs, rhs)
            for _, event in pairs(rhs) do
                table.insert(lhs, event)
            end

            return lhs
        end,
    }
end

-- Merge Tack events with the option of overriding events
-- Events with conflicting hotkeys will result in the lhs event being overwritten by the rhs event
function Tack._mergeEvents(mode, lhs, rhs, overrideLHS)
    -- LHS event modifiers keyed by event keyname
    local lhsHotkeys = {}

    -- Map lhs keynames to modifier keys
    for index, lhsEvent in pairs(lhs) do
        local modifiers = lhsEvent[_G.SHORTCUT_MODKEY_INDEX] or {}
        local keyName = lhsEvent[_G.SHORTCUT_HOTKEY_INDEX]

        lhsHotkeys[keyName] = {
            index = index,
            modifiers = modifiers,
        }
    end

    -- Merge events from rhs to lhs
    for _, rhsEvent in pairs(rhs) do
        -- Determine if event exists in lhs events
        local rhsEventModifiers = rhsEvent[_G.SHORTCUT_MODKEY_INDEX] or {}
        local eventKeyName = rhsEvent[_G.SHORTCUT_HOTKEY_INDEX]
        local eventModifiers = lhsHotkeys[eventKeyName] and lhsHotkeys[eventKeyName].modifiers or nil
        local hasHotkeyConflict = util.areListsEqual(eventModifiers, rhsEventModifiers)

        if not hasHotkeyConflict then
            table.insert(lhs, rhsEvent)
        else
            if overrideLHS then
                -- Overwrite LHS shortcut or concat the RHS shortcut
                local lhsIndex = lhsHotkeys[eventKeyName]
                    and lhsHotkeys[eventKeyName].index
                    or nil

                if lhsIndex ~= nil then
                    lhs[lhsIndex] = rhsEvent
                else
                    table.insert(lhs, rhsEvent)
                end
            else
                -- Generate hotkey binding text to display in console warning
                local modifierName = ""

                for index, modifiers in pairs(rhsEventModifiers) do
                    modifierName = (index == 1 and modifierName or modifierName.."+")..modifiers
                end

                local binding = "{"..(#rhsEventModifiers == 0 and "" or modifierName.."+")..eventKeyName.."}"

                hs.showError("Cannot overwrite hotkey binding "..binding.." in "..mode.." mode reserved for transition events")
            end
        end
    end
end

-- Create a metatable defined with transition or workflow events operations. An optional `overrideLHS` can be provided to enable overriding LHS events or show an error on conflicting hotkeys.
function Tack:_createEventsMetatable(overrideLHS)
    return {
        __add = function(lhs, rhs)
            for mode, events in pairs(rhs) do
                if not lhs[mode] then
                    lhs[mode] = {}
                end

                self._mergeEvents(mode, lhs[mode], events, overrideLHS)
            end

            return lhs
        end,
    }
end

-- Allow default events to be overridden
setmetatable(Tack.defaultWorkflowEvents, Tack:_createEventsMetatable(true))

--- Tack.transitionEvents
--- Variable
--- A table containing the definitions of transition events.
---
--- The default mode transition events are defined:
---  * from `desktop` mode, <kbd>⌘⎋</kbd> to enter `normal` mode
---  * from `normal` mode, <kbd>⌘e</kbd> to enter `entity` mode
---  * from `normal` mode, <kbd>⌘a</kbd> to enter `action` mode
---  * from `normal` mode, <kbd>⌘s</kbd> to enter `select` mode
---  * from `normal` mode, <kbd>⌘u</kbd> to enter `url` mode
---  * <kbd>⎋</kbd> to exit back to `desktop` mode from any of the modes above
---
--- The example transition events in the snippet below allow the following transition events:
---  * from `desktop` mode, enter `normal` mode with <kbd>⌘⎋</kbd>
---  * from `normal` mode, enter `desktop` mode with <kbd>⎋</kbd>
---
---  ```
---  -- Initialize state events to expose `enterNormalMode` and `exitMode` methods on `Tack.state`
---  Tack.stateEvents = {
---      { name = "enterNormalMode", from = "desktop", to = "normal" },
---      { name = "exitMode", from = "normal", to = "desktop" },
---  }
---
---  local enterNormalMode = function() Tack.state:enterNormalMode() end
---  local exitMode = function() Tack.state:exitMode() end
---
---  Tack.transitionEvents = {
---      desktop = {
---          { {"cmd"}, "escape", enterNormalMode, { "Desktop Mode", "Transition to Normal Mode" } },
---      },
---      normal = {
---          { nil, "escape", exitMode, { "Normal Mode", "Exit to Desktop Mode" } },
---      },
---  }
---  ```
---
--- **Note**: `action` mode is unique in that its events are generated at runtime and automatically dispatched to the intended `entity` handler. That's why there are no explicit transition events to `entity` mode defined in this default transitions table.
Tack.transitionEvents = {}

--- Tack.defaultTransitionEvents
--- Variable
--- A table containing the default transition events for all default modes in Tack.
Tack.defaultTransitionEvents = {
    desktop = {
        {
            {"cmd"}, "escape",
            function() Tack.state:enterNormalMode() end,
            { "Desktop Mode", "Transition to Normal Mode" },
        },
    },
    normal = {
        {
            nil, "escape",
            function() Tack.state:exitMode() end,
            { "Normal Mode", "Exit to Desktop Mode" },
        },
        {
            {"cmd"}, "e",
            function() Tack.state:enterEntityMode() end,
            { "Normal Mode", "Transition to Entity Mode" },
        },
        {
            {"cmd"}, "f",
            function() Tack.state:enterFileMode() end,
            { "Normal Mode", "Transition to File Mode" },
        },
        {
            {"cmd"}, "a",
            function() Tack.state:enterActionMode() end,
            { "Normal Mode", "Transition to Action Mode" },
        },
        {
            {"cmd"}, "u",
            function() Tack.state:enterUrlMode() end,
            { "Normal Mode", "Transition to URL Mode" },
        },
        {
            {"cmd"}, "s",
            function() Tack.state:enterSelectMode() end,
            { "Normal Mode", "Transition to Select Mode" },
        },
    },
    entity = {
        {
            nil, "escape",
            function() Tack.state:exitMode() end,
            { "Entity Mode", "Exit to Normal Mode" },
        },
        {
            {"cmd"}, "u",
            function() Tack.state:enterUrlMode() end,
            { "Entity Mode", "Transition to URL Mode" },
        },
        {
            {"cmd"}, "f",
            function() Tack.state:enterFileMode() end,
            { "Entity Mode", "Transition to File Mode" },
        },
        {
            {"cmd"}, "s",
            function() Tack.state:enterSelectMode() end,
            { "Entity Mode", "Transition to Select Mode" },
        },
    },
    file = {
        {
            nil, "escape",
            function() Tack.state:exitMode() end,
            { "File Mode", "Exit to Desktop Mode" },
        },
    },
    action = {
        {
            nil, "escape",
            function() Tack.state:exitMode() end,
            { "Action Mode", "Exit to Normal Mode" },
        },
    },
    select = {
        {
            nil, "escape",
            function() Tack.state:exitMode() end,
            { "Select Mode", "Exit to Normal Mode" },
        },
        {
            {"cmd"}, "e",
            function() Tack.state:enterEntityMode() end,
            { "Select Mode", "Transition to Entity Mode" },
        },
        {
            {"cmd"}, "f",
            function() Tack.state:enterFileMode() end,
            { "Select Mode", "Transition to File Mode" },
        },
        {
            {"cmd"}, "u",
            function() Tack.state:enterUrlMode() end,
            { "Select Mode", "Transition to URL Mode" },
        },
    },
    url = {
        {
            nil, "escape",
            function() Tack.state:exitMode() end,
            { "URL Mode", "Exit to Normal Mode" },
        },
    },
}
setmetatable(Tack.defaultTransitionEvents, Tack:_createEventsMetatable())

--- Tack.stateEvents
--- Variable
--- A table containing the [state events](https://github.com/unindented/lua-fsm#usage) for the finite state machine set to `Tack.state`. Custom state events can be set to `Tack.stateEvents` before calling `Tack.start()` to set up the FSM with custom transition events.
---
--- The example state events below create methods on `Tack.state` to enter and exit entity mode from normal mode:
--- * `{ name = "enterEntityMode", from = "normal", to = "entity" }`
--- * `{ name = "exitMode", from = "entity", to = "normal" }`
---
--- **Note**: these events will only _initialize and expose_ methods on `Tack.state`. For example, the `Tack.state:enterEntityMode` and `Tack.state:exitMode` methods will only be _initialized_ with the example state events above. These methods will need to be called in transition events ([`Tack.transitionEvents`](#transitionEvents)) in order to actually trigger the transition from mode to mode.
Tack.stateEvents = {}
Tack._defaultStateEvents = {
    { name = "enterNormalMode", from = "desktop", to = "normal" },
    { name = "enterEntityMode", from = "normal", to = "entity" },
    { name = "enterEntityMode", from = "action", to = "entity" },
    { name = "enterEntityMode", from = "select", to = "entity" },
    { name = "enterActionMode", from = "normal", to = "action" },
    { name = "enterSelectMode", from = "entity", to = "select" },
    { name = "enterSelectMode", from = "normal", to = "select" },
    { name = "enterFileMode", from = "normal", to = "file" },
    { name = "enterFileMode", from = "entity", to = "file" },
    { name = "enterFileMode", from = "select", to = "file" },
    { name = "enterSelectMode", from = "file", to = "select" },
    { name = "enterUrlMode", from = "normal", to = "url" },
    { name = "enterUrlMode", from = "select", to = "url" },
    { name = "enterUrlMode", from = "entity", to = "url" },
    { name = "exitMode", from = "normal", to = "desktop" },
    { name = "exitMode", from = "entity", to = "desktop" },
    { name = "exitMode", from = "file", to = "desktop" },
    { name = "exitMode", from = "url", to = "desktop" },
    { name = "exitMode", from = "select", to = "desktop" },
    { name = "exitMode", from = "action", to = "desktop" },
}
setmetatable(Tack._defaultStateEvents, Tack._createStatesMetatable())

--- Tack.workflowEvents
--- Variable
--- A table containing lists of custom workflow events keyed by mode name. The following example creates two entity and url events:
--- ```lua
--- local function handleUrlEvent(url)
---     hs.urlevent.openURL(url)
---     spoon.Tack.state:exitMode()
--- end
--- local function launchOrFocusApplicationEvent(appName)
---     hs.application.launchOrFocus(appName)
---     spoon.Tack.state:exitMode()
--- end
---
--- spoon.Tack.workflowEvents = {
---     url = {
---         { nil, "g", function() handleUrlEvent("https://google.com") end },
---         { nil, "r", function() handleUrlEvent("https://reddit.com") end },
---     },
---     entity = {
---         { nil, "s", function() launchOrFocusApplicationEvent("Safari") end) },
---         { {"shift"}, "s", function() launchOrFocusApplicationEvent("Spotify") end) },
---     },
--- }
--- ```
Tack.workflowEvents = {}

--- Tack.statusDisplay
--- Variable
--- A table that defines the behavior for displaying the status of mode transitions. The `show` function should clear out any previous display and show the current transitioned mode. The following methods should be available on the object:
---  * `show` - A function invoked when a mode transition event occurs, with the following arguments:
---    * `status` - A string value containing the current mode
---    * `parenthetical` - Optional parenthesized text in the display
---
--- Defaults to a simple text display in the center of the menu bar of the focused screen.
Tack.statusDisplay = nil

-- A table that stores the workflow history.
Tack.history = {
    workflow = {},
    action = {},
}

function Tack.history:recordEvent(mode, keyName, flags)
    table.insert(self.workflow, {
        mode = mode,
        flags = flags,
        keyName = keyName,
    })
end

function Tack._renderHotkeyText(modifiers, keyName)
    local modKeyText = ""
    local modNames = {
        cmd = "⌘",
        alt = "⌥",
        shift = "⇧",
        ctrl = "⌃",
        fn = "<fn>",
    }

    for name, isKeyDown in pairs(modifiers) do
        if name and modNames[name] and isKeyDown then
            modKeyText = modKeyText..modNames[name]
        end
    end

    return modKeyText..keyName
end

-- Generate the finite state machine callbacks for all state events, generic `onstatechange` callbacks for recording/resetting event history and state event-specific callbacks
function Tack:_createFsmCallbacks()
    local callbacks = {}

    -- Add generic state change callback for all events to record and reset workflow event history
    callbacks.on_enter_state = function(_, eventName, _, nextState, stateMachine, _, _, action)
        if not self.listener or not self.listener:isEnabled() then
            return
        end

        local actionHotkey = action and self._renderHotkeyText(action.flags, action.keyName)
        local parenthetical = eventName == "enterSelectMode" and next(self.history.action) and "with action" or actionHotkey

        -- Show the status display with the current mode and record the event to the workflow history
        self.statusDisplay:show(stateMachine.current, parenthetical)

        if nextState == "desktop" then
            self.history.workflow = {}
            self.history.action = {}
        end
    end

    return callbacks
end

-- Handle keydown event by triggering the appropriate event handler or entity action dispatcher depending on the mode, modifier keys, and keycode
function Tack:_handleKeyDown(event)
    local mode = self.state.current
    local workflowEvents = self.workflowEvents[mode]
    local handler = nil

    local flags = event:getFlags()
    local keyName = hs.keycodes.map[event:getKeyCode()]

    -- Determine event handler
    for _, workflowEvent in pairs(workflowEvents) do
        local eventModifiers = workflowEvent[_G.SHORTCUT_MODKEY_INDEX] or {}
        local eventKeyName = workflowEvent[_G.SHORTCUT_HOTKEY_INDEX]
        local eventTrigger = workflowEvent[_G.SHORTCUT_EVENT_HANDLER_INDEX]

        if flags:containExactly(eventModifiers) and keyName == eventKeyName then
            handler = eventTrigger
        end
    end

    -- Create action handlers at runtime to automatically enter entity mode with the intended event
    if mode == "action" and not handler then
        handler = function(actionFlags, actionKeyName)
            local action = {
                flags = actionFlags,
                keyName = actionKeyName,
            }

            Tack.history.action = action
            Tack.state:enterEntityMode(nil, nil, action)
        end
    end

    -- Avoid propagating existing handler or non-existent handler in a non-normal mode
    if handler then
        Tack.history:recordEvent(mode, keyName, flags)

        if type(handler) == "table" and handler.dispatchAction then
            local shouldAutoExit = handler:dispatchAction(mode, Tack.history.action, Tack.history.workflow)

            if shouldAutoExit then
                self.state:exitMode()
            end
        elseif type(handler) == "function" then
            local shouldAutoExit = handler(flags, keyName)

            if shouldAutoExit then
                self.state:exitMode()
            end
        else
            local hotkeyText = self._renderHotkeyText(flags, keyName)
            local details =
                "The event handler may be misconfigured for the shortcut "..hotkeyText.." in "..mode.." mode."

            self.createEntity().notifyError("Unexpected event handler", details)
        end

        return true
    elseif mode ~= "desktop" then
        hs.sound.getByName("Funk"):volume(1):play()
        return true
    end

    -- Propagate event when there is no handler in desktop mode
end

-- Primary init function to initialize the primary event handler
function Tack:init()
    local eventHandler = function(event)
        return self:_handleKeyDown(event)
    end

    -- Set keydown listener with the primary event handler
    self.listener = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, eventHandler)
end

--- Tack:start() -> hs.eventtap
--- Method
--- Sets the status display, creates all transition and workflow events, and starts the input event listener
---
--- Parameters:
---  * None
---
--- Returns:
---   * An [`hs.eventtap`](https://www.hammerspoon.org/docs/hs.eventtap.html) object
function Tack:start()
    -- Set default status display if not provided
    self.statusDisplay = self.statusDisplay or dofile(_G.spoonPath.."/status-display.lua")

    -- Recreate the internal finite state machine if custom state events are provided
    self.state = fsm.create({
        initial = "desktop",
        events = self._defaultStateEvents + self.stateEvents,
        callbacks = self:_createFsmCallbacks()
    })

    -- Set transition and workflow events
    local workflowEvents = self.defaultWorkflowEvents + self.workflowEvents
    local transitionEvents = self.defaultTransitionEvents + self.transitionEvents
    self.workflowEvents = transitionEvents + workflowEvents

    -- Collect all actions
    local actions = {}
    for _, workflowActions in pairs(self.workflowEvents) do
        for _, workflow in pairs(workflowActions) do
            table.insert(actions, workflow)
        end
    end

    -- Create Tack cheatsheet
    self.cheatsheet = _G.requirePackage("cheatsheet", true)

    local function showCheatsheet()
        self.cheatsheet:show()
        return true
    end

    -- Add show cheatsheet entity event into workflow entity events
    table.insert(self.workflowEvents.entity, {
        { "shift" }, "/", showCheatsheet, { "Entities", "Cheatsheet" },
    })

    -- Initialize cheat sheet with both default and/or custom transition and workflow events
    local description = "Shortcuts for Tack modes, entities, and transition and workflow events"
    self.cheatsheet:init("Tack", description, actions)

    -- Start keydown event listener
    return self.listener:start()
end

--- Tack:stop() -> hs.eventtap
--- Method
--- Stops the input event listener
---
--- Parameters:
---  * None
---
--- Returns:
---   * An [`hs.eventtap`](https://www.hammerspoon.org/docs/hs.eventtap.html) object
function Tack:stop()
    return self.listener:stop()
end

return Tack
