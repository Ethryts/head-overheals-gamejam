local deps = require("gamestate.deps")
local project = require("project")
local viewport = require("src.viewport")
local Skin = require("ui.skin")
local defaultTheme = require("lib.suit.theme")
local theme = setmetatable({}, {__index = defaultTheme})
function theme.Button(text, opt, x, y, w, h)
    Skin.panel(x, y, w, h, opt.state ~= "normal" and 0.6 or 0)
    defaultTheme.Label(text, opt, x, y, w, h)
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

function ui.new()
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
    return deps.suit.new(theme)
end

function ui.begin(instance)
    local x, y, inside = viewport.toGame(love.mouse.getPosition())
    if not inside then x, y = -math.huge, -math.huge end
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
  love.graphics.setFont(fonts.body)
  love.graphics.setColor(0.93, 0.95, 0.96)
  love.graphics.print("Heal charge", 24, ui.height - 76)
  healBarWidget:draw(124, ui.height - 60, healResource:getRatio())
end

function ui.draw(instance)
    love.graphics.setFont(fonts.body)
    love.graphics.setColor(1, 1, 1)
    instance:draw()
end

return ui
