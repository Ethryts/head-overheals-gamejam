local common = require("attacks.common")

---@type CreatureAttackBehavior
local melee = {}

function melee.update(creature, dt, context, canAttack)
  local target = common.readyTarget(creature, dt, context, canAttack, 24)
  if not target then return end
  target:takeDamage(creature.attack.damage)
  if context.fx then
    local offset = target.position - creature.position
    context.fx:emit("sparks", target.position.x, target.position.y, {
      angle = math.atan2(offset.y, offset.x), depth = target.position.y + 32,
    })
  end
  creature.attackCooldownRemaining = creature.attack.cooldown
end

return melee
