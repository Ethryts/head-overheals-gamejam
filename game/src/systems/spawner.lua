local behavior = require("behavior")

---@class SpawnerOptions
---@field interval? number Seconds between spawns. Defaults to 2.
---@field margin? number How far outside the screen edge to spawn. Defaults to 40.
---@field pool? { id: string, weight?: number }[] Creature IDs to pick from, with optional weights.
---@field speed? number Creature speed. Defaults to 60.
---@field scale? number Creature draw scale. Defaults to 2.

---@class Spawner
---@field creatureSystem CreatureSystem
---@field interval number Seconds between spawns.
---@field margin number Distance beyond the screen edge in pixels.
---@field pool { id: string, weight?: number }[]
---@field speed number Spawned creature speed.
---@field scale number Spawned creature draw scale.
---@field timer number Seconds until the next spawn.
---@field enabled boolean
local Spawner = {}
Spawner.__index = Spawner

local DEFAULT_POOL = {
    { id = "death_slime" },
    { id = "bloodshot_eye" },
    { id = "ochre_jelly" },
}

---@param creatureSystem CreatureSystem
---@param options? SpawnerOptions
---@return Spawner
function Spawner.new(creatureSystem, options)
    options = options or {}
    local self = setmetatable({}, Spawner)

    self.creatureSystem = creatureSystem
    self.interval = options.interval or 2
    self.margin = options.margin or 40
    self.pool = options.pool or DEFAULT_POOL
    self.speed = options.speed or 60
    self.scale = options.scale or 2

    self.timer = self.interval
    self.enabled = true

    return self
end

---@param enabled boolean
function Spawner:setEnabled(enabled)
    self.enabled = enabled
end

local function pickFromPool(pool)
    local totalWeight = 0
    for _, entry in ipairs(pool) do
        totalWeight = totalWeight + (entry.weight or 1)
    end

    local roll = math.random() * totalWeight
    for _, entry in ipairs(pool) do
        roll = roll - (entry.weight or 1)
        if roll <= 0 then
            return entry.id
        end
    end
    return pool[#pool].id -- fallback, shouldn't hit
end

-- Picks a point just outside one of the four screen edges.
local function randomOffscreenPoint(margin)
    local width, height = love.graphics.getDimensions()
    local edge = math.random(4)

    if edge == 1 then -- top
        return math.random(0, width), -margin
    elseif edge == 2 then -- bottom
        return math.random(0, width), height + margin
    elseif edge == 3 then -- left
        return -margin, math.random(0, height)
    else -- right
        return width + margin, math.random(0, height)
    end
end

---@return Creature
function Spawner:spawnOne()
    local id = pickFromPool(self.pool)
    local x, y = randomOffscreenPoint(self.margin)

    return self.creatureSystem:create(id, x, y, {
        behavior = behavior.chase,
        speed = self.speed,
        scale = self.scale,
    })
end

---@param dt number Elapsed seconds.
function Spawner:update(dt)
    if not self.enabled then return end

    self.timer = self.timer - dt
    if self.timer <= 0 then
        self:spawnOne()
        self.timer = self.interval
    end
end

return Spawner
