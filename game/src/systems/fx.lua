local presets = require("fx.presets")
local atlas, quads
local function loadAtlas()
  if atlas then return end
  atlas = love.graphics.newImage("assets/images/fx/particles.png")
  atlas:setFilter("nearest", "nearest")
  quads = {}
  for i, name in ipairs({"dot", "line", "cluster", "diamond", "sparkle"}) do
    quads[name] = love.graphics.newQuad((i - 1) * 8, 0, 8, 8, 40, 8)
  end
end

---@class FxOptions
---@field angle? number Emission direction in radians.
---@field radius? number Outer reach of a swing in world pixels; defaults to 60.
---@field color? number[] RGB tint for pickup flecks.
---@field depth? number World foot/depth anchor; defaults to y, stays fixed as particles rise.

---@class FxEmitter
---@field active boolean
---@field x number
---@field y number
---@field preset FxPreset
---@field options FxOptions
---@field elapsed number Fractional emission time.
local Emitter = {}
Emitter.__index = Emitter

function Emitter:stop()
  self.active = false -- Existing particles remain owned by FxSystem.
end

---@param x number
---@param y number
---@param depth? number World foot/depth anchor.
function Emitter:setPosition(x, y, depth)
  self.x, self.y = x, y
  self.options.depth = depth or y
end

---@class FxParticle
---@field preset FxPreset
---@field x number
---@field y number
---@field vx number
---@field vy number
---@field age number
---@field lifetime number
---@field depth number
---@field shape string
---@field phase number
---@field angle number
---@field radius number
---@field color? number[]

---@class FxSystem
---@field particles FxParticle[]
---@field emitters FxEmitter[]
---@field maxParticles integer
---@field maxEmitters integer
local FxSystem = {}
FxSystem.__index = FxSystem

---@param options? { seed?: integer, maxParticles?: integer, maxEmitters?: integer }
---@return FxSystem
function FxSystem.new(options)
  options = options or {}
  return setmetatable({particles = {}, emitters = {},
    maxParticles = options.maxParticles or 1024, maxEmitters = options.maxEmitters or 64,
    random = love.math.newRandomGenerator(options.seed or 1)}, FxSystem)
end

local function sample(self, low, high)
  return low + (high - low) * self.random:random(0, 1000000) / 1000001
end

local function copyOptions(options)
  options = options or {}
  local color = options.color
  return {angle = options.angle, radius = options.radius, depth = options.depth,
    color = color and {color[1], color[2], color[3]} or nil}
end

local function advance(p, dt)
  local preset = p.preset
  -- Exact integration of dv/dt = acceleration - drag*v keeps bursts frame independent.
  if preset.drag == 0 then
    p.x = p.x + p.vx * dt + preset.acceleration[1] * dt * dt / 2
    p.y = p.y + p.vy * dt + preset.acceleration[2] * dt * dt / 2
    p.vx = p.vx + preset.acceleration[1] * dt
    p.vy = p.vy + preset.acceleration[2] * dt
    p.age = p.age + dt
    return
  end
  local decay = math.exp(-preset.drag * dt)
  local step = (1 - decay) / preset.drag
  local terminalX, terminalY = preset.acceleration[1] / preset.drag, preset.acceleration[2] / preset.drag
  p.x = p.x + terminalX * dt + (p.vx - terminalX) * step
  p.y = p.y + terminalY * dt + (p.vy - terminalY) * step
  p.vx = terminalX + (p.vx - terminalX) * decay
  p.vy = terminalY + (p.vy - terminalY) * decay
  p.age = p.age + dt
end

