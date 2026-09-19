local baton = require("lib.baton")

local Player = {}
Player.__index = Player

function Player.new(x, y)
    local player = setmetatable({}, Player)

    player.x = x or 100
    player.y = y or 100
    player.speed = 200

    player.input = baton.new({
        controls = {
            left = { "key:left", "key:a", "axis:leftx-", "button:dpleft" },
            right = { "key:right", "key:d", "axis:leftx+", "button:dpright" },
            up = { "key:up", "key:w", "axis:lefty-", "button:dpup" },
            down = { "key:down", "key:s", "axis:lefty+", "button:dpdown" }
        },
        pairs = {
          move = { "left", "right", "up", "down" }
    },
    joystick = love.joystick.getJoysticks()[1],
    deadzone = 0.25,
  })

    return player
end

function Player.update(player, dt)
    player.input:update()

    local dx, dy = player.input:get("move")

    local moveX = dx * player.speed * dt
    local moveY = dy * player.speed * dt

    player.x = player.x + moveX
    player.y = player.y + moveY

    if player.shape then
      player.shape:move(moveX, moveY)
    end
end

function Player.draw(player)
    love.graphics.circle("fill", player.x, player.y, 16)
end

return Player
