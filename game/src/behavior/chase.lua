local idle = require("behavior.idle")

---@type CreatureBehavior
local chase = {}

---@param creature Creature
---@param dt number
---@param context CreatureSystemContext
function chase.update(creature, dt, context)
  local knight = context.knight
  if not knight or dt <= 0 then
    return idle.update(creature, dt, context)
  end

  local offset = knight.position - creature.position
  local distance = offset:len()
  if distance == 0 then
    return idle.update(creature, dt, context)
  end

  -- Stop at the knight's position rather than overshooting on a long frame.
  local speed = math.min(math.max(0, creature.speed), distance / dt)
  creature.velocity = offset:normalized() * speed
end

return chase
