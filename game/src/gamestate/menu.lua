local Gamestate = require("gamestate.deps").Gamestate
local project = require("project")
local UI = require("gamestate.ui")
local menu = {}

function menu:enter()
    self.ui = UI.new()
end

function menu:update(dt)
    UI.begin(self.ui)
    if self.ui:Button("Play", UI.buttonRect(1)).hit then
        return Gamestate.switch(require("gamestate.game"))
    end
end

function menu:draw()
    UI.background()
    UI.heading(project.title, "Ready when you are.")
    UI.draw(self.ui)
    UI.footer("Enter: play")
end

function menu:keypressed(key, scancode, isrepeat)
    if isrepeat then return end
    if key == "return" or key == "kpenter" then
        return Gamestate.switch(require("gamestate.game"))
    end
end

return menu
