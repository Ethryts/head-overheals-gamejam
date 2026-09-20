local anim8 = require("lib.anim8")

---@class PlayerAnimationOptions
---@field bodyScale? number Defaults to 1.
---@field headScale? number Defaults to bodyScale; independent after construction.
---@field frameDuration? number Seconds per frame; defaults to 0.2.

---@class PlayerAnimationLayer
---@field image love.Image
---@field animation Anim8Animation

---@class PlayerAnimation
---@field body PlayerAnimationLayer
---@field head PlayerAnimationLayer
---@field bodyScale number
---@field headScale number
---@field headVisible? boolean False hides only the head, such as during an explosion.
local PlayerAnimation = {}
PlayerAnimation.__index = PlayerAnimation

local function loadLayer(path, duration)
  local image = love.graphics.newImage(path)
  image:setFilter("nearest", "nearest")
  local grid = anim8.newGrid(16, 16, image:getWidth(), image:getHeight())
  return { image = image, animation = anim8.newAnimation(grid("1-4", 1), duration) }
end

---@param directory string Folder containing body_idle.png and head_idle.png.
---@param options? PlayerAnimationOptions
---@return PlayerAnimation
function PlayerAnimation.new(directory, options)
  options = options or {}
  local duration = options.frameDuration or 0.2
  return setmetatable({
    body = loadLayer(directory .. "/body_idle.png", duration),
    head = loadLayer(directory .. "/head_idle.png", duration),
    bodyScale = options.bodyScale or 1,
    headScale = options.headScale or options.bodyScale or 1,
  }, PlayerAnimation)
end

---@param dt number
function PlayerAnimation:update(dt)
  self.body.animation:update(dt)
  self.head.animation:update(dt)
end

local function drawLayer(layer, x, y, direction, scale)
  -- Both sheets share a frame-center anchor, near the base of the head.
  -- Scaling the head therefore keeps its attachment fixed.
  local width, height = layer.animation:getDimensions()
  layer.animation:draw(layer.image, x, y, 0, direction * scale, scale,
    width / 2, height / 2)
end

---@param y number
---@return number World-space foot position for depth sorting, independent of head scale.
function PlayerAnimation:getFeetY(y)
  local _, height = self.body.animation:getDimensions()
  return y + height / 2 * self.bodyScale
end

---@param x number
---@param y number
---@param direction? number 1 for right, -1 for left; defaults to right.
---@param headOffsetX? number Visual-only head displacement in world pixels.
---@param headOffsetY? number
function PlayerAnimation:draw(x, y, direction, headOffsetX, headOffsetY)
  direction = direction or 1
  love.graphics.push("all")
  love.graphics.setColor(1, 1, 1, 1)
  drawLayer(self.body, x, y, direction, self.bodyScale)
  if self.headVisible ~= false then
    drawLayer(self.head, x + (headOffsetX or 0), y + (headOffsetY or 0), direction, self.headScale)
  end
  love.graphics.pop()
end

return PlayerAnimation
