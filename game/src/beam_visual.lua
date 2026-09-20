-- Fixed-size visual geometry. No particles or random-number calls per frame.
local Visual = {}
Visual.__index = Visual
local SEGMENTS, SPARKLES = 20, 8

function Visual.new()
  local self = setmetatable({time = 0, vertices = {}, center = {}, cracks = {{}, {}}, sparkles = {}}, Visual)
  for i = 1, (SEGMENTS + 1) * 2 do self.vertices[i] = {0, 0, 0, 0, 0.1, 0.7, 0.4, 0.8} end
  for i = 1, SPARKLES do self.sparkles[i] = {} end
  return self
end

local function point(x0, y0, x1, y1, x2, y2, t, path)
  if path then
    local step = t * (#path - 1)
    local index = math.min(math.floor(step) + 1, #path - 1)
    local first, last = path[index], path[index + 1]
    local fraction = step - index + 1
    return first.x + (last.x-first.x)*fraction, first.y + (last.y-first.y)*fraction,
      last.x-first.x, last.y-first.y
  end
  local u = 1 - t
  return u*u*x0 + 2*u*t*x1 + t*t*x2, u*u*y0 + 2*u*t*y1 + t*t*y2,
    u*(x1-x0) + t*(x2-x1), u*(y1-y0) + t*(y2-y1)
end

function Visual:update(beam, dt)
  self.time = self.time + dt
  self.tipX = nil
  if not beam.isVisible or beam.length <= 0 then return end
  local path = beam.points
  if path and #path < 2 then return end
  local x0, y0, x2, y2 = beam.bottomLeft.x, beam.bottomLeft.y, beam.tip.x, beam.tip.y
  local dx, dy = x2-x0, y2-y0
  local length = math.sqrt(dx*dx + dy*dy)
  if length == 0 then return end
  local nx, ny = -dy/length, dx/length
  local x1, y1 = (x0+x2)/2 + nx*beam.bend, (y0+y2)/2 + ny*beam.bend
  local flicker = math.floor(self.time * 18)
  self.pulse = 0.5 + 0.5 * math.sin(self.time * 24)
  self.strength = math.min(1, beam.length / 24)
  for i = 0, SEGMENTS do
    local t = i / SEGMENTS
    local x, y, tangentX, tangentY = point(x0,y0,x1,y1,x2,y2,t,path)
    local tangentLength = math.sqrt(tangentX*tangentX + tangentY*tangentY)
    local normalX, normalY = nx, ny
    if tangentLength > 0 then normalX, normalY = -tangentY/tangentLength, tangentX/tangentLength end
    local width = beam.width * (0.45 + 0.08*math.sin(self.time*19 - t*14))
    local left, right = self.vertices[i*2+1], self.vertices[i*2+2]
    left[1],left[2] = x+normalX*width, y+normalY*width
    right[1],right[2] = x-normalX*width, y-normalY*width
    left[8],right[8] = 0.8*self.strength, 0.8*self.strength
    self.center[i*2+1],self.center[i*2+2] = x,y
    for strand = 1, 2 do
      -- Coarse flicker changes only at 18 Hz; points track the live curve every update.
      local noise = math.sin((i+1)*19.17 + flicker*12.31 + strand*47.7)
      local envelope = math.sin(t*math.pi)
      local offset = (noise*beam.width*0.9 + (strand==1 and 2 or -2))*envelope
      self.cracks[strand][i*2+1] = x+normalX*offset
      self.cracks[strand][i*2+2] = y+normalY*offset
    end
  end
  for i, sparkle in ipairs(self.sparkles) do
    local phase = (self.time * (0.9 + i*0.03) + i/SPARKLES) % 1
    local t = (phase + i*0.173) % 1
    local x,y = point(x0,y0,x1,y1,x2,y2,t,path)
    local offset = math.sin(i*7.3 + flicker)*beam.width*0.95
    sparkle.x, sparkle.y = x+nx*offset, y+ny*offset
    sparkle.visible = phase < 0.65
    sparkle.size = phase < 0.2 and 4 or 2
  end
  self.tipX,self.tipY = point(x0,y0,x1,y1,x2,y2,1,path)
  self.dirty = true
end

function Visual:draw()
  if not self.tipX then return end
  if not self.mesh then self.mesh = love.graphics.newMesh(self.vertices, "strip", "dynamic") end
  if self.dirty then self.mesh:setVertices(self.vertices); self.dirty = false end
  love.graphics.push("all")
  love.graphics.setColor(1,1,1,1)
  love.graphics.draw(self.mesh)
  love.graphics.setLineStyle("rough")
  love.graphics.setLineJoin("bevel")
  love.graphics.setLineWidth(2)
  love.graphics.setColor(0.55,1,0.8,self.strength)
  love.graphics.line(self.center)
  love.graphics.setColor(0.15,0.95,0.6,0.9*self.strength)
  love.graphics.line(self.cracks[1])
  love.graphics.setColor(0.85,1,0.6,self.strength)
  love.graphics.line(self.cracks[2])
  love.graphics.setColor(0.9,1,0.85,self.strength)
  for _, sparkle in ipairs(self.sparkles) do
    if sparkle.visible then
      local x,y = math.floor(sparkle.x/2+0.5)*2, math.floor(sparkle.y/2+0.5)*2
      love.graphics.rectangle("fill",x-sparkle.size,y,2*sparkle.size+2,2)
      love.graphics.rectangle("fill",x,y-sparkle.size,2,2*sparkle.size+2)
    end
  end
  local tipSize = self.pulse > 0.65 and 4 or 2
  love.graphics.rectangle("fill",self.tipX-tipSize,self.tipY,tipSize*2+2,2)
  love.graphics.rectangle("fill",self.tipX,self.tipY-tipSize,2,tipSize*2+2)
  love.graphics.pop()
end

function Visual:destroy()
  if self.mesh then self.mesh:release(); self.mesh = nil end
end

return Visual
