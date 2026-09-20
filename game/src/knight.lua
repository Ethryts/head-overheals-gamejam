local vector            = require("lib.hump.vector")
local PlayerAnimation   = require("src.player_animation")
local Player            = require("src.player")

local Knight            = {}
Knight.__index          = Knight

local ATTACK_RANGE      = 60
local ATTACK_COOLDOWN   = 0.8
local IDLE_DURATION     = 3
local MOVE_SPEED        = 120
local MAX_SAFE_HEALTH   = 100 -- normal healthy cap
local OVERHEAL_LIMIT    = 200 -- past this, his head explodes
local STARTING_HEALTH   = 10
local KNIGHT_SCALE      = 4
local KNIGHT_HEAD_SCALE = 4

Knight.OVERHEAL_LIMIT   = OVERHEAL_LIMIT

function Knight.new(x, y)
  local self = setmetatable({}, Knight)
  self.position = vector(x, y)
  self.direction = 1 -- 1: right, -1: left; preserved while idle.
  self.animation = PlayerAnimation.new("assets/images/Hero Asset/Animations", {
    bodyScale = KNIGHT_SCALE,
    headScale = KNIGHT_HEAD_SCALE,
  })
  self.health = STARTING_HEALTH
  self.speed = MOVE_SPEED
  self.state = "idle"
  self.idleTimer = IDLE_DURATION
  self.attackCooldown = 0
  self.destination = nil
  self.dead = false
  self.overhealed = false
  return self
end

function Knight:setPatrolArea(minX, minY, maxX, maxY)
  self.minX, self.minY, self.maxX, self.maxY = minX, minY, maxX, maxY
end

-- Setting health directly also lets debug tools reset death/overheal states.
function Knight:setHealth(amount)
  self.health = math.max(0, math.min(OVERHEAL_LIMIT, amount))
  self.dead = self.health <= 0
  self.overhealed = self.health >= OVERHEAL_LIMIT
  local percentage_over = (self.health - MAX_SAFE_HEALTH) / (OVERHEAL_LIMIT - MAX_SAFE_HEALTH)
  self.animation.headScale = math.max(KNIGHT_HEAD_SCALE * (1 + percentage_over), KNIGHT_HEAD_SCALE)
end

-- Normal damage from creatures. No upper concern here, just death at 0.
function Knight:takeDamage(amount)
  if self.dead or self.overhealed then return end
  self:setHealth(self.health - amount)
end

-- Healing (pickups, buffs, etc). Safe below MAX_SAFE_HEALTH, risky above it,
-- fatal at OVERHEAL_LIMIT.
function Knight:heal(amount)
  if self.dead or self.overhealed then return end
  self:setHealth(self.health + amount)
  if self.overhealed then
    -- hook: trigger head-explode animation / game over here
  end
end

local function pickDestination(self)
  local x = math.random(self.minX or self.position.x - 150, self.maxX or self.position.x + 150)
  local y = math.random(self.minY or self.position.y - 150, self.maxY or self.position.y + 150)
  return vector(x, y)
end

local function findNearest(self, creatureSystem)
  local nearest, nearestDist
  for _, creature in ipairs(creatureSystem:getAll()) do
    local dist = (creature.position - self.position):len()
    if not nearestDist or dist < nearestDist then
      nearest, nearestDist = creature, dist
    end
  end
  return nearest, nearestDist
end

function Knight:update(dt, creatureSystem, player)
  if self.dead or self.overhealed then return end

  self.animation:update(dt)
  self.attackCooldown = math.max(0, self.attackCooldown - dt)

  local nearest, dist = findNearest(self, creatureSystem)

  if nearest and dist <= ATTACK_RANGE then
    local dx = nearest.position.x - self.position.x
    if dx ~= 0 then self.direction = dx < 0 and -1 or 1 end
    self.state = "attacking"
    if self.attackCooldown <= 0 then
      creatureSystem:damage(nearest, 1)
      self.attackCooldown = ATTACK_COOLDOWN
    end
  elseif self.state == "attacking" then
    self.state = "idle"
    self.idleTimer = IDLE_DURATION
  elseif self.state == "idle" then
    self.idleTimer = self.idleTimer - dt
    if self.idleTimer <= 0 then
      self.destination = pickDestination(self)
      self.state = "moving"
    end
  elseif self.state == "moving" then
    local toGoal = self.destination - self.position
    local distance = toGoal:len()
    if distance < 4 then
      self.state = "idle"
      self.idleTimer = IDLE_DURATION
    else
      if toGoal.x ~= 0 then self.direction = toGoal.x < 0 and -1 or 1 end
      self.position = self.position + (toGoal / distance) * self.speed * dt
    end
  end

	if Player.doesBeamOverlapWithPoint(player, self.position, ATTACK_RANGE) then
		self:heal(dt * 10)
	end

  self:clampToScreen()
end

function Knight:clampToScreen()
  local width, height = love.graphics.getDimensions()
  local margin = 16

  self.position.x = math.max(margin, math.min(width - margin, self.position.x))
  self.position.y = math.max(margin, math.min(height - margin, self.position.y))
end

function Knight:draw()
  self.animation:draw(self.position.x, self.position.y, self.direction)

  if self.state == "attacking" then
    love.graphics.setColor(1, 0.3, 0.3, 0.5)
    love.graphics.circle("line", self.position.x, self.position.y, ATTACK_RANGE)
  end

  -- Flush red as he climbs past the safe cap toward the overheal limit.
  local overRatio = math.max(0, (self.health - MAX_SAFE_HEALTH) / (OVERHEAL_LIMIT - MAX_SAFE_HEALTH))
  love.graphics.setColor(1, 1 - overRatio, 1 - overRatio)
  love.graphics.print(string.format("HP: %d / %d", self.health, OVERHEAL_LIMIT),
    self.position.x - 24, self.position.y - 34)
end

function Knight:GetHealthPercentage()
	return (self.health / MAX_SAFE_HEALTH) * 100
end

return Knight
