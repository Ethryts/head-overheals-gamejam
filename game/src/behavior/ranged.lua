local idle = require("behavior.idle")

---@type CreatureMovementBehavior
local ranged = {}

---@param creature Creature
---@param dt number
---@param context CreatureSystemContext
function ranged.update(creature, dt, context)
  local knight = context.knight
  if not knight or dt <= 0 then
    return idle.update(creature, dt, context)
  end

  local offset = knight.position - creature.position
  local distance = offset:len()
  if distance == 0 then
    return idle.update(creature, dt, context)
  end

  -- Approach firing range, then hold position without retreating.
  local stopDistance = creature.attack and creature.attack.range or 300
  local speed = math.min(math.max(0, creature.speed), math.max(0, distance - stopDistance) / dt)
  creature.velocity = offset:normalized() * speed
end

return ranged
