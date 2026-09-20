-- Stable painter order shared by actors, pillars and airborne particles.
local DrawQueue = {}
DrawQueue.__index = DrawQueue

function DrawQueue.new()
  return setmetatable({entries = {}}, DrawQueue)
end

function DrawQueue:add(depth, draw)
  self.entries[#self.entries + 1] = {depth = depth, draw = draw, order = #self.entries + 1}
end

function DrawQueue:draw()
  table.sort(self.entries, function(a, b)
    if a.depth == b.depth then return a.order < b.order end
    return a.depth < b.depth
  end)
  love.graphics.push("all")
  for _, entry in ipairs(self.entries) do entry.draw() end
  love.graphics.pop()
end

return DrawQueue
