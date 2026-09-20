local Gamestate = require("gamestate.deps").Gamestate
local UI = require("gamestate.ui")
---@class PauseState
---@field game GameState Active game while the pause state is entered.
local pause = {}

---@param previous GameState
function pause:enter(previous)
    self.game = previous
    self.ui = UI.new()
end

function pause:toMenu()
    -- Remove the overlay before replacing the game underneath it.
    Gamestate.pop()
    return Gamestate.switch(require("gamestate.menu"))
end

function pause:resume()
    self.ui = UI.new()
end

function pause:update(dt)
    UI.begin(self.ui)
    if self.ui:Button("Resume", UI.buttonRect(1)).hit then
        return Gamestate.pop()
    end
    if self.ui:Button("Main menu", UI.buttonRect(2)).hit then
        return self:toMenu()
    end
    if self.ui:Button("Help / Controls", UI.buttonRect(3)).hit then
        return Gamestate.push(require("gamestate.help"))
    end
end

function pause:draw()
    -- Only redraw the world: no gameplay updates or underlying SUIT controls.
    love.graphics.push("all")
    self.game:drawWorld()
    love.graphics.pop()
    love.graphics.setColor(0, 0, 0, 0.82)
    love.graphics.rectangle("fill", 0, 0, UI.width, UI.height)
    UI.heading("Paused", "Start / Esc: resume")
    UI.draw(self.ui)
    UI.navigationFooter("Resume")
end

function pause:keypressed(key, scancode, isrepeat)
    if isrepeat then return end
    if key == "escape" or key == "return" or key == "kpenter" then
        return Gamestate.pop()
    elseif key == "m" then
        return self:toMenu()
    end
end

function pause:leave()
    self.game = nil
end


function pause:gamepadpressed(joystick, button)
    if button == "b" then return Gamestate.pop() end
    if button == "start" then return Gamestate.pop() end
    UI.gamepadpressed(self.ui, button)
end

function pause:gamepadaxis(joystick, axis, value)
    UI.gamepadaxis(self.ui, axis, value)
end

return pause
