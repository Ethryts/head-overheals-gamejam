---@class ActorStats
---@field speed number Movement speed in world pixels per second.
---@field maxHealth number Max health; can be overhealed to 2x
local Stats = {}

---@param speed number
---@param maxHealth number
---@param healSpeed number
---@return ActorStats
function Stats.new(speed, maxHealth, healSpeed)
  return { speed = speed, maxHealth = maxHealth, healSpeed = healSpeed or 0 }
end

return Stats
