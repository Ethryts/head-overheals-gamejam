local baton = require("lib.baton")
local vector = require("lib.hump.vector")
local PlayerAnimation = require("src.player_animation")
local Beam = require("src.beam")

local Player = {}
Player.__index = Player

local PLAYER_SCALE = 4
local PLAYER_HEAD_SCALE = 4
function Player.new(x, y)
  local player = setmetatable({}, Player)

  player.animation = PlayerAnimation.new("assets/images/Healer Asset/Animations", {
    bodyScale = PLAYER_SCALE,
    headScale = PLAYER_HEAD_SCALE,
  })
	player.x = x or 100
	player.y = y or 100
	player.speed = 200

	player.allBeams = {}
	player.currentBeam = nil

	player.speed = 200
  player.direction = 1 -- 1: right, -1: left; preserved while idle.

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

function Player.update(player, dt)
  player.input:update()

  local dx, dy = player.input:get("move")
	local aimX, aimY = player.input:get("aim")
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
	local isHealing = player.input:down("healBeam")
	if isHealing and directionVector ~= nil then
		if not player.currentBeam then
			player.currentBeam = Beam:new(playerPositionVector, directionVector)
			player.allBeams[#player.allBeams + 1] = player.currentBeam
		end
	elseif player.currentBeam and isHealing == false then
		player.currentBeam:startRelease()
		player.currentBeam = nil
	end

  local moveX = dx * player.speed * dt
  local moveY = dy * player.speed * dt

  player.x = player.x + moveX
  player.y = player.y + moveY

	if aimX ~= 0 or aimY ~= 0 then
		player.aimDirection = { x = aimX, y = aimY }
	end

  if player.shape then
    player.shape:move(moveX, moveY)
  end
  player.animation:update(dt)
	for _, beam in ipairs(player.allBeams) do
		beam:update(dt, playerPositionVector, directionVector)
	end
end

function Player.draw(player)
  player.animation:draw(player.x, player.y, player.direction)
	for _, beam in ipairs(player.allBeams) do
		beam:draw()
	end
end

function Player.doesBeamOverlapWithPoint(player, point, radius)
	if not player.allBeams then
		return false
	end
	for _, beam in ipairs(player.allBeams) do
		print ("Checking beam at position: ", beam.bottomLeft.x, beam.bottomLeft.y, " with tip at: ", beam.tip.x, beam.tip.y)
		if beam:containsPoint(point, radius) then
			return true
		end
	end
	return false
end

return Player
