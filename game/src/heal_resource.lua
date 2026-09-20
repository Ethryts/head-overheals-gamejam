local Stats = require("src.stats")

local HealResource = {}
HealResource.__index = HealResource

function HealResource.new(maxCharge, regenRate)
    return setmetatable({
        stats = Stats.new(nil, maxCharge or 100, nil),
        regenRate = regenRate or 0,
        current = 0,
    }, HealResource)
end

--@param dt number Elapsed seconds.
function HealResource:update(dt, isDraining)
  if not isDraining and self.regenRate > 0 then
    self:add(self.regenRate * dt)
  end
end


function HealResource:add(amount)
    self.current = math.max(0, math.min(self.stats.maxHealth, self.current + amount))
end

-- Spends up to `amount`; returns how much was actually available/spent,
-- so callers only apply the heal they actually paid for.
function HealResource:spend(amount)
    local spent = math.min(self.current, amount)
    self.current = self.current - spent
    return spent
end

function HealResource:getRatio()
    return self.current / self.stats.maxHealth
end

function HealResource:isEmpty()
    return self.current <= 0
end

return HealResource
