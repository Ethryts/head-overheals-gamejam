local UI = require("gamestate.ui")
local Fx = require("systems.fx")
local WorldCanvas = require("src.world_canvas")
local PlayerAnimation = require("src.player_animation")
local DrawQueue = require("fx.draw_queue")

local names = {"sparks", "dust", "embers", "healing", "pickup", "impact", "swing"}
local test = {label = "Particle FX", footer = "Click: burst     Toggle emitter: start / stop     Esc: menu     F3: exit"}
test.__index = test
function test.new()
  return setmetatable({fx = Fx.new(), canvas = WorldCanvas.new(), ui = UI.new(), selected = "sparks",
    character = PlayerAnimation.new("assets/images/Hero Asset/Animations", {bodyScale = 4})}, test)
end
function test:update(dt)
  UI.begin(self.ui)
  for i, name in ipairs(names) do
    if self.ui:Button(name, 24 + ((i - 1) % 4) * 132, 70 + math.floor((i - 1) / 4) * 42, 124, 36).hit then self.selected = name end
  end
  if self.ui:Button("Toggle emitter", 704, 70, 220, 36).hit then
    if self.emitter then self.emitter:stop(); self.emitter = nil
    else self.emitter = self.fx:start(self.selected, 480, self.selected == "dust" and 322 or 290, {depth = 322}) end
  end
  self.character:update(dt)
  self.fx:update(dt)
end
function test:mousepressed(x, y, button)
  if button == 1 and y > 158 and y < UI.height - 60 then
    self.fx:emit(self.selected, x, y, {angle = -math.pi / 3, color = {0.4, 0.8, 1}})
  end
end
function test:draw()
  self.canvas:draw(function()
    love.graphics.setColor(0.10, 0.12, 0.13, 1)
    love.graphics.rectangle("fill", 0, 0, UI.width, UI.height)
    self.fx:draw("ground")
    local queue = DrawQueue.new()
    queue:add(322, function() self.character:draw(480, 290, 1) end)
    for _, p in ipairs(self.fx.particles) do
      if p.preset.layer == "air" then queue:add(p.depth, function() self.fx:drawParticle(p) end) end
    end
    queue:draw()
  end)
  UI.draw(self.ui)
  love.graphics.print("FX: " .. self.selected .. "   Particles: " .. #self.fx.particles, 24, 158)
end
function test:destroy()
  self.fx:destroy()
  self.canvas:destroy()
end
return test
