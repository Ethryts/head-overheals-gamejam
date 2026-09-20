local vector            = require("lib.hump.vector")
local PlayerAnimation   = require("src.player_animation")

local Knight            = {}
Knight.__index          = Knight

local ATTACK_RANGE     = 60
local ATTACK_COOLDOWN  = 0.8
local IDLE_SHORT_MIN = 0.5
local IDLE_SHORT_MAX = 1
local IDLE_LONG_MIN = 2
local IDLE_LONG_MAX = 4
local IDLE_SHORT_CHANCE = 0.7 
local MOVE_SPEED       = 120
local MAX_SAFE_HEALTH  = 100 -- normal healthy cap
local OVERHEAL_LIMIT   = 200 -- past this, his head explodes
local STARTING_HEALTH  = 10
local KNIGHT_SCALE      = 4
local KNIGHT_HEAD_SCALE = 4

Knight.OVERHEAL_LIMIT   = OVERHEAL_LIMIT

local function rollIdleDuration()
  if math.random() < IDLE_SHORT_CHANCE then
    return IDLE_SHORT_MIN + math.random() * (IDLE_SHORT_MAX - IDLE_SHORT_MIN)
  else
    return IDLE_LONG_MIN + math.random() * (IDLE_LONG_MAX - IDLE_LONG_MIN)
  end
end

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
  self.idleTimer = rollIdleDuration() 
  self.attackCooldown = 0
  self.destination = nil
  self.dead = false
  self.overhealed = false
  return self
end

function Knight:setPatrolRadius(radius, anchor)
  self.patrolRadius = radius
  self.patrolAnchor = anchor or self.position:clone()
end

-- Setting health directly also lets debug tools reset death/overheal states.
function Knight:setHealth(amount)
  self.health = math.max(0, math.min(OVERHEAL_LIMIT, amount))
  self.dead = self.health <= 0
  self.overhealed = self.health >= OVERHEAL_LIMIT
  local percentage_over = (self.health - MAX_SAFE_HEALTH) / (OVERHEAL_LIMIT - MAX_SAFE_HEALTH)
  self.animation.headScale = math.max(KNIGHT_HEAD_SCALE * (1 + percentage_over), KNIGHT_HEAD_SCALE)
end

function Knight:setPatrolRadius(radius, anchor)
  self.patrolRadius = radius
  self.patrolAnchor = anchor or self.position:clone()
end


local function pickDestination(self)
  if self.patrolRadius then
    local angle = math.random() * math.pi * 2
    local distance = math.random() * self.patrolRadius
    return self.patrolAnchor + vector(math.cos(angle), math.sin(angle)) * distance
  end

  -- fallback
  local x = self.position.x + math.random(-150, 150)
  local y = self.position.y + math.random(-150, 150)
  return vector(x, y)
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

function Knight:update(dt, creatureSystem)
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
    self.idleTimer = rollIdleDuration() 
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
      self.idleTimer = rollIdleDuration() 
    else
      if toGoal.x ~= 0 then self.direction = toGoal.x < 0 and -1 or 1 end
      self.position = self.position + (toGoal / distance) * self.speed * dt
    end
  end
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

return Knight
