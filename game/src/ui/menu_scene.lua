local WorldCanvas = require("src.world_canvas")
local PlayerAnimation = require("src.player_animation")
local Fx = require("systems.fx")
local Scene = {}
Scene.__index = Scene
local images = {}
local function image(name)
  if not images[name] then
    images[name] = love.graphics.newImage("assets/images/Tileset/" .. name .. ".png")
    images[name]:setFilter("nearest", "nearest")
  end
  return images[name]
end

function Scene.new()
  local self = setmetatable({canvas = WorldCanvas.new(), batches = {}, time = 0,
    fx = Fx.new({seed = 71, maxParticles = 48, maxEmitters = 3}),
    knight = PlayerAnimation.new("assets/images/Hero Asset/Animations", {bodyScale = 3, frameDuration = 0.4}),
    healer = PlayerAnimation.new("assets/images/Healer Asset/Animations", {bodyScale = 3, frameDuration = 0.4}),
  }, Scene)
  -- A fixed, cached chamber: no gameplay world, collision or global RNG.
  for i = 1, 10 do
    local batch = love.graphics.newSpriteBatch(image(string.format("floor_%02d", i)), 600, "static")
    for row = 0, 16 do
      for col = 0, 29 do
        if (col*7 + row*13 + col*row) % 10 + 1 == i then
          batch:add(col*32, row*32, 0, 2, 2)
        end
      end
    end
    batch:flush()
    self.batches[i] = batch
  end
  self.fx:start("menu_embers", 252, 409)
  self.fx:start("menu_embers", 708, 409)
  self.fx:start("menu_dust", 480, 270)
  return self
end

function Scene:update(dt)
  dt = math.min(dt, 0.1)
  self.time = self.time + dt
  self.knight:update(dt)
  self.healer:update(dt)
  self.fx:update(dt)
end

local function prop(name, x, bottom, scale, brightness)
  local sprite = image(name)
  love.graphics.setColor(brightness or 0.75, brightness or 0.78, brightness or 0.83)
  love.graphics.draw(sprite, x, bottom, 0, scale, scale, sprite:getWidth()/2, sprite:getHeight())
end

function Scene:draw()
  self.canvas:draw(function()
    love.graphics.setColor(0.52, 0.57, 0.65)
    for _, batch in ipairs(self.batches) do love.graphics.draw(batch) end
    -- Stepped shadows leave the center open and slightly brighter.
    for i = 0, 7 do
      love.graphics.setColor(0.015, 0.025, 0.04, 0.075)
      love.graphics.rectangle("fill", 0, 0, 32+i*24, 540)
      love.graphics.rectangle("fill", 928-i*24, 0, 32+i*24, 540)
      love.graphics.rectangle("fill", 0, 0, 960, 12+i*8)
    end
    for x = 32, 928, 32 do prop("wall_horizontal", x, 42, 2, 0.5) end
    for _, x in ipairs({88, 872}) do
      prop("pillar_square", x, 196, 4)
      prop("pillar_round", x, 374, 4)
      prop("pillar_broken", x, 518, 4)
    end
    prop("rubble_large", 152, 478, 3, 0.55)
    prop("decal_bones", 808, 466, 3, 0.7)
    prop("decal_bones", 166, 214, 2, 0.55)
    prop("decal_pebbles", 796, 236, 3, 0.5)
    for _, x in ipairs({252, 708}) do
      local flicker = 0.9 + 0.1*math.sin(self.time*3)
      for radius = 4, 1, -1 do
        love.graphics.setColor(1, 0.45, 0.12, 0.025*flicker)
        love.graphics.ellipse("fill", x, 434, radius*24, radius*10)
      end
      prop("brazier", x, 452, 4, 1)
    end
    self.fx:draw()
    love.graphics.setColor(0, 0, 0, 0.35)
    love.graphics.ellipse("fill", 326, 470, 25, 7)
    love.graphics.ellipse("fill", 634, 470, 25, 7)
    self.knight:draw(326, 448, 1)
    self.healer:draw(634, 448, -1)
  end)
end

function Scene:destroy()
  self.fx:destroy()
  self.canvas:destroy()
  for _, batch in ipairs(self.batches) do batch:release() end
end

return Scene
