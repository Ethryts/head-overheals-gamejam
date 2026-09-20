local project = require("project")
local Pickup = require("src.pickup")
local items = require("src.items")

---@class PickupsOptions
---@field intervalMin? number Minimum seconds between batches; defaults to 1.
---@field intervalMax? number Maximum seconds between batches; defaults to 3.
---@field batchSize? integer Pickups per batch; defaults to 2.
---@field maxItems? integer Maximum active pickups; defaults to 60.
---@field lifetime? number Seconds before despawn; defaults to 15.
---@field scale? number Sprite scale; defaults to 2.

---@class Pickups
---@field player Player Spawn positions are relative to this player.
---@field items Pickup[]
---@field nextSpawnTime number Seconds until the next batch spawns.
---@field intervalMin number
---@field intervalMax number
---@field batchSize integer
---@field maxItems integer
---@field lifetime number
---@field scale number
local Pickups = {}
Pickups.__index = Pickups

local function spawnDelay(self)
  return self.intervalMin + math.random() * (self.intervalMax - self.intervalMin)
end

---@param player Player
---@param options? PickupsOptions
---@return Pickups
function Pickups.new(player, options)
  options = options or {}
  local self = setmetatable({
    player = player, items = {},
    intervalMin = options.intervalMin or 1,
    intervalMax = options.intervalMax or 3,
    batchSize = options.batchSize or 2,
    maxItems = options.maxItems or 60,
    lifetime = options.lifetime or 15,
    scale = options.scale or 2,
  }, Pickups)
  assert(self.intervalMin > 0 and self.intervalMax >= self.intervalMin, "Invalid pickup spawn interval")
  assert(self.lifetime > 0 and self.scale > 0, "Pickup lifetime and scale must be positive")
  assert(self.batchSize >= 0 and self.batchSize % 1 == 0, "Invalid pickup batch size")
  assert(self.maxItems >= 0 and self.maxItems % 1 == 0, "Invalid pickup population limit")
  self.nextSpawnTime = spawnDelay(self)
  return self
end

---@param roll? number A number in [0, 1), or math.random() when omitted.
---@return Item
function Pickups:chooseItem(roll)
  roll = roll or math.random()
  assert(roll >= 0 and roll < 1, "Pickup roll must be in [0, 1)")
  local total = 0
  for _, item in ipairs(items) do
    assert(item.weight >= 0, "Item weight must be nonnegative: " .. item.id)
    total = total + item.weight
  end
  assert(total > 0, "At least one item must have a positive spawn weight")
  local remaining = roll * total
  local last
  for _, item in ipairs(items) do
    if item.weight > 0 then
      last = item
      remaining = remaining - item.weight
      if remaining < 0 then return item end
    end
  end
  return last -- Floating-point rounding at the upper boundary.
end

---@param item Item
---@param x number
---@param y number
---@return Pickup? pickup Nil when the population limit is reached.
function Pickups:create(item, x, y)
  if #self.items >= self.maxItems then return nil end
  local pickup = Pickup.new(item, x, y, self.lifetime, self.scale)
  self.items[#self.items + 1] = pickup
  return pickup
end

---@param count integer
---@param margin? number Half-size of the spawn area in world pixels.
---@param item? Item Fixed item; otherwise chosen by spawn weight.
function Pickups:spawn(count, margin, item)
  local marginX = margin or project.width * 1.25 / 2
  local marginY = margin or project.height * 1.25 / 2
  for _ = 1, math.min(count, self.maxItems - #self.items) do
    local x = self.player.x + (math.random() * 2 - 1) * marginX
    local y = self.player.y + (math.random() * 2 - 1) * marginY
    self:create(item or self:chooseItem(), x, y)
  end
end

---@param player Player The healer collecting pickups.
---@param knight? Knight Available to ability effects.
---@param game? GameState Available to game-wide item effects.
function Pickups:checkCollected(player, knight, game)
  if not player.shape then return end
  ---@type PickupContext
  local context = { player = player, knight = knight, game = game }
  for i = #self.items, 1, -1 do
    local item = self.items[i]
    if not item.removed and player.shape:collidesWith(item.shape) then
      table.remove(self.items, i)
      self:onCollect(item, context)
    end
  end
end

---@param dt number Elapsed seconds.
function Pickups:update(dt)
  for i = #self.items, 1, -1 do
    local item = self.items[i]
    item:update(dt)
    if item.removed then table.remove(self.items, i) end
  end

  self.nextSpawnTime = self.nextSpawnTime - dt
  if self.nextSpawnTime <= 0 then
    self:spawn(self.batchSize)
    -- At most one batch per update, avoiding bursts after a long frame.
    self.nextSpawnTime = spawnDelay(self)
  end
end

---@param item Pickup
---@param context PickupContext
function Pickups:onCollect(item, context)
  return item:collect(context)
end

function Pickups:draw()
  love.graphics.push("all")
  love.graphics.setColor(1, 1, 1, 1)
  for _, item in ipairs(self.items) do item:draw() end
  love.graphics.pop()
end

function Pickups:destroy()
  for _, item in ipairs(self.items) do item:destroy() end
  self.items = {}
end

return Pickups
