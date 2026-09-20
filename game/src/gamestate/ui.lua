local deps = require("gamestate.deps")
local project = require("project")
local viewport = require("src.viewport")
local Navigation = require("ui.navigation")
local Skin = require("ui.skin")
local defaultTheme = require("lib.suit.theme")
local theme = setmetatable({}, {__index = defaultTheme})
function theme.Button(text, opt, x, y, w, h)
    Skin.panel(x, y, w, h, (opt.navFocused or opt.state ~= "normal") and 0.6 or 0)
    defaultTheme.Label(text, opt, x, y, w, h)
    if opt.navFocused then
      love.graphics.setColor(0.5, 1, 0.65)
      love.graphics.rectangle("line", x+4, y+4, w-8, h-8)
    end
end
local HealthBar = require("src.health_bar")

local ui = {
    width = project.width,
    height = project.height,
    buttonWidth = 240,
    buttonHeight = 44,
}
local fonts
local healBarWidget

function ui.new(customTheme)
    if not fonts then
        fonts = {
            title = Skin.font(48),
            body = Skin.font(24),
        }
    end
    if not healBarWidget then
      healBarWidget = HealthBar.new({ width = 200, height = 16, offsetY = 0 })
    end
    -- Each visit starts with a fresh SUIT instance and an empty draw queue.
    local instance = deps.suit.new(customTheme or theme)
    Navigation.attach(instance)
    return instance
end

function ui.begin(instance)
    local x, y, inside = viewport.toGame(love.mouse.getPosition())
    if not inside then x, y = -math.huge, -math.huge end
    Navigation.begin(instance, x, y)
    instance:updateMouse(x, y, love.mouse.isDown(1))
    love.graphics.setFont(fonts.body)
end

function ui.buttonRect(row)
    return (ui.width - ui.buttonWidth) / 2,
        ui.height * 0.5 + (row - 1) * (ui.buttonHeight + 12),
        ui.buttonWidth, ui.buttonHeight
end

function ui.background()
    -- A rectangle preserves the starter's letterbox bars and scissor.
    love.graphics.setColor(0.055, 0.075, 0.085)
    love.graphics.rectangle("fill", 0, 0, ui.width, ui.height)
end

function ui.heading(title, subtitle)
    love.graphics.setColor(0.93, 0.95, 0.96)
    love.graphics.setFont(fonts.title)
    love.graphics.printf(title, 24, ui.height * 0.25, ui.width - 48, "center")
    love.graphics.setFont(fonts.body)
    love.graphics.setColor(0.64, 0.70, 0.73)
    love.graphics.printf(subtitle or "", 24, ui.height * 0.38,
        ui.width - 48, "center")
end

function ui.footer(text)
    love.graphics.setFont(fonts.body)
    love.graphics.setColor(0.64, 0.70, 0.73)
    love.graphics.printf(text, 24, ui.height - 48, ui.width - 48, "center")
end

--@param healResource HealResource
function ui.healBar(healResource)
  love.graphics.push("all")
  love.graphics.translate(16, ui.height - 16)
  love.graphics.scale(0.75, 0.75)
  local x, y = 0, -68
  Skin.panel(x, y, 232, 68)
  love.graphics.setFont(fonts.body)
  love.graphics.setColor(0.93, 0.95, 0.96)
  love.graphics.print("Heal charge", x + 16, y + 12)
  healBarWidget:draw(x + 116, y + 36, healResource:getRatio())
  love.graphics.pop()
end

function ui.draw(instance)
    love.graphics.setFont(fonts.body)
    love.graphics.setColor(1, 1, 1)
    instance:draw()
end

ui.gamepadpressed = Navigation.pressed
ui.gamepadaxis = Navigation.axis

function ui.navigationFooter(back)
    love.graphics.setFont(fonts.body)
    love.graphics.setColor(0.75, 0.8, 0.82)
    love.graphics.print("D-pad / Left stick: move", 190, ui.height-44)
    local function badge(letter, label, x, color)
        love.graphics.setColor(color)
        love.graphics.circle("fill", x, ui.height-32, 12)
        love.graphics.setColor(0.05, 0.07, 0.08)
        love.graphics.printf(letter, x-12, ui.height-44, 24, "center")
        love.graphics.setColor(0.85, 0.9, 0.9)
        love.graphics.print(label, x+20, ui.height-44)
    end
    badge("A", "Select", 534, {0.45, 0.9, 0.55})
    if back then badge("B", back, 674, {1, 0.5, 0.45}) end
end

return ui
