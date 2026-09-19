love.filesystem.setRequirePath(love.filesystem.getRequirePath() .. ";src/?.lua;src/?/init.lua")

local project = require("project")
local viewport = require("src.viewport")
local Gamestate = require("gamestate.deps").Gamestate
local MusicSystem = require("systems.music")
local music
local debugState = require("gamestate.debug")
local debugHud = require("debug.hud")

function love.load()
		music = MusicSystem:new()
    viewport.init(project.width, project.height)
    viewport.resize(love.graphics.getDimensions())
		Gamestate.musicHandler = music
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
    debugHud.draw(Gamestate.current())
    viewport.endDraw()
end

function love.resize(width, height)
    viewport.resize(width, height)
end

function love.keypressed(key, scancode, isrepeat)
    if key == "f3" then
        if isrepeat then return end
        if Gamestate.current() == debugState then Gamestate.pop()
        else Gamestate.push(debugState) end
        return
    elseif key == "f4" then
        if not isrepeat then debugHud.toggle() end
        return
    end
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
