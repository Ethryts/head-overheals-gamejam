local Gamestate = require("gamestate.deps").Gamestate
local HC = require("lib.HC")
local anim8 = require("lib.anim8")

-- Keep rendering resources separate from the shared item data.
---@type table<Item, { image: love.Image, animation: Anim8Animation }>
local visuals = {}
local rarityColors = {
  common = {0.8, 0.85, 0.9},
  uncommon = {0.35, 1, 0.55},
  rare = {0.65, 0.45, 1},
}
local expiryWarning = 5

---@param item Item
local function createAnimation(item)
  if not visuals[item] then
    local image = love.graphics.newImage(item.imagePath)
    image:setFilter("nearest", "nearest")
    local grid = anim8.newGrid(16, 16, image:getWidth(), image:getHeight())
    visuals[item] = {
      image = image,
      animation = anim8.newAnimation(grid(item.frames or "1-1", 1), item.frameDuration or 0.2),
    }
  end
  return visuals[item].image, visuals[item].animation:clone()
end

---@class Pickup
---@field item Item Shared item data and hooks.
---@field type string Item ID.
---@field shape HCShape
---@field x number World-space center.
---@field y number
---@field lifetime number Seconds remaining before removal.
---@field image love.Image
---@field animation Anim8Animation Independent animation playback.
---@field scale number
---@field removed boolean Prevents duplicate collection and cleanup.
---@field age number Animation time, advanced only by update.
---@field phase number Position-based visual offset so pickups do not hover in sync.
local Pickup = {}
Pickup.__index = Pickup

---@param item Item
---@param x number
---@param y number
---@param lifetime number
---@param scale number
---@return Pickup
function Pickup.new(item, x, y, lifetime, scale)
  local image, animation = createAnimation(item)
  local shape = HC.circle(x, y, 4 * scale)
  shape.isPickup = true
  return setmetatable({ item = item, type = item.id, x = x, y = y,
    lifetime = lifetime, scale = scale, image = image, animation = animation,
    shape = shape, removed = false, age = 0,
    phase = (x * 0.73 + y * 0.37) % (math.pi * 2) }, Pickup)
end

---@param context PickupContext
---@return boolean collected
function Pickup:collect(context)
  if self.removed then return false end
  self:destroy()
  self.item.onCollect(self, context)
  if context.game and context.game.fx then
    context.game.fx:emit("pickup", self.x, self.y, {color = self.item.color})
  end
	Gamestate.soundEffectsSystem:playSoundEffect(self.item.soundEffectName, true)
  return true
end

---@param dt number
function Pickup:update(dt)
  if self.removed then return end
  self.age = self.age + dt
  self.lifetime = self.lifetime - dt
  if self.lifetime <= 0 then self:destroy() else self.animation:update(dt) end
end

function Pickup:isVisible()
  if self.removed or self.lifetime <= 0 then return false end
  if self.lifetime > expiryWarning then return true end
  local elapsed = expiryWarning - self.lifetime
  -- Brief dips at 0.5–2 flashes/second; offset nearby items to avoid mass blinking.
  local cycles = 0.5 * elapsed + 0.15 * elapsed * elapsed + self.phase / (math.pi * 2)
  return cycles % 1 < 0.85
end

function Pickup:draw()
  if not self:isVisible() then return end
  local scale = self.scale
  local time = self.age * 2.5 + self.phase
  local x = self.x
  local y = self.y - scale * (2 + math.sin(time) * 1.5)
  local color = self.item.color or rarityColors[self.item.rarity] or rarityColors.common
  love.graphics.push("all")
  -- Small stepped halos and two pixel sparkles; no emitters or per-frame allocations.
  local pulse = 0.85 + 0.15 * math.sin(time)
  for layer = 2, 1, -1 do
    local radius = scale * (5 + layer * 2)
    love.graphics.setColor(color[1], color[2], color[3], (layer == 2 and 0.1 or 0.18) * pulse)
    love.graphics.polygon("fill", x, y-radius, x+radius, y, x, y+radius, x-radius, y)
  end
  for i = 1, 2 do
    local phase = (self.age * 0.7 + self.phase + i * 0.5) % 1
    local sx = x + (i == 1 and -7 or 7) * scale
    local sy = y + (4 - phase * 10) * scale
    local brightness = math.sin(phase * math.pi)
    love.graphics.setColor(color[1], color[2], color[3], brightness * 0.8)
    love.graphics.rectangle("fill", sx-scale/2, sy-scale/2, scale, scale)
    if brightness > 0.85 then
      love.graphics.rectangle("fill", sx-scale*1.5, sy-scale/2, scale*3, scale)
      love.graphics.rectangle("fill", sx-scale/2, sy-scale*1.5, scale, scale*3)
    end
  end
  love.graphics.setColor(1, 1, 1, 1)
  self.animation:draw(self.image, x, y, 0, scale, scale, 8, 8)
  love.graphics.pop()
end

function Pickup:destroy()
  if self.removed then return end
  self.removed = true
  HC.remove(self.shape)
end

return Pickup
