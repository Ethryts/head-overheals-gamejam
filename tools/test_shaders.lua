-- Run from the repository root: luajit tools/test_shaders.lua
package.path = 'game/src/?.lua;' .. package.path
local events, canvases, stack = {}, {}, {}
local width, height, dpi = 960, 540, 1
local state = {canvas = 'screen', shader = 'caller'}
local function record(event) events[#events + 1] = event end
love = {graphics = {}}
local g = love.graphics
function g.getDimensions() return width, height end
function g.getDPIScale() return dpi end
function g.newCanvas(w, h, options)
  local canvas = {id = #canvases + 1}
  function canvas:setFilter() end
  function canvas:setWrap() end
  function canvas:getPixelDimensions() return w * options.dpiscale, h * options.dpiscale end
  function canvas:release() self.released = true end
  canvases[#canvases + 1] = canvas
  return canvas
end
function g.newShader(path)
  local shader = {path = path, sent = {}}
  function shader:hasUniform(name) return self.path == 'diffuse' and name == 'screenSize' end
  function shader:send(name, value) self.sent[name] = value end
  function shader:release() self.released = true end
  return shader
end
function g.push() stack[#stack + 1] = {canvas = state.canvas, shader = state.shader} end
function g.pop() state = table.remove(stack) end
function g.setCanvas(canvas) state.canvas = canvas end
function g.setShader(shader) state.shader = shader end
function g.draw(canvas)
  assert(canvas ~= state.canvas, 'Cannot sample current render target')
  record(state.shader and state.shader.path or 'present')
end
for _, name in ipairs({'origin', 'setScissor', 'clear', 'setColor', 'setBlendMode'}) do
  g[name] = function() end
end
local ShaderSystem = require('systems.shader')
local shaders = ShaderSystem.new({effects = {{name = 'diffuse', path = 'diffuse'},
  {name = 'grade', path = 'grade', uniforms = {strength = 0.5}}}})
local function scene() record('scene') end
local function ui() record('ui') end
local function check(expected, menu)
  events = {}
  shaders:draw(scene, ui, menu)
  assert(table.concat(events, ',') == expected, table.concat(events, ','))
  assert(state.canvas == 'screen' and state.shader == 'caller' and #stack == 0,
    'Caller graphics state must be restored')
end
check('scene,diffuse,grade,present,ui')
assert(#canvases == 2)
assert(shaders:get('diffuse').shader.sent.screenSize[1] == 960)
assert(shaders:get('grade').shader.sent.strength == 0.5)
check('scene,diffuse,grade,present,ui')
assert(#canvases == 2, 'Reuse targets')
check('scene,ui', true)
shaders.includeMenus, shaders.includeUI = true, true
check('scene,ui,diffuse,grade,present', true)
shaders:get('diffuse').enabled = false
check('scene,ui,grade,present')
shaders.enabled = false
check('scene,ui')
shaders.enabled = true
width, height, dpi = 1280, 720, 2
check('scene,ui,grade,present')
assert(#canvases == 4 and canvases[1].released and canvases[2].released)
shaders:get('diffuse').enabled = true
check('scene,ui,diffuse,grade,present')
assert(shaders:get('diffuse').shader.sent.screenSize[1] == 2560)
local diffuse = shaders:get('diffuse').shader
assert(not pcall(function() shaders:add('diffuse', 'diffuse') end))
assert(shaders:remove('diffuse') and diffuse.released)
assert(not shaders:remove('missing'))
shaders:remove('grade')
check('scene,ui')
shaders:destroy()
assert(canvases[3].released and canvases[4].released)
local empty = ShaderSystem.new()
empty:draw(scene, ui, false)
assert(#canvases == 4, 'Empty pipeline should not allocate targets')
print('Shader tests passed: ordering, UI/menu bypass, uniforms, resize, lifecycle and state restoration')
