  love.filesystem.setRequirePath(love.filesystem.getRequirePath() .. ";src/?.lua;src/?/init.lua")

local project = require("project")
local viewport = require("src.viewport")
local Gamestate = require("gamestate.deps").Gamestate
local MusicSystem = require("systems.music")
local music
local SoundEffectsSystem = require("systems.sound_effects")
local soundEffects
local debugState = require("gamestate.debug")
local debugHud = require("debug.hud")
local ShaderSystem = require("systems.shader")
local shaders

function love.load()
		music = MusicSystem:new()
		soundEffects = SoundEffectsSystem:new()
    viewport.init(project.width, project.height)
    viewport.resize(love.graphics.getDimensions())
    shaders = ShaderSystem.new(require("shader_config"))
    Gamestate.shaderSystem = shaders
		Gamestate.musicSystem = music
		Gamestate.soundEffectsSystem = soundEffects
    Gamestate.switch(require("gamestate.menu"))
    print("[jam] ready")
end

function love.update(dt)
    Gamestate.update(dt)
end

function love.draw()
    love.graphics.clear(0.035, 0.047, 0.063)
    local state = Gamestate.current()
    shaders:draw(function()
        viewport.beginDraw()
        Gamestate.drawScene()
        viewport.endDraw()
    end, function()
        viewport.beginDraw()
        Gamestate.drawUI()
        debugHud.draw(state)
        viewport.endDraw()
    end, state.isMenu ~= false)
end

function love.quit()
    if shaders then shaders:destroy() end
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

function love.gamepadpressed(joystick, button)
    Gamestate.gamepadpressed(joystick, button)
end

function love.gamepadaxis(joystick, axis, value)
    Gamestate.gamepadaxis(joystick, axis, value)
end
