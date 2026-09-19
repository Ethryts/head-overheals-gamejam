local images = {}
local definitions = {
  pillar_round = { width = 10, height = 8 },
  pillar_square = { width = 12, height = 9 },
  pillar_broken = { width = 10, height = 9 },
  pillar_wide = { width = 24, height = 12 },
}

---@class MapStructure
---@field kind string Pillar asset ID.
---@field x number World-space bottom-center anchor.
---@field y number
---@field shape? table Optional HC shape owned by this structure.
---@field scale number
---@field image love.Image
local Structure = {}
Structure.__index = Structure

---@param kind string
---@param x number
---@param y number
---@param scale number
---@param world table HC instance that owns this structure's collision shape.
---@return MapStructure
function Structure.new(kind, x, y, scale, world)
  local definition = assert(definitions[kind], "Unknown structure: " .. tostring(kind))
  local image = images[kind]
  if not image then
    image = love.graphics.newImage("assets/images/Tileset/" .. kind .. ".png")
    image:setFilter("nearest", "nearest")
    images[kind] = image
  end
  local width, height = definition.width * scale, definition.height * scale
  local structure = setmetatable({
    kind = kind, x = x, y = y, scale = scale, image = image, world = world,
    shape = world:rectangle(x - width / 2, y - height, width, height),
  }, Structure)
  structure.shape.structure = structure
  return structure
end

function Structure:draw()
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(self.image, self.x, self.y, 0, self.scale, self.scale,
    self.image:getWidth() / 2, self.image:getHeight())
end

---@param otherShape table HC shape to test against.
---@return boolean
function Structure:collidesWith(otherShape)
  if not self.shape then return false end
  return self.shape:collidesWith(otherShape)
end

-- Called when the owning chunk unloads; concrete types may extend cleanup.
function Structure:destroy()
  if self.shape then
    self.world:remove(self.shape)
    self.shape = nil
  end
end

return Structure
