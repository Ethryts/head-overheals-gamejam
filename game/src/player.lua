local baton = require("lib.baton")
local PlayerAnimation = require("src.player_animation")

---@class Player
---@field x number World-space horizontal position.
---@field y number World-space vertical position.
---@field speed number World pixels per second.
---@field direction 1|-1 Facing direction, preserved while idle.
---@field animation PlayerAnimation
---@field input BatonInput
---@field shape? HCShape Assigned by the game when collision is enabled.
local Player = {}
Player.__index = Player

local PLAYER_SCALE = 4
local PLAYER_HEAD_SCALE = 4
---@param x? number Defaults to 100.
---@param y? number Defaults to 100.
---@return Player
function Player.new(x, y)
  local player = setmetatable({}, Player)

  player.animation = PlayerAnimation.new("assets/images/Healer Asset/Animations", {
    bodyScale = PLAYER_SCALE,
    headScale = PLAYER_HEAD_SCALE,
  })
    player.x = x or 100
    player.y = y or 100
    player.speed = 200

  player.direction = 1 -- 1: right, -1: left; preserved while idle.

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

---@param player Player
---@param dt number Elapsed seconds.
function Player.update(player, dt)
  player.input:update()

  local dx, dy = player.input:get("move")
  if dx ~= 0 then
    player.direction = dx < 0 and -1 or 1
  end

  local moveX = dx * player.speed * dt
  local moveY = dy * player.speed * dt

  player.x = player.x + moveX
  player.y = player.y + moveY

  if player.shape then
    player.shape:move(moveX, moveY)
  end
  player.animation:update(dt)
end

---@param player Player
function Player.draw(player)
  player.animation:draw(player.x, player.y, player.direction)
end

return Player
