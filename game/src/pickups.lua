local HC = require("lib.HC")
local project = require("project")

---@class Pickup
---@field shape HCShape
---@field x number World-space horizontal position.
---@field y number World-space vertical position.
---@field lifetime number Seconds remaining before removal.

---@class Pickups
---@field player Player Spawn positions are relative to this player.
---@field items Pickup[]
---@field nextSpawnTime number Seconds until the next batch spawns.


local Pickups = {
  items = {}, -- list of { shape = ..., x = ..., y = ... }
  nextSpawnTime = 0,

}
Pickups.__index = Pickups

local RADIUS = 8

---@param player Player
---@return Pickups
function Pickups.new(player)
  local self = setmetatable({}, Pickups)

  self.player = player
  self.items = {} -- list of { shape = ..., x = ..., y = ... }
  return self
end

---@param count integer
---@param margin? number Half-size of the spawn area in world pixels.
function Pickups:spawn(count, margin)
  -- Use logical world dimensions: window scaling doesn't change the visible area.
  local marginX = margin or project.width * 1.25 / 2
  local marginY = margin or project.height * 1.25 / 2
  for i = 1, count do
    local x = self.player.x + (math.random() * 2 - 1) * marginX
    local y = self.player.y + (math.random() * 2 - 1) * marginY

    local shape = HC.circle(x, y, RADIUS)
    shape.isPickup = true -- tag so we can identify it in collision checks

    table.insert(self.items, {
      shape = shape,
      x = x,
      y = y,
      lifetime = 15
    })
  end
end

---@param playerShape HCShape
function Pickups:checkCollected(playerShape)
  for i = #self.items, 1, -1 do
    local item = self.items[i]
    if playerShape:collidesWith(item.shape) then
      table.remove(self.items, i)
      self:onCollect(item)
    end
  end
end

---@param dt number Elapsed seconds.
function Pickups:update(dt)
  for i = #self.items, 1, -1 do
    local item = self.items[i]
    item.lifetime = item.lifetime - dt
    if item.lifetime <= 0 then
      table.remove(self.items, i)
    end
  end

  if self.nextSpawnTime <= 0 then
    self:spawn(2)
    self.nextSpawnTime = math.random(1, 3)
  else
    self.nextSpawnTime = self.nextSpawnTime - dt
  end
end

---@param item Pickup
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
