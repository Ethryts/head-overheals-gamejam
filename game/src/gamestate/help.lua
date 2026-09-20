local Gamestate = require("gamestate.deps").Gamestate
local UI = require("gamestate.ui")
local Skin = require("ui.skin")
local help = {}
local controls = {
  {"Move", "W A S D", "Left stick / D-pad"},
  {"Aim beam / kick", "Mouse / Arrow keys", "Right stick"},
  {"Heal", "Left click / Space", "RT / RB"},
  {"Kick", "Right click / F", "LT"},
  {"Pause / Resume", "Esc", "Start"},
  {"Menu navigation", "Mouse", "D-pad / Left stick"},
  {"Select / Back", "Click / Esc", "A / B"},
}

function help:enter(previous)
  self.previous = previous
  self.ui = UI.new()
end

function help:update(dt)
  UI.begin(self.ui)
  if self.ui:Button("Back", (UI.width-240)/2, 432, 240, 44).hit then
    return Gamestate.pop()
  end
end

function help:draw()
  UI.background()
  love.graphics.setFont(Skin.font(36))
  love.graphics.setColor(1, 0.85, 0.6)
  love.graphics.printf("HOW TO PLAY", 0, 26, UI.width, "center")
  love.graphics.setFont(Skin.font(24))
  love.graphics.setColor(0.9, 0.93, 0.92)
  love.graphics.printf("Protect the knight from the creatures. Keep them alive with your healing beam.",
    100, 76, UI.width-200, "center")
  Skin.panel(100, 126, UI.width-200, 290)
  local columns = {124, 360, 636}
  love.graphics.setColor(1, 0.8, 0.52)
  for i, label in ipairs({"ACTION", "MOUSE / KEYBOARD", "CONTROLLER"}) do
    love.graphics.print(label, columns[i], 142)
  end
  for i, row in ipairs(controls) do
    love.graphics.setColor(0.83, 0.89, 0.89)
    for col, label in ipairs(row) do
      love.graphics.print(label, columns[col], 178+(i-1)*30)
    end
  end
  UI.draw(self.ui)
  UI.navigationFooter("Back")
end

function help:keypressed(key, _, isrepeat)
  if not isrepeat and (key == "escape" or key == "return") then return Gamestate.pop() end
end

function help:gamepadpressed(joystick, button)
  if button == "b" then return Gamestate.pop() end
  if button == "start" and self.previous == require("gamestate.pause") then
    Gamestate.pop()
    return Gamestate.pop()
  end
  UI.gamepadpressed(self.ui, button)
end

function help:gamepadaxis(joystick, axis, value)
  UI.gamepadaxis(self.ui, axis, value)
end

return help
