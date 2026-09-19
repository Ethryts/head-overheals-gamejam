-- Draw in fixed game coordinates while the window/iframe changes size.
-- No offscreen canvas: shapes and fonts render at the display resolution.
local viewport = {}
local gameWidth, gameHeight = 960, 540
local scale, offsetX, offsetY = 1, 0, 0

function viewport.init(width, height)
    gameWidth, gameHeight = width, height
end

function viewport.resize(width, height)
    scale = math.max(0.001, math.min(width / gameWidth, height / gameHeight))
    offsetX = (width - gameWidth * scale) / 2
    offsetY = (height - gameHeight * scale) / 2
end

function viewport.toGame(x, y)
    local gameX = (x - offsetX) / scale
    local gameY = (y - offsetY) / scale
    local inside = gameX >= 0 and gameY >= 0
        and gameX < gameWidth and gameY < gameHeight
    return gameX, gameY, inside
end

function viewport.beginDraw()
    love.graphics.push("all")
    love.graphics.origin()
    love.graphics.setScissor(
        math.floor(offsetX), math.floor(offsetY),
        math.ceil(gameWidth * scale), math.ceil(gameHeight * scale)
    )
    love.graphics.translate(offsetX, offsetY)
    love.graphics.scale(scale)
end

function viewport.endDraw()
    love.graphics.pop()
end

return viewport
