local vector = require("lib.hump.vector")
local Gamestate = require("gamestate.deps").Gamestate

---@class Kick
---@field cooldownRemaining number
---@field effectRemaining number
---@field origin HumpVector
---@field direction HumpVector
local Kick = {}
Kick.__index = Kick

-- Experimental balance values, in world pixels and seconds.
Kick.tuning = {
  range = 80,
  arc = math.pi / 2,
  distance = 180,
  duration = 0.25,
  cooldown = 0.65,
  effectDuration = 0.2,
}

function Kick.new()
  return setmetatable({
    cooldownRemaining = 0,
    effectRemaining = 0,
    origin = vector(0, 0),
    direction = vector(1, 0),
  }, Kick)
end

function Kick:update(dt)
  self.cooldownRemaining = math.max(0, self.cooldownRemaining - dt)
  self.effectRemaining = math.max(0, self.effectRemaining - dt)
end

---@param creatures CreatureSystem
---@param projectiles? ProjectileSystem Shots in the kick arc are destroyed on activation.
---@return boolean activated
function Kick:tryActivate(x, y, direction, creatures, projectiles)
  if self.cooldownRemaining > 0 or direction:len() == 0 then return false end
  local tuning = Kick.tuning
  self.origin = vector(x, y)
  self.direction = direction:normalized()
  self.cooldownRemaining = tuning.cooldown
  self.effectRemaining = tuning.effectDuration
  local threshold = math.cos(tuning.arc / 2)
  local function inArc(position)
    local offset = position - self.origin
    local distance = offset:len()
    local dot = offset.x * self.direction.x + offset.y * self.direction.y
    return distance <= tuning.range and (distance == 0 or dot / distance >= threshold - 1e-9)
  end
  for _, creature in ipairs(creatures:getAll()) do
    if inArc(creature.position) then
      creatures:applyKnockback(creature, self.direction, tuning.distance, tuning.duration)
    end
  end
  if projectiles then
    projectiles:removeWhere(function(shot) return inArc(shot.position) end)
  end
  return true
end

function Kick:draw()
  if self.effectRemaining <= 0 then return end
  local progress = 1 - self.effectRemaining / Kick.tuning.effectDuration
  local extension = math.sin(progress * math.pi)
  love.graphics.push("all")
  love.graphics.translate(self.origin.x, self.origin.y)
  love.graphics.rotate(math.atan2(self.direction.y, self.direction.x))
  love.graphics.setColor(0.75, 1, 0.7, 1 - progress)
  love.graphics.setLineWidth(3)
  love.graphics.arc("line", "open", 0, 0, 32 + progress * (Kick.tuning.range - 32),
    -Kick.tuning.arc / 2, Kick.tuning.arc / 2, 20)
  -- A short leg and boot thrust; no new sprite sheet is required.
  love.graphics.setColor(0.85, 0.85, 0.7, 1 - progress)
  love.graphics.rectangle("fill", 10, -5, 14 + extension * 24, 10)
  love.graphics.setColor(0.3, 0.2, 0.12, 1 - progress)
  local toe = 24 + extension * 24
  love.graphics.polygon("fill", toe, -9, toe + 14, -9, toe + 18, 9, toe, 9)
  love.graphics.pop()
end

function Kick:drawStatus(x, y)
  love.graphics.push("all")
  love.graphics.setColor(0.75, 1, 0.7, 1)
  local status = self.cooldownRemaining > 0
      and string.format("%.1fs", self.cooldownRemaining) or "Ready"
  love.graphics.print("Kick: LT / F  " .. status, x, y)
  love.graphics.setColor(0.2, 0.25, 0.2, 1)
  love.graphics.rectangle("fill", x, y + 24, 120, 4)
  love.graphics.setColor(0.75, 1, 0.7, 1)
  love.graphics.rectangle("fill", x, y + 24,
    120 * (1 - self.cooldownRemaining / Kick.tuning.cooldown), 4)
  love.graphics.pop()
end

return Kick
