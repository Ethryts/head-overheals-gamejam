local Gamestate = require("gamestate.deps").Gamestate
local Scene = require("ui.menu_scene")
local Skin = require("ui.skin")
local theme = {}
function theme.Button(text, opt, x, y, w, h)
  local selected = opt.navFocused or opt.state ~= "normal"
  Skin.panel(x, y, w, h, nil, "steel")
  if selected then
    love.graphics.setColor(0.88, 0.68, 0.33)
    love.graphics.rectangle("line", x + 2, y + 2, w - 4, h - 4)
    love.graphics.polygon("fill", x - 18, y + h / 2 - 6, x - 10, y + h / 2, x - 18, y + h / 2 + 6)
  end
  love.graphics.setColor(selected and 1 or 0.78, selected and 0.95 or 0.82, selected and 0.8 or 0.87)
  love.graphics.setFont(opt.font)
  love.graphics.printf(text, x, y + (h - opt.font:getHeight()) / 2, w, "center")
end

local UI = require("gamestate.ui")
local menu = {}

function menu:enter()
  self.scene = Scene.new()
  Gamestate.musicSystem:receiveHealthUpdate(100)
  self.ui = UI.new(theme)
  self.ui.navigation.active = true
end

function menu:resume()
  self.ui = UI.new(theme)
  self.ui.navigation.active = true
end

function menu:update(dt)
  self.scene:update(dt)
  UI.begin(self.ui)
  local entries = {
    { "Play",    "game",    false }, { "Settings", "settings", true },
    { "Credits", "credits", true }, { "Help / Controls", "help", true },
  }
  for i, entry in ipairs(entries) do
    if self.ui:Button(entry[1], (UI.width - 272) / 2, 224 + (i - 1) * 54, 272, 46).hit then
      local target = require("gamestate." .. entry[2])
      if entry[3] then return Gamestate.push(target) end
      return Gamestate.switch(target)
    end
  end
end

function menu:draw()
  self:drawScene()
  self:drawUI()
end

function menu:drawScene()
  self.scene:draw()
end

function menu:drawUI()
  love.graphics.setFont(Skin.font(72))
  love.graphics.setColor(0.025, 0.03, 0.045)
  for _, offset in ipairs({ { -2, 0 }, { 2, 0 }, { 0, -2 }, { 0, 2 }, { 2, 4 } }) do
    love.graphics.printf("HEAD OVER HEALED", offset[1], 94 + offset[2], UI.width, "center")
  end
  love.graphics.setColor(0.97, 0.94, 0.82)
  love.graphics.printf("HEAD OVER HEALED", 0, 94, UI.width, "center")
  love.graphics.setColor(0.8, 0.6, 0.3)
  love.graphics.rectangle("fill", 380, 162, 200, 2)
  love.graphics.setFont(Skin.font(20))
  love.graphics.setColor(0.65, 0.69, 0.72)
  love.graphics.printf("A MOMENT OF REST", 0, 180, UI.width, "center")
  UI.draw(self.ui)
  UI.navigationFooter()
end

function menu:leave()
  if self.scene then
    self.scene:destroy(); self.scene = nil
  end
end

function menu:keypressed(key, scancode, isrepeat)
  if isrepeat then return end
  if key == "return" or key == "kpenter" then
    return Gamestate.switch(require("gamestate.game"))
  end
end

function menu:gamepadpressed(joystick, button)
  if button == "b" then return end
  if button == "start" then button = "a" end
  UI.gamepadpressed(self.ui, button)
end

function menu:gamepadaxis(joystick, axis, value)
  UI.gamepadaxis(self.ui, axis, value)
end

return menu
