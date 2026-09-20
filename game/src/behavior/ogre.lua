local chase = require("behavior.chase")
local idle = require("behavior.idle")
---@type CreatureMovementBehavior
local ogre = {}
local walkDuration, restDuration = 2, 1

local function walkingTime(time)
  local cycle = walkDuration + restDuration
  return math.floor(time / cycle) * walkDuration + math.min(time % cycle, walkDuration)
end

---@param creature Creature
---@param dt number
---@param context CreatureSystemContext
function ogre.update(creature, dt, context)
  if dt <= 0 or not context.knight then return idle.update(creature, dt, context) end
  local before = creature.pursuitTime or 0
  creature.pursuitTime = before + dt
  -- Integrate only the walking portions, even when a frame crosses a rest boundary.
  local movingDt = walkingTime(creature.pursuitTime) - walkingTime(before)
  if movingDt <= 0 then return idle.update(creature, dt, context) end
  chase.update(creature, movingDt, context)
  creature.velocity = creature.velocity * (movingDt / dt)
end

return ogre
