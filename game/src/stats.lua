---@class ActorStats
---@field speed number Movement speed in world pixels per second.
local Stats = {}

---@param speed number
---@return ActorStats
function Stats.new(speed)
  return { speed = speed }
end

return Stats
