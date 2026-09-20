local behavior = require("behavior")

---@class SpawnerOptions
---@field interval? number Seconds between spawns. Defaults to 2.
---@field margin? number How far outside the screen edge to spawn. Defaults to 40.
---@field pool? { id: string, weight?: number }[] Creature IDs to pick from, with optional weights.
---@field speed? number Creature speed. Defaults to 60.
---@field scale? number Creature draw scale. Defaults to 2.
---@field difficulty? DifficultyStage[] Optional schedule; overrides interval and pool.

---@class Spawner
---@field creatureSystem CreatureSystem
---@field interval number Seconds between spawns.
---@field margin number Distance beyond the screen edge in pixels.
---@field pool { id: string, weight?: number }[]
---@field speed number Spawned creature speed.
---@field scale number Spawned creature draw scale.
---@field timer number Seconds until the next spawn.
---@field enabled boolean
---@field difficulty? DifficultyStage[]
---@field elapsed number Active spawning time in seconds.
---@field stage integer Current difficulty stage; zero without a schedule.
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

    self.difficulty = options.difficulty
    self.elapsed, self.stage = 0, 0
    if self.difficulty then
        assert(#self.difficulty > 0 and self.difficulty[1].at == 0,
            "Difficulty must start with a stage at zero")
        for i, stage in ipairs(self.difficulty) do
            assert(stage.interval > 0 and #stage.pool > 0, "Difficulty needs a positive interval and a creature pool")
            assert(i == 1 or stage.at > self.difficulty[i - 1].at, "Difficulty stages must be ordered")
            for _, entry in ipairs(stage.pool) do
                assert(entry.weight > 0, "Difficulty weights must be positive")
            end
        end
        self.stage = 1
        self.interval, self.pool = self.difficulty[1].interval, self.difficulty[1].pool
    end

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
local function randomOffscreenPoint(centerX, centerY, margin)
    local width, height = love.graphics.getDimensions()
    local halfW, halfH = width / 2, height / 2
    local edge = math.random(4)
    local offsetW = math.random(-math.floor(halfW), math.floor(halfW))
    local offsetH = math.random(-math.floor(halfH), math.floor(halfH))
    
    if edge == 1 then
        return centerX + offsetW, centerY - halfH - margin
    elseif edge == 2 then
        return centerX + offsetW, centerY + halfH + margin
    elseif edge == 3 then
        return centerX - halfW - margin, centerY + offsetH
    else
        return centerX + halfW + margin, centerY + offsetH
    end
end

---@return Creature
function Spawner:spawnOne(anchorX, anchorY)
    local id = pickFromPool(self.pool)
    local x, y = randomOffscreenPoint(anchorX, anchorY, self.margin)

    -- Ogres use their own size, speed and movement cycle rather than mob defaults.
    if id == "brawny_ogre" then return self.creatureSystem:create(id, x, y) end

    return self.creatureSystem:create(id, x, y, {
        movementBehavior = id == "bloodshot_eye" and behavior.ranged or behavior.chase,
        speed = self.speed,
        scale = self.scale,
    })
end

---@param dt number Elapsed seconds.
function Spawner:update(dt, anchorX, anchorY)
    if not self.enabled then return end

    self.elapsed = self.elapsed + dt
    if self.difficulty then
        while self.difficulty[self.stage + 1] and self.elapsed >= self.difficulty[self.stage + 1].at do
            self.stage = self.stage + 1
            local stage = self.difficulty[self.stage]
            self.interval, self.pool = stage.interval, stage.pool
        end
    end
    -- Keep the pending spawn; the new interval applies after it fires.
    self.timer = self.timer - dt
    if self.timer <= 0 then
        self:spawnOne(anchorX, anchorY)
        self.timer = self.interval
    end
end

return Spawner
