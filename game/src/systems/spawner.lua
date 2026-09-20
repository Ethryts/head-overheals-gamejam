local behavior = require("behavior")
local groups = require("spawns")
local project = require("project")

---@class SpawnerOptions
---@field interval? number Seconds between spawns. Defaults to 2.
---@field margin? number How far outside the screen edge to spawn. Defaults to 40.
---@field pool? { id: string, weight?: number }[] Creature IDs to pick from, with optional weights.
---@field speed? number Creature speed. Defaults to 60.
---@field scale? number Creature draw scale. Defaults to 2.
---@field difficulty? DifficultyStage[] Optional schedule; overrides interval and pool.
---@field endless? EndlessDifficulty Optional escalation after timed stages.
---@field maxActiveCreatures? integer Overrides the population ceiling; defaults to 150.

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
---@field endless? EndlessDifficulty
---@field baseInterval number Current stage interval before endless scaling.
---@field endlessStep integer
---@field hordeWeightMultiplier number
---@field maxActiveCreatures integer
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

    self.endless = options.endless
    self.baseInterval = self.interval
    self.endlessStep, self.hordeWeightMultiplier = 0, 1
    self.maxActiveCreatures = options.maxActiveCreatures
        or (self.endless and self.endless.maxActiveCreatures) or 150
    assert(self.maxActiveCreatures > 0 and self.maxActiveCreatures % 1 == 0, "Invalid creature cap")
    if self.endless then
        local e = self.endless
        assert(e.start >= 0 and e.stepEvery > 0 and e.minInterval > 0, "Invalid endless timing")
        assert(e.intervalMultiplier > 0 and e.intervalMultiplier <= 1, "Invalid interval multiplier")
        assert(e.hordeWeightGrowth >= 0 and e.maxHordeWeightMultiplier >= 1, "Invalid swarm growth")
    end
    self.timer = self.interval
    self.enabled = true

    return self
end

---@param enabled boolean
function Spawner:setEnabled(enabled)
    self.enabled = enabled
end

local function effectiveWeight(self, entry)
    return (entry.weight or 1) * (groups[entry.id] and self.hordeWeightMultiplier or 1)
end

local function pickFromPool(self)
    local pool = self.pool
    local totalWeight = 0
    for _, entry in ipairs(pool) do
        totalWeight = totalWeight + effectiveWeight(self, entry)
    end

    local roll = math.random() * totalWeight
    for _, entry in ipairs(pool) do
        roll = roll - effectiveWeight(self, entry)
        if roll <= 0 then
            return entry.id
        end
    end
    return pool[#pool].id -- fallback, shouldn't hit
end

-- Picks a point just outside one of the four screen edges.
local function randomOffscreenPoint(centerX, centerY, margin)
    local width, height = project.width, project.height
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

---@param id string Creature ID.
---@param x number
---@param y number
---@return Creature? Nil if the population limit is reached.
function Spawner:spawnAt(id, x, y)
    if #self.creatureSystem:getAll() >= self.maxActiveCreatures then return nil end

    -- Specialized creatures own their movement and stat defaults.
    if id == "brawny_ogre" or id == "ocular_watcher" or id == "humongous_ettin" then
        return self.creatureSystem:create(id, x, y)
    end

    return self.creatureSystem:create(id, x, y, {
        movementBehavior = id == "bloodshot_eye" and behavior.ranged or behavior.chase,
        speed = self.speed,
        scale = self.scale,
    })
end

---@param group SpawnGroup
---@param anchorX number Player's world position.
---@param anchorY number
---@return Creature? first First spawned member.
---@return integer count Number actually spawned, limited by available capacity.
function Spawner:spawnGroup(group, anchorX, anchorY)
    local total = 0
    for _, member in ipairs(group.members) do total = total + member.count end
    local columns = math.ceil(math.sqrt(total))
    local rows = math.ceil(total / columns)
    local halfWidth = (columns - 1) * group.spacing / 2
    local halfHeight = (rows - 1) * group.spacing / 2
    -- Move the whole formation outside the logical viewport, including sprite edges.
    local x, y = randomOffscreenPoint(anchorX, anchorY,
        self.margin + math.max(halfWidth, halfHeight) + 32)
    local index, first = 0, nil
    for _, member in ipairs(group.members) do
        for _ = 1, member.count do
            local creature = self:spawnAt(member.id,
                x + (index % columns) * group.spacing - halfWidth,
                y + math.floor(index / columns) * group.spacing - halfHeight)
            if not creature then return first, index end
            first = first or creature
            index = index + 1
        end
    end
    return first, index
end

-- One spawn event can resolve to a single creature or a complete swarm.
---@return Creature? first First spawned creature, retaining the single-spawn API.
---@return integer count
function Spawner:spawnOne(anchorX, anchorY)
    if #self.creatureSystem:getAll() >= self.maxActiveCreatures then return nil, 0 end
    local id = pickFromPool(self)
    if groups[id] then return self:spawnGroup(groups[id], anchorX, anchorY) end
    local x, y = randomOffscreenPoint(anchorX, anchorY, self.margin)
    local creature = self:spawnAt(id, x, y)
    return creature, creature and 1 or 0
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
            self.baseInterval = stage.interval
        end
    end
    if self.endless then
        local e = self.endless
        self.endlessStep = math.max(0, math.floor((self.elapsed - e.start) / e.stepEvery))
        self.interval = math.max(e.minInterval, self.baseInterval * e.intervalMultiplier ^ self.endlessStep)
        self.hordeWeightMultiplier = math.min(e.maxHordeWeightMultiplier, 1 + self.endlessStep * e.hordeWeightGrowth)
    end
    -- Keep the pending spawn; the new interval applies after it fires.
    self.timer = self.timer - dt
    if self.timer <= 0 then
        self:spawnOne(anchorX, anchorY)
        self.timer = self.interval
    end
end

return Spawner
