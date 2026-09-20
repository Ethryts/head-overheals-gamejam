local project = require("project")

-- Two world pixels per canvas pixel preserves the smallest (2x) sprite scale.
-- The viewport still handles window scaling and input; UI remains outside this canvas.
---@class WorldCanvas
---@field canvas love.Canvas
local WorldCanvas = {}
WorldCanvas.__index = WorldCanvas

function WorldCanvas.new()
  local canvas = love.graphics.newCanvas(project.width / 2, project.height / 2)
  canvas:setFilter("nearest", "nearest")
  return setmetatable({canvas = canvas}, WorldCanvas)
end

---@param draw fun() Draw world-space content using the existing logical coordinates.
function WorldCanvas:draw(draw)
  local previous = love.graphics.getCanvas()
  love.graphics.push("all")
  love.graphics.setCanvas(self.canvas)
  love.graphics.origin()
  love.graphics.setScissor()
  love.graphics.clear(0.055, 0.075, 0.085, 1)
  love.graphics.scale(0.5)
  draw()
  love.graphics.setCanvas(previous)
  love.graphics.pop()
  love.graphics.push("all")
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.setBlendMode("alpha", "premultiplied")
  love.graphics.draw(self.canvas, 0, 0, 0, 2, 2)
  love.graphics.pop()
end

function WorldCanvas:destroy()
  self.canvas:release()
end

return WorldCanvas
