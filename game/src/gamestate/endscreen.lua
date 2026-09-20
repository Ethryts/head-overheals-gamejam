local Gamestate = require("gamestate.deps").Gamestate
local UI = require("gamestate.ui")
local endscreen = {}

---@param previous GameState
---@param result? GameResult
function endscreen:enter(previous, result)
    self.ui = UI.new()
    self.result = result or {}
end

function endscreen:update(dt)
    UI.begin(self.ui)
    if self.ui:Button("Play again", UI.buttonRect(1)).hit then
        return Gamestate.switch(require("gamestate.game"))
    end
    if self.ui:Button("Main menu", UI.buttonRect(2)).hit then
        return Gamestate.switch(require("gamestate.menu"))
    end
end

function endscreen:draw()
  self:drawScene()
  self:drawUI()
end

function endscreen:drawScene()
    UI.background()
end

function endscreen:drawUI()
    UI.heading(self.result.title or "Run complete", self.result.message)
    UI.draw(self.ui)
    UI.navigationFooter("Main menu")
end

function endscreen:keypressed(key, scancode, isrepeat)
    if isrepeat then return end
    if key == "return" or key == "kpenter" then
        return Gamestate.switch(require("gamestate.game"))
    elseif key == "escape" then
        return Gamestate.switch(require("gamestate.menu"))
    end
end


function endscreen:gamepadpressed(joystick, button)
    if button == "b" then return Gamestate.switch(require("gamestate.menu")) end
    if button == "start" then button = "a" end
    UI.gamepadpressed(self.ui, button)
end

function endscreen:gamepadaxis(joystick, axis, value)
    UI.gamepadaxis(self.ui, axis, value)
end

return endscreen
