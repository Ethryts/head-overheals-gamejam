local Burst = {}
Burst.__index = Burst

-- Break the currently displayed head frame into sixteen reusable sprite fragments.
function Burst.new(layer, x, y, scale, direction, duration)
  local frame = layer.animation.frames[layer.animation.position]
  local fx, fy, width, height = frame:getViewport()
  local pieces = {}
  for row = 0, 3 do
    for col = 0, 3 do
      local ox, oy = (col+0.5)*width/4-width/2, (row+0.5)*height/4-height/2
      local length = math.sqrt(ox*ox+oy*oy)
      local speed = 80 + ((row*4+col)*17)%70
      pieces[#pieces+1] = {
        quad = love.graphics.newQuad(fx+col*width/4, fy+row*height/4, width/4, height/4,
          layer.image:getWidth(), layer.image:getHeight()),
        x = ox*scale*direction, y = oy*scale,
        vx = ox/length*speed*direction, vy = oy/length*speed-35,
        spin = ((row+col)%2 == 0 and 1 or -1)*4,
      }
    end
  end
  return setmetatable({image=layer.image, pieces=pieces, x=x, y=y,
    scale=scale, direction=direction, age=0, duration=duration, ox=width/8, oy=height/8}, Burst)
end

function Burst:update(dt)
  self.age = math.min(self.duration, self.age+dt)
end

function Burst:draw()
  local progress = self.age/self.duration
  if progress >= 1 then return end
  love.graphics.push("all")
  love.graphics.setColor(1, 1, 1, 1-progress)
  local scale = self.scale*(1-0.35*progress)
  for _, piece in ipairs(self.pieces) do
    local x = self.x+piece.x+piece.vx*self.age
    local y = self.y+piece.y+piece.vy*self.age+90*self.age*self.age
    love.graphics.draw(self.image, piece.quad, math.floor(x/2)*2, math.floor(y/2)*2,
      piece.spin*self.age, scale*self.direction, scale, self.ox, self.oy)
  end
  love.graphics.pop()
end

return Burst
