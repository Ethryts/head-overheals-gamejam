local vector = require("lib.hump.vector")
local images = {}
local definitions = {
  pillar_round = { width = 10, height = 8 },
  pillar_square = { width = 12, height = 9 },
  pillar_broken = { width = 10, height = 9 },
  pillar_wide = { width = 24, height = 12 },
  crate = { width = 12, height = 8, breakable = true, scale = 0.625 },
  brazier = { width = 10, height = 6, scale = 0.875 },
  barrel = { width = 10, height = 8, breakable = true, scale = 0.625 },
}

---@class MapStructure
---@field kind string Structure asset ID.
---@field breakable boolean Whether this type can be smashed.
---@field broken? boolean
---@field flight? table Active throw; its ground position controls collision and depth.
---@field lift? number Visual height above the ground.
---@field angle? number Visual spin in radians.
---@field onBreak? fun(structure: MapStructure) Called once for gameplay destruction.
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
  scale = scale * (definition.scale or 1)
  local width, height = definition.width * scale, definition.height * scale
  local structure = setmetatable({
    kind = kind, x = x, y = y, scale = scale, image = image, world = world,
    breakable = definition.breakable == true, width = width, height = height,
    shape = world:rectangle(x - width / 2, y - height, width, height),
  }, Structure)
  structure.shape.structure = structure
  return structure
end

function Structure:draw()
  if self.broken then return end
  if self.flight then
    love.graphics.setColor(0, 0, 0, 0.25)
    love.graphics.ellipse("fill", self.x, self.y, self.width / 2, self.height / 3)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self.image, self.x, self.y - self.image:getHeight() * self.scale / 2 - self.lift,
      self.angle, self.scale, self.scale, self.image:getWidth() / 2, self.image:getHeight() / 2)
    return
  end
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

-- Ground travel and the visual arc share one clock, so long frames land exactly.
Structure.throw = { distance = 180, duration = 0.45, height = 40, spin = math.pi * 1.5 }

function Structure:launch(direction)
  if not self.breakable or self.broken or self.flight or not self.shape or direction:len() == 0 then
    return false
  end
  local aim = direction:normalized()
  self.flight = { elapsed = 0, origin = vector(self.x, self.y - self.height / 2),
    direction = aim, spin = aim.x < 0 and -1 or 1 }
  self.lift, self.angle = 0, 0
  -- Airborne props no longer block walking, beams or their own flight trace.
  self.world:remove(self.shape)
  self.shape = nil
  return true
end

---@param trace fun(origin: HumpVector, destination: HumpVector, radius: number): number?
function Structure:updateFlight(dt, trace)
  local flight = self.flight
  if not flight or dt <= 0 then return end
  local tuning = Structure.throw
  local elapsed = math.min(tuning.duration, flight.elapsed + dt)
  local origin = vector(self.x, self.y - self.height / 2)
  local destination = flight.origin + flight.direction * (tuning.distance * elapsed / tuning.duration)
  local hit = trace(origin, destination, math.max(self.width, self.height) / 2)
  local fraction = hit or 1
  local position = origin + (destination - origin) * fraction
  flight.elapsed = flight.elapsed + (elapsed - flight.elapsed) * fraction
  self.x, self.y = position.x, position.y + self.height / 2
  local progress = flight.elapsed / tuning.duration
  self.lift = 4 * tuning.height * progress * (1 - progress)
  self.angle = tuning.spin * progress * flight.spin
  if hit or elapsed >= tuning.duration then self:tryBreak() end
end

-- Gameplay destruction is distinct from unloading a chunk.
---@return boolean broken
function Structure:tryBreak()
  if not self.breakable or self.broken or (not self.shape and not self.flight) then return false end
  self.broken = true
  self:destroy()
  if self.onBreak then self.onBreak(self) end
  return true
end

-- Emit only near the camera; ownership follows the structure through unloading.
function Structure:updateEffects(fx, visible)
  if self.kind ~= "brazier" then return end
  if not visible or not self.shape then
    for _, emitter in pairs(self.emitters or {}) do emitter:stop() end
    self.emitters = nil
    return
  end
  self.emitters = self.emitters or {}
  for _, preset in ipairs({"brazier_flame", "embers"}) do
    local emitter = self.emitters[preset]
    if not emitter or not emitter.active then
      local x, y = self.x, self.y - 9 * self.scale
      emitter = fx:start(preset, x, y, {depth = self.y})
      self.emitters[preset] = emitter
      if emitter.active then fx:emit(preset, x, y, {depth = self.y}) end
    end
  end
end

-- Called when the owning chunk unloads; stops ambient effects without loot.
function Structure:destroy()
  for _, emitter in pairs(self.emitters or {}) do emitter:stop() end
  self.emitters = nil
  self.flight = nil
  if self.shape then
    self.world:remove(self.shape)
    self.shape = nil
  end
end

return Structure
