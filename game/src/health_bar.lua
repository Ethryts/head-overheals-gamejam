---@class HealthBar
---@field style table
---@field overheal number Progress from normal max health to the overheal limit.
---@field time number Visual animation time, advanced only during updates.
---@field bursts integer
---@field shards {x: number, y: number, vx: number, vy: number, age: number, lifetime: number}[]
local HealthBar = {}
HealthBar.__index = HealthBar

local DEFAULT_STYLE = {
    width = 40,
    height = 6,
    offsetY = -30, -- drawn this far above the anchor point
    background = { 0.15, 0.15, 0.15, 0.8 },
    border = { 0, 0, 0, 1 },
    fill = { 0.3, 0.9, 0.3, 1 },
}

---@param style? table Override any of DEFAULT_STYLE's fields.
function HealthBar.new(style)
    local self = setmetatable({}, HealthBar)
    self.style = setmetatable(style or {}, { __index = DEFAULT_STYLE })
    self.overheal, self.time, self.bursts = 0, 0, 0
    self.shards = {}
    return self
end

-- Ratio through the extra-health range: 0 at normal max, 1 at fatal overheal.
---@param ratio number
function HealthBar:setOverheal(ratio)
    ratio = math.max(0, math.min(1, ratio))
    local function band(value)
        return value < 0.5 and 0 or math.floor((value - 0.5) * 20 + 1e-7) + 1
    end
    if band(ratio) > band(self.overheal) then
        self.bursts = self.bursts + 1
        -- Small bursts only when another 5% of the overheal range is filled.
        for i = 1, math.min(4, 24 - #self.shards) do
            local seed = self.bursts * 7 + i * 11
            self.shards[#self.shards + 1] = {
                x = 2 + seed % math.max(1, self.style.width - 4), y = 0,
                vx = (seed % 13 - 6) * 5, vy = -22 - seed % 23,
                age = 0, lifetime = 0.35 + (seed % 4) * 0.05,
            }
        end
    end
    self.overheal = ratio
end

---@param dt number
function HealthBar:update(dt)
    self.time = self.time + dt
    for i = #self.shards, 1, -1 do
        local shard = self.shards[i]
        shard.age = shard.age + dt
        if shard.age >= shard.lifetime then
            table.remove(self.shards, i)
        else
            shard.x = shard.x + shard.vx * dt
            shard.y = shard.y + shard.vy * dt + 80 * dt * dt
            shard.vy = shard.vy + 160 * dt
        end
    end
end

---@param healing boolean
---@return number x
---@return number y
function HealthBar:headShake(healing)
    if not healing or self.overheal < 0.5 then return 0, 0 end
    local strength = 1 + (self.overheal - 0.5) * 6
    return math.floor(math.sin(self.time * 73) * strength + 0.5),
        math.floor(math.cos(self.time * 97) * strength + 0.5)
end

---@param worldX number Anchor X (bar is centered on this).
---@param worldY number Anchor Y (bar is drawn offsetY above this).
---@param ratio number 0..1 fill amount.
---@param fillColorOverride? table {r,g,b,a} to override the style's fill color for this draw.
function HealthBar:draw(worldX, worldY, ratio, fillColorOverride)
    local s = self.style
    local x = worldX - s.width / 2
    local y = worldY + s.offsetY
    ratio = math.max(0, math.min(1, ratio))
    love.graphics.push("all")
    if self.overheal > 0 then
        local pulse = 0.75 + 0.25 * math.sin(self.time * 7)
        for edge = 4, 2, -2 do
            love.graphics.setColor(0.25, 1, 0.45, (0.08 + self.overheal * 0.12) * pulse)
            love.graphics.rectangle("fill", x-edge, y-edge, s.width+edge*2, s.height+edge*2)
        end
    end

    -- TODO(assets): once real art exists, replace these three rectangle calls
    -- with e.g. love.graphics.draw(s.backgroundImage, x, y) / a cropped quad
    -- for the fill / love.graphics.draw(s.borderImage, x, y). Callers never
    -- need to change — they only ever call :draw(worldX, worldY, ratio).
    love.graphics.setColor(s.background)
    love.graphics.rectangle("fill", x, y, s.width, s.height)

    love.graphics.setColor(fillColorOverride or s.fill)
    love.graphics.rectangle("fill", x, y, s.width * ratio, s.height)

    love.graphics.setColor(s.border)
    love.graphics.rectangle("line", x, y, s.width, s.height)
    if self.overheal >= 0.5 then
        local cracks = math.min(6, 1 + math.floor((self.overheal - 0.5) * 10))
        love.graphics.setLineStyle("rough")
        for i = 1, cracks do
            local cx = x + 4 + (i * 13) % math.max(1, s.width - 8)
            love.graphics.setLineWidth(2)
            love.graphics.setColor(0.03, 0.16, 0.1)
            love.graphics.line(cx, y, cx-2, y+s.height*0.4, cx+2, y+s.height*0.6, cx, y+s.height)
            love.graphics.setLineWidth(1)
            love.graphics.setColor(0.8, 1, 0.9, 0.8)
            love.graphics.line(cx+1, y, cx-1, y+s.height*0.4)
        end
    end
    for _, shard in ipairs(self.shards) do
        local sx, sy = x + math.floor(shard.x/2)*2, y + math.floor(shard.y/2)*2
        love.graphics.setColor(0.8, 1, 0.9, 1 - shard.age/shard.lifetime)
        love.graphics.polygon("fill", sx, sy, sx+4, sy+2, sx, sy+4)
    end
    love.graphics.pop()
end

return HealthBar
