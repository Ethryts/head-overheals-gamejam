local vector = require("lib.hump.vector")
local animations = require("systems.monster_animations")
local Gamestate = require("gamestate.deps").Gamestate
local behavior = require("behavior")
local attacks = require("attacks")

---@class CreatureActor
---@field position HumpVector Current position in the same game coordinates as creatures.

---@class CreatureSystemContext
---@field fx? FxSystem
---@field projectiles? ProjectileSystem Ranged attacks spawn into this system.
---@field knight? CreatureActor|ProjectileTarget Live knight object; chase follows its position. Nil means no target.
---@field healer? CreatureActor Live healer object, available to behaviors; idle/chase do not target it.
---@field resolveKnockback? fun(creature: Creature, destination: HumpVector): HumpVector, boolean, StructureImpact? Returns corrected position, collision flag and optional surface contact.

---@class CreatureKnockback
---@field direction HumpVector
---@field distance number
---@field duration number
---@field elapsed number
---@field blocked boolean

---@class CreatureMovementBehavior
---@field update fun(creature: Creature, dt: number, context: CreatureSystemContext) Sets velocity; CreatureSystem applies movement.

---@class CreatureAttackBehavior
---@field update fun(creature: Creature, dt: number, context: CreatureSystemContext, canAttack: boolean) Advances cooldown and attacks only when permitted by the system.

---@class Attack
---@field type "melee"|"ranged"
---@field damage number
---@field cooldown number Seconds between attacks.
---@field range? number
---@field projectile? { speed?: number, radius?: number, lifespan?: number } Ranged shot tuning.
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
---@field movementBehavior CreatureMovementBehavior Shared movement module.
---@field attackBehavior CreatureAttackBehavior Shared attack module; state stays on the creature.
---@field knockback? CreatureKnockback Overrides movement and interrupts attacks.
---@field attackCooldownRemaining number

---@class CreatureOptions
---@field attackBehavior? CreatureAttackBehavior Defaults to attacks.projectile for ranged attacks, otherwise attacks.melee.
---@field health? number Defaults to 1.
---@field speed? number Defaults to 0.
---@field scale? number Defaults to 1.
---@field frameDuration? number Seconds per frame; defaults to 0.2.
---@field movementBehavior? CreatureMovementBehavior Defaults to behavior.ranged for ranged attacks, otherwise behavior.idle.
---@field attack? Attack Bloodshot Eyes default to ranged; other creatures default to melee.

---@class CreatureSystem
---@field private creatures Creature[]
---@field fx? FxSystem
local CreatureSystem = {}
CreatureSystem.__index = CreatureSystem

local DEFAULT_ATTACK = { type = "melee", damage = 1, cooldown = 1, range = 24 }
local EYE_ATTACK = { type = "ranged", damage = 1, cooldown = 1.5, range = 300,
  projectile = { speed = 240, radius = 4, lifespan = 3 } }

---@return CreatureSystem
---@param fx? FxSystem
function CreatureSystem.new(fx)
  return setmetatable({ creatures = {}, fx = fx }, CreatureSystem)
end

---@param monsterId string
---@param x number
---@param y number
---@param options? CreatureOptions
---@return Creature
function CreatureSystem:create(monsterId, x, y, options)
  options = options or {}
  local image, clips = animations.loadMonster(monsterId, options.frameDuration)
  local attack = options.attack or (monsterId == "bloodshot_eye" and EYE_ATTACK or DEFAULT_ATTACK)
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
    movementBehavior = options.movementBehavior or (attack.type == "ranged" and behavior.ranged or behavior.idle),
    attack = attack,
    attackBehavior = options.attackBehavior or (attack.type == "ranged" and attacks.projectile or attacks.melee),
    attackCooldownRemaining = 0,
  }
  self.creatures[#self.creatures + 1] = creature
  return creature
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

local function updateKnockback(creature, dt, context, pendingKills)
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
      local impact
      destination, kick.blocked, impact = context.resolveKnockback(creature, destination)
      if kick.blocked then
        if context.fx then
          local x = impact and impact.x or destination.x + kick.direction.x * 6 * creature.scale
          local y = impact and impact.y or destination.y + kick.direction.y * 6 * creature.scale
          local nx = impact and impact.normalX or -kick.direction.x
          local ny = impact and impact.normalY or -kick.direction.y
          context.fx:emit("impact", x, y, {angle = math.atan2(ny, nx), depth = destination.y + 8 * creature.scale})
          context.fx:emit("dust", destination.x, destination.y + 8 * creature.scale)
        end
        pendingKills[#pendingKills + 1] = creature
      end
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
  local canAttack = {}
  local pendingKills = {}
  -- Resolve every movement before any attack reads the resulting positions.
  for _, creature in ipairs(self.creatures) do
    local wasKnockedBack = creature.knockback ~= nil
    local activeDt = wasKnockedBack and updateKnockback(creature, dt, context, pendingKills) or dt
    canAttack[creature] = not wasKnockedBack or activeDt > 1e-9
    if canAttack[creature] then
      creature.movementBehavior.update(creature, activeDt, context)
      creature.position = creature.position + creature.velocity * activeDt
    end
    creature.animations.idle:update(dt)
  end
  for _, creature in ipairs(self.creatures) do
    creature.attackBehavior.update(creature, dt, context, canAttack[creature] == true)
  end
  for _, creature in ipairs(pendingKills) do
    self:damage(creature, creature.health)
  end
end

---@param creature Creature
function CreatureSystem:getFeetY(creature)
  local _, height = creature.animations.idle:getDimensions()
  return creature.position.y + height / 2 * creature.scale
end

---@param creature Creature
function CreatureSystem:drawCreature(creature)
  love.graphics.push("all")
  local flash = creature.knockback
    and (1 - creature.knockback.elapsed / creature.knockback.duration) or 0
  love.graphics.setColor(1, 1, 1 - 0.7 * flash, 1)
  local animation = creature.animations.idle
  local width, height = animation:getDimensions()
  animation:draw(creature.image, creature.position.x, creature.position.y,
    0, creature.scale, creature.scale, width / 2, height / 2)
  love.graphics.pop()
end

function CreatureSystem:draw()
  for _, creature in ipairs(self.creatures) do self:drawCreature(creature) end
end

---@return Creature[]
function CreatureSystem:getAll()
  return self.creatures
end

---@param creature Creature
---@param amount number
---@param origin? HumpVector Hit source used for directional sparks.
function CreatureSystem:damage(creature, amount, origin)
  if self.fx and amount > 0 and creature.health > 0 then
    local dx = origin and creature.position.x - origin.x or 1
    local dy = origin and creature.position.y - origin.y or 0
    self.fx:emit("sparks", creature.position.x, creature.position.y, {
      angle = math.atan2(dy, dx), depth = creature.position.y + 8 * creature.scale,
    })
  end
  creature.health = creature.health - amount
  if creature.health <= 0 then
    for i, c in ipairs(self.creatures) do
      if c == creature then
				Gamestate.soundEffectsSystem:playSoundEffect("MonsterDeath")
				if creature.kind == 'death_slime' or creature.kind == 'ochre_jelly' then
					Gamestate.soundEffectsSystem:playSoundEffect("SlimeDeath", true)
				elseif creature.kind == 'bloodshot_eye' then
					Gamestate.soundEffectsSystem:playSoundEffect("EyeballDeath", true)
				else 
					Gamestate.soundEffectsSystem:playSoundEffect("GeneralDeath", true)
				end
        table.remove(self.creatures, i)
        break
      end
    end
  end
end

return CreatureSystem
