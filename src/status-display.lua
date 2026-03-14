--- === StatusDisplay ===
---
--- Floating pill-style mode indicator
---

local StatusDisplay = {}
StatusDisplay.__index = StatusDisplay
StatusDisplay.__name = "status-display"

StatusDisplay.PILL_HEIGHT = 28
StatusDisplay.PILL_PADDING_H = 24
StatusDisplay.PILL_CORNER_RADIUS = 14
StatusDisplay.DEFAULT_FADE_TIMEOUT = 0.8

StatusDisplay.displays = {}

local MODE_COLORS = {
    desktop    = { bg = { red = 0.2,  green = 0.2,  blue = 0.2,  alpha = 0.7 },
                   fg = { red = 0.6,  green = 0.6,  blue = 0.6,  alpha = 1.0 } },
    normal     = { bg = { red = 0.15, green = 0.15, blue = 0.2,  alpha = 0.85 },
                   fg = { red = 0.6,  green = 0.7,  blue = 1.0,  alpha = 1.0 } },
    entity     = { bg = { red = 0.1,  green = 0.18, blue = 0.12, alpha = 0.85 },
                   fg = { red = 0.4,  green = 0.9,  blue = 0.5,  alpha = 1.0 } },
    action     = { bg = { red = 0.22, green = 0.15, blue = 0.05, alpha = 0.85 },
                   fg = { red = 1.0,  green = 0.75, blue = 0.3,  alpha = 1.0 } },
    select     = { bg = { red = 0.18, green = 0.1,  blue = 0.2,  alpha = 0.85 },
                   fg = { red = 0.8,  green = 0.5,  blue = 1.0,  alpha = 1.0 } },
    file       = { bg = { red = 0.15, green = 0.15, blue = 0.2,  alpha = 0.85 },
                   fg = { red = 0.5,  green = 0.7,  blue = 0.9,  alpha = 1.0 } },
    url        = { bg = { red = 0.1,  green = 0.15, blue = 0.2,  alpha = 0.85 },
                   fg = { red = 0.3,  green = 0.75, blue = 0.95, alpha = 1.0 } },
    volume     = { bg = { red = 0.15, green = 0.15, blue = 0.2,  alpha = 0.85 },
                   fg = { red = 0.6,  green = 0.7,  blue = 1.0,  alpha = 1.0 } },
    brightness = { bg = { red = 0.15, green = 0.15, blue = 0.2,  alpha = 0.85 },
                   fg = { red = 0.6,  green = 0.7,  blue = 1.0,  alpha = 1.0 } },
}

local DEFAULT_COLORS = MODE_COLORS.normal

--- StatusDisplay:show(status[, parenthetical])
--- Method
--- Shows a floating pill indicator near the top of the screen
---
--- Parameters:
---  * `status` - a string value containing the current mode
---  * `parenthetical` - an optional string value of some parenthetical in the text display
---
--- Returns:
---  * None
function StatusDisplay:show(status, parenthetical)
    -- Clear any pre-existing status display canvases
    for state, display in pairs(self.displays) do
        if display ~= nil then
            display:delete()
            self.displays[state] = nil
        end
    end

    local colors = MODE_COLORS[status] or DEFAULT_COLORS
    local statusText = status:upper()
    local text = parenthetical and statusText .. "  " .. parenthetical or statusText

    local styledText = hs.styledtext.new(text, {
        font = { name = "Menlo", size = 12 },
        color = colors.fg,
        paragraphStyle = { alignment = "center" },
    })

    -- Estimate width: ~8px per character + padding
    local pillWidth = self.PILL_PADDING_H * 2 + #text * 8
    if pillWidth < 120 then pillWidth = 120 end

    local fullFrame = hs.screen.mainScreen():fullFrame()
    local usableFrame = hs.screen.mainScreen():frame()
    local menuBarHeight = usableFrame.y - fullFrame.y
    local pillY = fullFrame.y + math.max((menuBarHeight - self.PILL_HEIGHT) / 2, 0)
    local dimensions = {
        x = fullFrame.x + (fullFrame.w / 2) - (pillWidth / 2),
        y = pillY,
        h = self.PILL_HEIGHT,
        w = pillWidth,
    }

    local display = hs.canvas.new(dimensions)

    -- Background pill shape
    display:appendElements({
        type = "rectangle",
        action = "fill",
        roundedRectRadii = {
            xRadius = self.PILL_CORNER_RADIUS,
            yRadius = self.PILL_CORNER_RADIUS,
        },
        fillColor = colors.bg,
        frame = { x = 0, y = 0, w = pillWidth, h = self.PILL_HEIGHT },
    })

    -- Subtle border
    display:appendElements({
        type = "rectangle",
        action = "stroke",
        roundedRectRadii = {
            xRadius = self.PILL_CORNER_RADIUS,
            yRadius = self.PILL_CORNER_RADIUS,
        },
        strokeColor = { red = 1, green = 1, blue = 1, alpha = 0.08 },
        strokeWidth = 0.5,
        frame = { x = 0, y = 0, w = pillWidth, h = self.PILL_HEIGHT },
    })

    -- Mode text
    display:appendElements({
        type = "text",
        frame = { x = 0, y = 4, w = pillWidth, h = self.PILL_HEIGHT - 4 },
        text = styledText,
    })

    display:level(hs.drawing.windowLevels.modalPanel)
    display:show()

    self.displays[status] = display

    if status == "desktop" then
        display:delete(self.DEFAULT_FADE_TIMEOUT)
        self.displays[status] = nil
    end
end

return StatusDisplay
