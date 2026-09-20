local common = require("attacks.common")

---@type CreatureAttackBehavior
local melee = {}

function melee.update(creature, dt, context, canAttack)
  local target = common.readyTarget(creature, dt, context, canAttack, 24)
  if not target then return end
  target:takeDamage(creature.attack.damage)
  creature.attackCooldownRemaining = creature.attack.cooldown
end

return melee