local function spawn(self, preset, x, y, options, age)
  if #self.particles >= self.maxParticles then return end
  -- Emitter birth-count tolerance can put a birth just ahead of this frame.
  -- Keep that rounding residue from producing a negative age and palette index 0.
  age = math.max(0, age)
  local lifetime = sample(self, preset.lifetime[1], preset.lifetime[2])
  if age >= lifetime then return end
  local angle = (options.angle or preset.angle) + sample(self, -preset.spread / 2, preset.spread / 2)
  local speed = sample(self, preset.speed[1], preset.speed[2])
  local p = {preset = preset, x = x + sample(self, -preset.spreadX, preset.spreadX),
    y = y + sample(self, -preset.spreadY, preset.spreadY),
    vx = math.cos(angle) * speed, vy = math.sin(angle) * speed,
    age = 0, lifetime = lifetime, depth = options.depth or y,
    shape = preset.shapes[self.random:random(1, #preset.shapes)],
    phase = sample(self, 0, math.pi * 2), color = options.color, angle = angle, radius = options.radius or 60}
  advance(p, age)
  self.particles[#self.particles + 1] = p
end

---@param name string Preset ID: sparks, impact, beam_impact, dodge, swing, dust, embers, healing, pickup.
---@param x number World position.
---@param y number
---@param options? FxOptions
function FxSystem:emit(name, x, y, options)
  local preset = assert(presets[name], "Unknown FX preset: " .. tostring(name))
  options = copyOptions(options)
  for _ = 1, math.min(preset.count, self.maxParticles - #self.particles) do
    spawn(self, preset, x, y, options, 0)
  end
end

---@param name string
---@param x number
---@param y number
---@param options? FxOptions
---@return FxEmitter emitter Inactive if the emitter budget is full.
function FxSystem:start(name, x, y, options)
  local preset = assert(presets[name], "Unknown FX preset: " .. tostring(name))
  local emitter = setmetatable({preset = preset, x = x, y = y,
    options = copyOptions(options), elapsed = 0, active = #self.emitters < self.maxEmitters}, Emitter)
  if emitter.active then self.emitters[#self.emitters + 1] = emitter end
  return emitter
end

---@param dt number
function FxSystem:update(dt)
  if dt <= 0 then return end
  for i = #self.particles, 1, -1 do
    local p = self.particles[i]
    advance(p, dt)
    if p.age >= p.lifetime then table.remove(self.particles, i) end
  end
  for i = #self.emitters, 1, -1 do
    local emitter = self.emitters[i]
    if not emitter.active then
      table.remove(self.emitters, i)
    else
      local interval = 1 / emitter.preset.rate
      local elapsed = emitter.elapsed + dt
      local count = math.floor(elapsed / interval + 1e-9)
      emitter.elapsed = math.max(0, elapsed - count * interval)
      -- Skip old births and bound work on a long frame or at capacity.
      local live = math.ceil(emitter.preset.lifetime[2] / interval)
      local allowed = math.min(count, live, self.maxParticles - #self.particles)
      for birth = count - allowed + 1, count do
        spawn(self, emitter.preset, emitter.x, emitter.y, emitter.options, elapsed - birth * interval)
      end
    end
  end
end

-- A short, opaque ribbon sweeps around the knight's existing circular attack.
-- The low-resolution world canvas gives the silhouette its pixel edges.
local function drawSlash(p, progress)
  local head = p.angle - math.pi / 2 + progress * math.pi * 2
  local tail = head - math.pi * 0.8
  local radius = p.radius * (0.72 + 0.28 * progress)
  local thickness = 8 * (1 - progress) + 2
  local segments = 18
  for i = 0, segments - 1 do
    local startProgress, endProgress = i / segments, (i + 1) / segments
    local startAngle = tail + (head - tail) * startProgress
    local endAngle = tail + (head - tail) * endProgress
    local startInner = radius - thickness * startProgress
    local endInner = radius - thickness * endProgress
    -- Fill one convex strip at a time; taper the ribbon toward its tail.
    love.graphics.polygon("fill",
      p.x + math.cos(startAngle) * radius, p.y + math.sin(startAngle) * radius,
      p.x + math.cos(endAngle) * radius, p.y + math.sin(endAngle) * radius,
      p.x + math.cos(endAngle) * endInner, p.y + math.sin(endAngle) * endInner,
      p.x + math.cos(startAngle) * startInner, p.y + math.sin(startAngle) * startInner)
  end
end

---@param particle FxParticle
function FxSystem:drawParticle(particle)
  loadAtlas()
  local p, preset = particle, particle.preset
  local progress = p.age / p.lifetime
  local stage = math.min(#preset.colors, math.floor(progress * #preset.colors) + 1)
  local color = preset.colors[stage]
  if preset.tint and p.color and stage > 1 then
    local brightness = stage == 2 and 1 or 0.55
    love.graphics.setColor(p.color[1] * brightness, p.color[2] * brightness, p.color[3] * brightness, 1)
  else
    love.graphics.setColor(color[1], color[2], color[3], 1)
  end
  if preset.flicker and math.floor(p.age * 16 + p.phase) % 7 == 0 then
    love.graphics.setColor(1, 0.85, 0.45, 1)
  end
  if p.shape == "slash" then
    drawSlash(p, progress)
    return
  end
  local shape = preset.shrink and progress > 0.65 and "dot" or p.shape
  local drift = preset.drift and math.sin(p.age * 5 + p.phase) * preset.drift or 0
  local x, y = math.floor((p.x + drift) / 2 + 0.5) * 2, math.floor(p.y / 2 + 0.5) * 2
  local angle = shape == "line" and math.floor(math.atan2(p.vy, p.vx) / (math.pi / 2) + 0.5) * math.pi / 2 or 0
  love.graphics.draw(atlas, quads[shape], x, y, angle, 2, 2, 3, 3)
end

---@param layer? "ground"|"air" Omit to draw all particles in depth order.
function FxSystem:draw(layer)
  local particles = {}
  for _, p in ipairs(self.particles) do
    if not layer or p.preset.layer == layer then particles[#particles + 1] = p end
  end
  table.sort(particles, function(a, b) return a.depth < b.depth end)
  love.graphics.push("all")
  for _, p in ipairs(particles) do self:drawParticle(p) end
  love.graphics.pop()
end

function FxSystem:destroy()
  for _, emitter in ipairs(self.emitters) do emitter:stop() end
  self.emitters, self.particles = {}, {}
end

return FxSystem
