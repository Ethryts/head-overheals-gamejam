-- Replace this screen with your game. Keep ordinary LÖVE APIs and callbacks;
-- there is deliberately no engine, scene system, or gameplay architecture.
local project = require("project")
local game = {}
local fonts = {}
local elapsed, pulse, inputCount = 0, 0, 0
local focused, showStats = true, false
local volumeBeforeBlur
local accents = { { 0.51, 0.91, 0.76 }, { 1.0, 0.70, 0.43 } }
local Player = require("src.player")

local function text(value, x, y, font, color)
    love.graphics.setFont(font)
    love.graphics.setColor(color)
    love.graphics.print(value, x, y)
end

local function activate()
    inputCount = inputCount + 1
    pulse = 1
    print("[jam] input")
end

function game.load()
    fonts.small = love.graphics.newFont(13)
    fonts.body = love.graphics.newFont(17)
    fonts.title = love.graphics.newFont(50)
    game.player = Player.new(400, 300)
end

function game.update(dt)
    if not focused then return end
    -- Ignore large catch-up steps after browser suspension or a breakpoint.
    dt = math.min(dt, 0.1)
    elapsed = elapsed + dt
    pulse = math.max(0, pulse - dt * 1.5)
    Player.update(game.player, dt)
end

function game.draw()
    local width, height = project.width, project.height
    local accent = accents[inputCount % #accents + 1]
    local white = { 0.91, 0.94, 0.93 }
    local muted = { 0.52, 0.59, 0.61 }

    love.graphics.setColor(0.055, 0.075, 0.085)
    love.graphics.rectangle("fill", 0, 0, width, height)

    love.graphics.setColor(accent)
    love.graphics.rectangle("fill", 54, 48, 10, 10, 2, 2)
    text("LÖVE / JAM STARTER", 77, 45, fonts.small, white)
    text("YOUR NEXT IDEA STARTS HERE", 54, height * 0.34,
        fonts.small, accent)
    text("Ready to build.", 50, height * 0.40, fonts.title, white)
    text("A small starting point. A blank canvas.", 54, height * 0.54,
        fonts.body, muted)

    -- A small input indicator, independent of any game genre.
    local centerX, centerY = width * 0.79, height * 0.47
    love.graphics.push()
    love.graphics.translate(centerX, centerY)
    love.graphics.setColor(0.13, 0.19, 0.20)
    love.graphics.setLineWidth(1)
    love.graphics.circle("line", 0, 0, 91, 64)
    love.graphics.setColor(accent[1], accent[2], accent[3], 0.10 + pulse * 0.12)
    love.graphics.circle("fill", 0, 0, 73 + pulse * 12, 64)
    love.graphics.rotate(elapsed * 0.15)
    love.graphics.setColor(accent)
    love.graphics.setLineWidth(2)
    local size = 37 + math.sin(elapsed * 2) * 2 + pulse * 10
    love.graphics.rectangle("line", -size, -size, size * 2, size * 2, 9, 9)
    love.graphics.circle("fill", 0, 0, 5 + pulse * 3)
    love.graphics.pop()

    love.graphics.setFont(fonts.small)
    love.graphics.setColor(pulse > 0 and accent or muted)
    love.graphics.printf(pulse > 0 and "INPUT RECEIVED" or "AWAITING INPUT",
        centerX - 115, centerY + 112, 230, "center")

    love.graphics.setColor(0.16, 0.21, 0.22)
    love.graphics.line(54, height - 95, width - 54, height - 95)
    text("CLICK OR SPACE", 54, height - 69, fonts.small, white)
    text("Test input", 181, height - 69, fonts.small, muted)
    love.graphics.setColor(muted)
    love.graphics.printf("F3  Stats", width - 204, height - 69, 150, "right")

    if showStats then
        text(string.format("%d FPS  /  %.1f MB Lua", love.timer.getFPS(),
            collectgarbage("count") / 1024), 54, height - 32, fonts.small, accent)
    end

    if not focused then
        love.graphics.setColor(0.025, 0.04, 0.05, 0.82)
        love.graphics.rectangle("fill", 0, 0, width, height)
        love.graphics.setColor(white)
        love.graphics.setFont(fonts.body)
        love.graphics.printf("Paused — click to focus", 0, height / 2 - 12,
            width, "center")
    end

    love.graphics.setColor(1,1,1)
    Player.draw(game.player)
end

function game.keypressed(key, scancode, isrepeat)
    if isrepeat then return end
    if key == "f3" then showStats = not showStats end
    if key == "space" then activate() end
end

function game.mousepressed(x, y, button)
    if button == 1 then activate() end
end

function game.focus(hasFocus)
    focused = hasFocus
    if not hasFocus and volumeBeforeBlur == nil then
        volumeBeforeBlur = love.audio.getVolume()
        love.audio.setVolume(0)
    elseif hasFocus and volumeBeforeBlur ~= nil then
        love.audio.setVolume(volumeBeforeBlur)
        volumeBeforeBlur = nil
    end
end

return game
