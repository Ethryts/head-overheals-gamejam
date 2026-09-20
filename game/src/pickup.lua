local Gamestate = require("gamestate.deps").Gamestate
local HC = require("lib.HC")
local anim8 = require("lib.anim8")

-- Keep rendering resources separate from the shared item data.
---@type table<Item, { image: love.Image, animation: Anim8Animation }>
local visuals = {}

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
    shape = shape, removed = false }, Pickup)
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
  self.lifetime = self.lifetime - dt
  if self.lifetime <= 0 then self:destroy() else self.animation:update(dt) end
end

function Pickup:draw()
  if self.removed then return end
  self.animation:draw(self.image, self.x, self.y, 0, self.scale, self.scale, 8, 8)
end

function Pickup:destroy()
  if self.removed then return end
  self.removed = true
  HC.remove(self.shape)
end

return Pickup
