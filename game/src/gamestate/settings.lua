local Gamestate = require("gamestate.deps").Gamestate
local UI = require("gamestate.ui")
local settings = require("ui.menu_settings")
local page = {}

function page:enter()
  self.ui = UI.new()
end

function page:changeVolume(delta)
  settings.volume = math.max(0, math.min(1, settings.volume + delta))
  love.audio.setVolume(settings.volume)
end

function page:update(dt)
  UI.begin(self.ui)
  if self.ui:Button("Volume -", UI.buttonRect(1)).hit then self:changeVolume(-0.1) end
  if self.ui:Button("Volume +", UI.buttonRect(2)).hit then self:changeVolume(0.1) end
  if self.ui:Button("Back", UI.buttonRect(3)).hit then return Gamestate.pop() end
end

function page:draw()
  self:drawScene()
  self:drawUI()
end

function page:drawScene()
  UI.background()
end

function page:drawUI()
  UI.heading("Settings", string.format("Master volume: %.0f%%", settings.volume*100))
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
