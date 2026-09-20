local Stats = require("src.stats")
local Gamestate = require("gamestate.deps").Gamestate
local vector            = require("lib.hump.vector")
local PlayerAnimation   = require("src.player_animation")
local Player            = require("src.player")
local HealthBar = require("src.health_bar")

---@class Knight: CreatureActor
---@field direction 1|-1 Facing direction, preserved while idle.
---@field animation PlayerAnimation
---@field health number Clamped to 0..(stats.maxHealth * OVERHEAL_RATIO) by setHealth.
---@field stats ActorStats Movement/health stats; pickup abilities can modify them.
---@field healthBar HealthBar
---@field state "idle"|"moving"|"attacking"
---@field idleTimer number Seconds remaining before choosing a destination.
---@field attackCooldown number Seconds remaining before the next attack.
---@field destination? HumpVector
---@field dead boolean
---@field overhealed boolean
---@field healedThisUpdate boolean Visual feedback for active healing.
---@field patrolRadius? number Patrol radius in world pixels.
---@field patrolAnchor? HumpVector Center of the patrol area.
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
local OVERHEAL_RATIO   = 2.0 -- past this, his head explodes
local STARTING_HEALTH  = 30
local STARTING_MAX_HEALTH  = 100 -- normal healthy cap
local STARTING_HEAL_SPEED  = 1
local KNIGHT_SCALE      = 3
local KNIGHT_HEAD_SCALE = 3

local function rollIdleDuration()
  if math.random() < IDLE_SHORT_CHANCE then
    return IDLE_SHORT_MIN + math.random() * (IDLE_SHORT_MAX - IDLE_SHORT_MIN)
  else
    return IDLE_LONG_MIN + math.random() * (IDLE_LONG_MAX - IDLE_LONG_MIN)
  end
end

---@param x number World-space horizontal position.
---@param y number World-space vertical position.
---@return Knight
function Knight.new(x, y)
  local self = setmetatable({}, Knight)
  self.position = vector(x, y)
  self.direction = 1 -- 1: right, -1: left; preserved while idle.
  self.animation = PlayerAnimation.new("assets/images/Hero Asset/Animations", {
    bodyScale = KNIGHT_SCALE,
    headScale = KNIGHT_HEAD_SCALE,
  })
  self.health = STARTING_HEALTH
  self.stats = Stats.new(MOVE_SPEED, STARTING_MAX_HEALTH, STARTING_HEAL_SPEED)
  self.healthBar = HealthBar.new()
  self.state = "idle"
  self.idleTimer = rollIdleDuration()
  self.attackCooldown = 0
  self.destination = nil
  self.dead = false
  self.overhealed = false
  self.healedThisUpdate = false
  return self
end

---@param radius number Patrol radius in world pixels.
---@param anchor? HumpVector Defaults to a copy of the current position.
function Knight:setPatrolRadius(radius, anchor)
  self.patrolRadius = radius
  self.patrolAnchor = anchor or self.position:clone()
end

-- Setting health directly also lets debug tools reset death/overheal states.
---@param amount number Absolute health; resets death/overheal flags.
function Knight:setHealth(amount)

	local overhealLimit = self.stats.maxHealth * OVERHEAL_RATIO
  self.health = math.max(0, math.min(overhealLimit, amount))
  self.dead = self.health <= 0
  self.overhealed = self.health >= overhealLimit
  local percentage_over = (self.health - self.stats.maxHealth) / (overhealLimit - self.stats.maxHealth)
  self.animation.headScale = math.max(KNIGHT_HEAD_SCALE * (1 + percentage_over), KNIGHT_HEAD_SCALE)
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
---@param amount number Health to subtract.
function Knight:takeDamage(amount)
  if self.dead or self.overhealed then return end
  self:setHealth(self.health - amount)
end

-- Healing (pickups, buffs, etc). Safe below MAX_SAFE_HEALTH, risky above it,
-- fatal at OVERHEAL_LIMIT.
---@param amount number Health to add.
function Knight:heal(amount)
  if self.dead or self.overhealed then return end
  self:setHealth(self.health + amount)
  if amount > 0 then self.healedThisUpdate = true end
end

local function findInRange(self, creatureSystem, range)
  local inRange = {}
  for _, creature in ipairs(creatureSystem:getAll()) do
    local dist = (creature.position - self.position):len()
    if dist <= range then
      inRange[#inRange + 1] = creature
    end
  end
  return inRange
end

---@param dt number Elapsed seconds.
---@param creatureSystem CreatureSystem
---@param player Player
---@param healResource HealResource
function Knight:update(dt, creatureSystem, player, healResource)
  self.healedThisUpdate = false
  if self.dead or self.overhealed then return end

  self.animation:update(dt)
  self.attackCooldown = math.max(0, self.attackCooldown - dt)

  local targets = findInRange(self, creatureSystem, ATTACK_RANGE)
  local isAttacking = #targets > 0

  if isAttacking and self.attackCooldown <= 0 then
    local offset = targets[1].position - self.position
    if offset.x ~= 0 then self.direction = offset.x < 0 and -1 or 1 end
    if creatureSystem.fx then
      creatureSystem.fx:emit("swing", self.position.x, self.position.y, {
        angle = math.atan2(offset.y, offset.x), radius = ATTACK_RANGE,
        depth = self.animation:getFeetY(self.position.y),
      })
    end
    Gamestate.soundEffectsSystem:playSoundEffect("Swing")
    for _, target in ipairs(targets) do
      creatureSystem:damage(target, 1, self.position)
    end
    self.attackCooldown = ATTACK_COOLDOWN
  end

  if isAttacking then
    self.state = "attacking"
  elseif self.state == "attacking" then
    self.state = "idle"
    self.idleTimer = rollIdleDuration()
  end

  if self.state == "idle" then
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
      self.position = self.position + (toGoal / distance) * self.stats.speed * dt
    end
  end
  if Player.doesBeamOverlapWithPoint(player, self.position, ATTACK_RANGE) then
    local spent = healResource:spend(self.stats.healSpeed * dt)
    if spent > 0 then
      self:heal(spent)
    end
  end
end

function Knight:draw()
  self.animation:draw(self.position.x, self.position.y, self.direction)


	local overhealLimit = self.stats.maxHealth * OVERHEAL_RATIO

  -- Flush red as he climbs past the safe cap toward the overheal limit.
  local overRatio = math.max(0, (self.health - self.stats.maxHealth) / (overhealLimit - self.stats.maxHealth))
  local fillColor = { 1, 1 - overRatio, 1 - overRatio, 1 }
  self.healthBar:draw(self.position.x, self.position.y, self.health / overhealLimit, fillColor)
end

function Knight:GetHealthPercentage()
	return (self.health / self.stats.maxHealth) * 100
end

return Knight
