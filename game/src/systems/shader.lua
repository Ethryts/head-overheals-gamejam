-- Ordered fullscreen post-processing. Draw callbacks use window coordinates.
local ShaderSystem = {}
ShaderSystem.__index = ShaderSystem

function ShaderSystem.new(options)
  options = options or {}
  local self = setmetatable({
    enabled = options.enabled ~= false,
    includeUI = options.includeUI == true,
    includeMenus = options.includeMenus == true,
    effects = {},
  }, ShaderSystem)
  for _, effect in ipairs(options.effects or {}) do
    self:add(effect.name, effect.path, effect)
  end
  return self
end

-- Returned entries can be toggled with entry.enabled or edited via entry.uniforms.
function ShaderSystem:add(name, path, options)
  assert(not self:get(name), "Duplicate shader name: " .. name)
  options = options or {}
  local effect = {name = name, shader = love.graphics.newShader(path),
    enabled = options.enabled ~= false, uniforms = options.uniforms or {}}
  self.effects[#self.effects + 1] = effect
  return effect
end

function ShaderSystem:get(name)
  for _, effect in ipairs(self.effects) do
    if effect.name == name then return effect end
  end
end

function ShaderSystem:remove(name)
  for i, effect in ipairs(self.effects) do
    if effect.name == name then
      effect.shader:release()
      table.remove(self.effects, i)
      return true
    end
  end
  return false
end

function ShaderSystem:releaseCanvases()
  if self.canvases then
    for _, canvas in ipairs(self.canvases) do canvas:release() end
    self.canvases = nil
  end
end

function ShaderSystem:ensureCanvases()
  local width, height = love.graphics.getDimensions()
  local dpi = love.graphics.getDPIScale()
  if self.canvases and self.width == width and self.height == height and self.dpi == dpi then return end
  self:releaseCanvases()
  self.width, self.height, self.dpi = width, height, dpi
  self.canvases = {}
  for i = 1, 2 do
    local canvas = love.graphics.newCanvas(width, height, {dpiscale = dpi})
    canvas:setFilter("linear", "linear")
    canvas:setWrap("clamp", "clamp")
    self.canvases[i] = canvas
  end
end

function ShaderSystem:draw(drawScene, drawUI, isMenu)
  local active = {}
  if self.enabled and (not isMenu or self.includeMenus) then
    for _, effect in ipairs(self.effects) do
      if effect.enabled then active[#active + 1] = effect end
    end
  end
  if #active == 0 then
    drawScene()
    drawUI()
    return
  end

  self:ensureCanvases()
  local graphics = love.graphics
  graphics.push("all")
  graphics.origin()
  graphics.setScissor()
  graphics.setShader()
  graphics.setCanvas(self.canvases[1])
  graphics.clear(0.035, 0.047, 0.063, 1)
  graphics.setColor(1, 1, 1, 1)
  graphics.setBlendMode("alpha")
  drawScene()
  if self.includeUI then drawUI() end

  local source = 1
  for _, effect in ipairs(active) do
    local target = 3 - source
    graphics.setCanvas(self.canvases[target])
    graphics.origin()
    graphics.setScissor()
    graphics.clear(0, 0, 0, 0)
    graphics.setColor(1, 1, 1, 1)
    graphics.setBlendMode("replace", "premultiplied")
    graphics.setShader(effect.shader)
    for name, value in pairs(effect.uniforms) do effect.shader:send(name, value) end
    if effect.shader:hasUniform("screenSize") then
      effect.shader:send("screenSize", {self.canvases[source]:getPixelDimensions()})
    end
    graphics.draw(self.canvases[source])
    source = target
  end
  -- pop restores the caller's render target as well as its graphics state.
  graphics.pop()
  graphics.push("all")
  graphics.origin()
  graphics.setScissor()
  graphics.setShader()
  graphics.setColor(1, 1, 1, 1)
  graphics.setBlendMode("alpha", "premultiplied")
  graphics.draw(self.canvases[source])
  graphics.pop()
  if not self.includeUI then drawUI() end
end

function ShaderSystem:destroy()
  self:releaseCanvases()
  for _, effect in ipairs(self.effects) do effect.shader:release() end
  self.effects = {}
end

return ShaderSystem
