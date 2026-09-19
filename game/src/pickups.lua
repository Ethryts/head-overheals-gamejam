local HC = require("lib.HC")

local Pickups = {}
Pickups.__index = Pickups

local RADIUS = 8

function Pickups.new(mapWidth, mapHeight)
    local self = setmetatable({}, Pickups)
    self.mapWidth = mapWidth
    self.mapHeight = mapHeight
    self.items = {} -- list of { shape = ..., x = ..., y = ... }
    return self
end

function Pickups:spawn(count, margin)
    margin = margin or 40
    for i = 1, count do
        local x = math.random(margin, self.mapWidth - margin)
        local y = math.random(margin, self.mapHeight - margin)

        local shape = HC.circle(x, y, RADIUS)
        shape.isPickup = true -- tag so we can identify it in collision checks

        table.insert(self.items, { shape = shape, x = x, y = y })
    end
end

function Pickups:checkCollected(playerShape)
    for i = #self.items, 1, -1 do
        local item = self.items[i]
        if playerShape:collidesWith(item.shape) then
            table.remove(self.items, i)
            self:onCollect(item)
        end
    end
end

function Pickups:onCollect(item)
    print("[pickup] collected at", item.x, item.y)
    -- hook your score/inventory logic here
end

function Pickups:draw()
    love.graphics.setColor(1, 0.85, 0.2)
    for _, item in ipairs(self.items) do
        love.graphics.circle("fill", item.x, item.y, RADIUS)
    end
end

return Pickups
