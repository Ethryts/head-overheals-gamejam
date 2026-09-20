local vector = require("lib.hump.vector")
local animations = require("systems.monster_animations")
local Gamestate = require("gamestate.deps").Gamestate
local behavior = require("behavior")

---@class CreatureActor
---@field position HumpVector Current position in the same game coordinates as creatures.

---@class CreatureSystemContext
---@field knight? CreatureActor Live knight object; chase follows its position. Nil means no target.
---@field healer? CreatureActor Live healer object, available to behaviors; idle/chase do not target it.
---@field resolveKnockback? fun(creature: Creature, destination: HumpVector): HumpVector, boolean Returns corrected position and whether a structure was hit.

---@class CreatureKnockback
---@field direction HumpVector
---@field distance number
---@field duration number
---@field elapsed number
---@field blocked boolean

---@class CreatureBehavior
---@field update fun(creature: Creature, dt: number, context: CreatureSystemContext) Sets velocity; CreatureSystem applies movement.

---@class Attack
---@field type "melee"|"ranged"
---@field damage number
---@field cooldown number Seconds between attacks.
---@field range? number
---@field animations? table<string, Anim8Animation>

---@class Creature
---@field kind string Monster catalog ID.
---@field health number
---@field speed number Game pixels per second.
---@field position HumpVector Sprite center in game coordinates.
---@field velocity HumpVector
---@field image love.Image
---@field animations table<string, Anim8Animation>
---@field scale number
---@field attack? Attack
---@field behavior CreatureBehavior Shared behavior module; defaults to behavior.idle.
---@field knockback? CreatureKnockback Overrides movement and interrupts attacks.
---@field attackCooldownRemaining number

---@class CreatureOptions
---@field health? number Defaults to 1.
---@field speed? number Defaults to 0.
---@field scale? number Defaults to 1.
---@field frameDuration? number Seconds per frame; defaults to 0.2.
---@field behavior? CreatureBehavior Defaults to behavior.idle.
---@field attack? Attack defaults to a basic melee attack (1 damage, 1s cooldown, 24 range).

---@class CreatureSystem
---@field private creatures Creature[]
local CreatureSystem = {}
CreatureSystem.__index = CreatureSystem

local DEFAULT_ATTACK = { type = "melee", damage = 1, cooldown = 1, range = 24 }

---@return CreatureSystem
function CreatureSystem.new()
  return setmetatable({ creatures = {} }, CreatureSystem)
end

---@param monsterId string
---@param x number
---@param y number
---@param options? CreatureOptions
---@return Creature
function CreatureSystem:create(monsterId, x, y, options)
  options = options or {}
  local image, clips = animations.loadMonster(monsterId, options.frameDuration)
  ---@type Creature
  local creature = {
    kind = monsterId,
    health = options.health or 1,
    speed = options.speed or 0,
    position = vector(x, y),
    velocity = vector(0, 0),
    image = image,
    animations = clips,
    scale = options.scale or 1,
    behavior = options.behavior or behavior.idle,
    attack = options.attack or DEFAULT_ATTACK,
    attackCooldownRemaining = 0,
  }
  self.creatures[#self.creatures + 1] = creature
  return creature
end

local function tryAttack(creature, context)
  local target = context.knight
  if not (creature.attack and target and target.position and type(target.takeDamage) == "function") then
    return
  end
  
  local range = creature.attack.range or DEFAULT_ATTACK.range
  local distance = (target.position - creature.position):len()

  if distance <= range and creature.attackCooldownRemaining <= 0 then
    target:takeDamage(creature.attack.damage)
    creature.attackCooldownRemaining = creature.attack.cooldown
  end
end

---@param creature Creature
---@param direction HumpVector
---@param distance number Total travel in world pixels, unless blocked.
---@param duration number Seconds of movement and attack interruption.
---@return boolean
function CreatureSystem:applyKnockback(creature, direction, distance, duration)
  if creature.health <= 0 or direction:len() == 0 or duration <= 0 or distance <= 0 then
    return false
  end
  creature.knockback = {
    direction = direction:normalized(), distance = distance, duration = duration,
    elapsed = 0, blocked = false,
  }
  creature.velocity = vector(0, 0)
  return true
end

local function updateKnockback(creature, dt, context)
  local kick = creature.knockback
  local consumed = math.min(dt, kick.duration - kick.elapsed)
  local before = kick.elapsed / kick.duration
  kick.elapsed = math.min(kick.duration, kick.elapsed + consumed)
  local after = kick.elapsed / kick.duration
  -- Integral of linearly decreasing speed; independent of the frame subdivision.
  local travel = kick.distance * ((2 * after - after * after) - (2 * before - before * before))
  if not kick.blocked and consumed > 0 then
    local destination = creature.position + kick.direction * travel
    if context.resolveKnockback then
      destination, kick.blocked = context.resolveKnockback(creature, destination)
    end
    creature.position = destination
  end
  creature.velocity = vector(0, 0)
  if kick.elapsed >= kick.duration then creature.knockback = nil end
  return math.max(0, dt - consumed)
end

---@param dt number Elapsed seconds.
---@param context? CreatureSystemContext References to the current knight and healer; omitted means neither is present.
function CreatureSystem:update(dt, context)
  context = context or {}
  for _, creature in ipairs(self.creatures) do
    local wasKnockedBack = creature.knockback ~= nil
    local activeDt = wasKnockedBack and updateKnockback(creature, dt, context) or dt
    creature.attackCooldownRemaining = math.max(0, creature.attackCooldownRemaining - dt)
    if not wasKnockedBack or activeDt > 1e-9 then
      creature.behavior.update(creature, activeDt, context)
      creature.position = creature.position + creature.velocity * activeDt
      tryAttack(creature, context)
    end
    creature.animations.idle:update(dt)
  end
end

function CreatureSystem:draw()
  love.graphics.push("all")
  for _, creature in ipairs(self.creatures) do
    local flash = creature.knockback
      and (1 - creature.knockback.elapsed / creature.knockback.duration) or 0
    love.graphics.setColor(1, 1, 1 - 0.7 * flash, 1)
    local animation = creature.animations.idle
    local width, height = animation:getDimensions()
    animation:draw(creature.image,
      creature.position.x, creature.position.y, 0, creature.scale, creature.scale,
      width / 2, height / 2)
  end
  love.graphics.pop()
end

---@return Creature[]
function CreatureSystem:getAll()
  return self.creatures
end

---@param creature Creature
---@param amount number
function CreatureSystem:damage(creature, amount)
  creature.health = creature.health - amount
  if creature.health <= 0 then
    for i, c in ipairs(self.creatures) do
      if c == creature then
				Gamestate.soundEffectsSystem:playSoundEffect("MonsterDeath")
				if creature.kind == 'death_slime' or creature.kind == 'ochre_jelly' then
					Gamestate.soundEffectsSystem:playSoundEffect("SlimeDeath", true)
				end
				if creature.kind == 'bloodshot_eye' then
					Gamestate.soundEffectsSystem:playSoundEffect("EyeballDeath", true)
				end
        table.remove(self.creatures, i)
        break
      end
    end
  end
end

return CreatureSystem
