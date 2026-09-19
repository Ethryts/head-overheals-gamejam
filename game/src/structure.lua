local HC = require("lib.HC")

---@class MapStructure
---@field x number World-space position.
---@field y number
---@field shape? table Optional HC shape owned by this structure.
local Structure = {}
Structure.__index = Structure

-- Minimal base for pillars, pots, etc. A concrete structure supplies its own
-- draw method and creates an HC shape when it needs collision.
function Structure.new(x, y)
  return setmetatable({ x = x, y = y }, Structure)
end

function Structure:draw()
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
    HC.remove(self.shape)
    self.shape = nil
  end
end

return Structure
