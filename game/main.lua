local project = require("project")
local viewport = require("src.viewport")
local game = require("src.game")

function love.load()
    viewport.init(project.width, project.height)
    viewport.resize(love.graphics.getDimensions())
    game.load()
    print("[jam] ready")
end

function love.update(dt)
    game.update(dt)
end

function love.draw()
    love.graphics.clear(0.035, 0.047, 0.063)
    viewport.beginDraw()
    game.draw()
    viewport.endDraw()
end

function love.resize(width, height)
    viewport.resize(width, height)
end

function love.keypressed(key, scancode, isrepeat)
    game.keypressed(key, scancode, isrepeat)
end

function love.mousepressed(x, y, button, istouch, presses)
    local gameX, gameY, inside = viewport.toGame(x, y)
    if inside then
        game.mousepressed(gameX, gameY, button, istouch, presses)
    end
end

function love.focus(focused)
    game.focus(focused)
end
