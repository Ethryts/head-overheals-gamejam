local common = require("attacks.common")

---@type CreatureAttackBehavior
local projectile = {}

function projectile.update(creature, dt, context, canAttack)
  local target = common.readyTarget(creature, dt, context, canAttack, 300)
  if not target or not context.projectiles then return end
  local tuning = creature.attack.projectile or {}
  local shot = context.projectiles:spawn({
    position = creature.position, direction = target.position - creature.position,
    damage = creature.attack.damage, owner = creature,
    speed = tuning.speed, radius = tuning.radius, lifespan = tuning.lifespan,
  })
  if shot then creature.attackCooldownRemaining = creature.attack.cooldown end
end

return projectile
