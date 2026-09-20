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

function pause:update(dt)
    UI.begin(self.ui)
    if self.ui:Button("Resume", UI.buttonRect(1)).hit then
        return Gamestate.pop()
    end
    if self.ui:Button("Main menu", UI.buttonRect(2)).hit then
        return self:toMenu()
    end
end

function pause:draw()
    -- Only redraw the world: no gameplay updates or underlying SUIT controls.
    love.graphics.push("all")
    self.game:drawWorld()
    love.graphics.pop()
    love.graphics.setColor(0, 0, 0, 0.82)
    love.graphics.rectangle("fill", 0, 0, UI.width, UI.height)
    UI.heading("Paused")
    UI.draw(self.ui)
    UI.footer("Enter / Esc: resume     M: main menu")
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

return pause
