local Gamestate = require("gamestate.deps").Gamestate
local UI = require("gamestate.ui")
local Skin = require("ui.skin")
local page = {}

function page:enter()
  self.ui = UI.new()
end

function page:update(dt)
  UI.begin(self.ui)
  if self.ui:Button("Back", (UI.width-240)/2, 420, 240, 44).hit then
    return Gamestate.pop()
  end
end

function page:draw()
  self:drawScene()
  self:drawUI()
end

function page:drawScene()
  UI.background()
end

function page:drawUI()
  love.graphics.setFont(Skin.font(48))
  love.graphics.setColor(0.97, 0.94, 0.82)
  love.graphics.printf("CREDITS", 0, 66, UI.width, "center")
  Skin.panel(180, 146, 600, 244, nil, "steel")
  love.graphics.setFont(Skin.font(24))
  love.graphics.setColor(0.85, 0.89, 0.9)
  local lines = {
    "HEAD OVER HEALS",
    "Built with LOVE",
    "UI artwork: Cryo's Mini GUI",
    "Monogram font: Vinicius Menezio",
    "Libraries: anim8, HUMP, HC, SUIT, Baton",
    "Thank you for playing.",
  }
  for i, text in ipairs(lines) do
    love.graphics.printf(text, 200, 162+(i-1)*34, 560, "center")
  end
  UI.draw(self.ui)
  UI.navigationFooter("Back")
end

function page:keypressed(key, _, isrepeat)
  if not isrepeat and key == "escape" then return Gamestate.pop() end
end

function page:gamepadpressed(joystick, button)
  if button == "b" then return Gamestate.pop() end
  UI.gamepadpressed(self.ui, button)
end

function page:gamepadaxis(joystick, axis, value)
  UI.gamepadaxis(self.ui, axis, value)
end

return page
