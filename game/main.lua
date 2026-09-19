love.filesystem.setRequirePath(love.filesystem.getRequirePath() .. ";src/?.lua;src/?/init.lua")

local project = require("project")
local viewport = require("src.viewport")
local Gamestate = require("gamestate.deps").Gamestate

function love.load()
    viewport.init(project.width, project.height)
    viewport.resize(love.graphics.getDimensions())
    Gamestate.switch(require("gamestate.menu"))
    print("[jam] ready")
end

function love.update(dt)
    Gamestate.update(dt)
end

function love.draw()
    love.graphics.clear(0.035, 0.047, 0.063)
    viewport.beginDraw()
    Gamestate.draw()
    viewport.endDraw()
end

function love.resize(width, height)
    viewport.resize(width, height)
end

function love.keypressed(key, scancode, isrepeat)
    Gamestate.keypressed(key, scancode, isrepeat)
end

function love.mousepressed(x, y, button, istouch, presses)
    local gameX, gameY, inside = viewport.toGame(x, y)
    if inside then
        Gamestate.mousepressed(gameX, gameY, button, istouch, presses)
    end
end

function love.focus(focused)
    Gamestate.focus(focused)
end
