local Stats = require("src.stats")
local baton = require("lib.baton")
local vector = require("lib.hump.vector")
local PlayerAnimation = require("src.player_animation")
local Gamestate = require("gamestate.deps").Gamestate
local Beam = require("src.beam")
local Kick = require("src.kick")
local HealthBar = require("src.health_bar")

---@class Player
---@field x number World-space horizontal position.
---@field y number World-space vertical position.
---@field stats ActorStats Movement stats; pickup abilities can modify them.
---@field health number Current health, 0..stats.maxHealth.
---@field dead boolean
---@field healthBar HealthBar
---@field direction 1|-1 Facing direction, preserved while idle.
---@field animation PlayerAnimation
---@field input BatonInput
---@field shape? HCShape Assigned by the game when collision is enabled.
---@field allBeams Beam[]
---@field currentBeam? Beam
---@field kick Kick
---@field kickDirection HumpVector Current aim, movement, or last nonzero direction.
---@field kickRequested boolean One-frame input, consumed after map collision.
local Player = {}
Player.__index = Player

local PLAYER_SCALE = 4
local PLAYER_HEAD_SCALE = 4
local PLAYER_MAX_HEALTH = 100
local PLAYER_HEAL_SPEED = 10
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
	player.stats = Stats.new(200, PLAYER_MAX_HEALTH, PLAYER_HEAL_SPEED)
  player.health = player.stats.maxHealth
  player.dead = false
  player.healthBar = HealthBar.new()

	player.allBeams = {}
	player.currentBeam = nil

  player.direction = 1 -- 1: right, -1: left; preserved while idle.
  player.kick = Kick.new()
  player.kickDirection = vector(1, 0)
  player.kickRequested = false

  player.input = baton.new({
    controls = {
      left = { "key:a", "axis:leftx-", "button:dpleft" },
      right = { "key:d", "axis:leftx+", "button:dpright" },
      up = { "key:w", "axis:lefty-", "button:dpup" },
      down = { "key:s", "axis:lefty+", "button:dpdown" },
			aimLeft = { "key:left", "axis:rightx-" },
			aimRight = { "key:right", "axis:rightx+" },
			aimUp = { "key:up", "axis:righty-" },
			aimDown = { "key:down", "axis:righty+" },
			healBeam = { "key:space", "axis:triggerright+", "button:rightshoulder" },
      kick = { "key:f", "axis:triggerleft+" },
    },
    pairs = {
      move = { "left", "right", "up", "down" },
			aim = { "aimLeft", "aimRight", "aimUp", "aimDown" },
    },
    joystick = love.joystick.getJoysticks()[1],
    deadzone = 0.25,
  })


  return player
end

---@param player Player
---@param amount number
function Player.takeDamage(player, amount)
  if player.dead then return end
  player.health = math.max(0, player.health - amount)
  if player.health <= 0 then
    player.dead = true
  end
end

-- Spends from the shared heal resource (at stats.healSpeed) to heal the
-- player. Call this from wherever self-heal is triggered (e.g. holding a
-- key while a creature-heal condition, standing on a shrine, etc).
---@param player Player
---@param healResource HealResource
---@param dt number
---@return number amountHealed
function Player.heal(player, healResource, dt)
  if player.dead then return 0 end
  local spent = healResource:spend(player.stats.healSpeed * dt)
  player.health = math.min(player.stats.maxHealth, player.health + spent)
  return spent
end

---@param player Player
---@param dt number Elapsed seconds.
---@param healResource HealResource
function Player.update(player, dt, healResource)
  if player.dead then return end

  player.input:update()
  player.kick:update(dt)
  player.kickRequested = player.input:pressed("kick")

  local dx, dy = player.input:get("move")
	local aimX, aimY = player.input:get("aim")
  if aimX ~= 0 or aimY ~= 0 then
    player.kickDirection = vector(aimX, aimY):normalized()
  elseif dx ~= 0 or dy ~= 0 then
    player.kickDirection = vector(dx, dy):normalized()
  end
  if aimX ~= 0 then
    player.direction = aimX < 0 and -1 or 1
	elseif dx ~= 0 then
		player.direction = dx < 0 and -1 or 1
	end

	local len = math.sqrt(aimX^2 + aimY^2)

	local directionVector = nil
	if len > 0 then
			local aimDx = aimX / len
			local aimYx = aimY / len
			directionVector = vector(aimDx, aimYx)
	end

	local playerPositionVector = vector(player.x, player.y)
	local isHealing = player.input:down("healBeam") and not healResource:isEmpty()
	if isHealing and directionVector ~= nil then
		if not player.currentBeam then
			player.currentBeam = Beam:new(playerPositionVector, directionVector)
			player.allBeams[#player.allBeams + 1] = player.currentBeam
		end
	elseif player.currentBeam and isHealing == false then
		player.currentBeam:startRelease()
		player.currentBeam = nil
	end

  local moveX = dx * player.stats.speed * dt
  local moveY = dy * player.stats.speed * dt

	if moveX ~= 0 and moveY ~= 0 then
		Gamestate.soundEffectsSystem:playWithLowPass("Step")
	end

  player.x = player.x + moveX
  player.y = player.y + moveY

  if player.shape then
    player.shape:move(moveX, moveY)
  end
  player.animation:update(dt)
	for _, beam in ipairs(player.allBeams) do
		beam:update(dt, playerPositionVector, directionVector)
	end
end

-- Called by the game after correcting the healer's position against pillars.
function Player.resolveKick(player, creatures)
  if not player.kickRequested then return false end
  player.kickRequested = false
  return player.kick:tryActivate(player.x, player.y, player.kickDirection, creatures)
end

function Player.resume(player)
  -- Synchronize held controls without turning a press during pause into a kick.
  player.input:update()
  player.kickRequested = false
end

---@param player Player
function Player.draw(player)
  player.animation:draw(player.x, player.y, player.direction)
	for _, beam in ipairs(player.allBeams) do
		beam:draw()
	end
  player.kick:draw()
  player.healthBar:draw(player.x, player.y, player.health / player.stats.maxHealth)
end

function Player.doesBeamOverlapWithPoint(player, point, radius)
	if not player.allBeams then
		return false
	end
	for _, beam in ipairs(player.allBeams) do
		if beam:containsPoint(point, radius) then
			return true
		end
	end
	return false
end

return Player
