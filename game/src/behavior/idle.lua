---@type CreatureMovementBehavior
local idle = {}

---@param creature Creature
---@param dt number
---@param context CreatureSystemContext
function idle.update(creature, dt, context)
  creature.velocity.x = 0
  creature.velocity.y = 0
end

return idle
