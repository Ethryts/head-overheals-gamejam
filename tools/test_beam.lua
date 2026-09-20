-- Run from the repository root: luajit tools/test_beam.lua
-- Real Baton, gameplay, HC and state lifecycle; only LÖVE platform APIs are mocked.
package.path = "game/?.lua;game/?/init.lua;game/src/?.lua;game/src/?/init.lua;" .. package.path
local function noop() end
local function audioSource()
  return {setLooping = noop, play = noop, stop = noop, setVolume = noop,
    setFilter = noop, isPlaying = function() return true end, clone = audioSource}
end
local keys, axes = {}, {}
local joystick = {
  getGamepadAxis = function(_, axis) return axes[axis] or 0 end,
  isGamepadDown = function() return false end,
}
local font = {getWidth = function(_, s) return #s * 9 end, getHeight = function() return 18 end}
local function read32(data, offset)
  local a, b, c, d = data:byte(offset, offset + 3)
  return ((a * 256 + b) * 256 + c) * 256 + d
end
love = {
  handlers = {},
  filesystem = {getRequirePath = function() return package.path end,
    setRequirePath = function(path) package.path = path end},
  keyboard = {isDown = function(key) return keys[key] or false end},
  joystick = {getJoysticks = function() return {joystick} end},
  mouse = {getPosition = function() return 0, 0 end, getX = function() return 0 end,
    getY = function() return 0 end, isDown = function() return false end},
  system = {getOS = function() return "Linux" end},
  audio = {newSource = audioSource},
  math = {newRandomGenerator = function(seed)
    local state = seed % 2147483647 + 1
    return {random = function(_, low, high)
      state = state * 48271 % 2147483647
      return low + state % (high - low + 1)
    end}
  end},
  graphics = setmetatable({
    newCanvas = function() return {setFilter = noop, release = noop} end,
    newImage = function(path)
      local file = assert(io.open("game/" .. path, "rb"))
      local header = file:read(24); file:close()
      return {getWidth = function() return read32(header, 17) end,
        getHeight = function() return read32(header, 21) end, setFilter = noop}
    end,
    newQuad = function(x, y, w, h) return {getViewport = function() return x, y, w, h end} end,
    newSpriteBatch = function() return {add = noop, flush = noop, release = noop} end,
    newFont = function() return font end, getFont = function() return font end,
    getDimensions = function() return 960, 540 end,
  }, {__index = function() return noop end}),
}
package.loaded.love = love
-- SUIT loads its text widget eagerly; this suite never uses text input.
package.preload.utf8 = function() return {} end
-- Unit-level player updates run before love.load initializes the game services.
require("gamestate.deps").Gamestate.soundEffectsSystem = require("systems.sound_effects"):new()

local meshes, released, uploads, draws = 0,0,0,0
love.graphics.newMesh=function(vertices,mode,usage)
  assert(#vertices==42 and mode=='strip' and usage=='dynamic')
  meshes=meshes+1
  return {setVertices=function(_,v) assert(#v==42); uploads=uploads+1 end,
    release=function() released=released+1 end}
end
love.graphics.draw=function() draws=draws+1 end
love.graphics.line=function() draws=draws+1 end
love.graphics.rectangle=function() draws=draws+1 end
local vector=require('lib.hump.vector')
local Beam=require('src.beam')
local origin,direction=vector(0,0),vector(1,0)
local beam=Beam:new(origin,direction)
beam:draw(); assert(meshes==0,'A zero-length beam does not allocate a mesh')
for _=1,30 do beam:update(1/60,origin,direction) end
assert(beam.length==200 and beam.width==10)
assert(beam:containsPoint(vector(100,0)))
assert(not beam:containsPoint(vector(100,20)),'Crackle does not widen collision')
beam:draw(); assert(meshes==1 and draws<=22,'Bounded mesh/strand/sparkle draw count')
local time, uploadCount=beam.visual.time,uploads
beam:draw(); assert(beam.visual.time==time and uploads==uploadCount,'Draw never animates or uploads unchanged geometry')
local vertices,cracks,sparkles=beam.visual.vertices,beam.visual.cracks,beam.visual.sparkles
local before=cracks[1][16]
beam:update(0.1,origin,direction)
assert(cracks[1][16]~=before,'Crackle flickers over time')
beam.bend=40; beam.bendVelocity=0
beam:update(0,origin,direction)
assert(beam:containsPoint(vector(100,20)),'Curved beam retains its original collision curve')
assert(math.abs(beam.visual.center[21]-100)<1e-9 and math.abs(beam.visual.center[22]-20)<1e-9)
local started=os.clock()
for _=1,10000 do beam.visual:update(beam,1/60) end
print(string.format('10,000 visual updates: %.3fs (CPU geometry only)',os.clock()-started))
assert(beam.visual.vertices==vertices and beam.visual.cracks==cracks and beam.visual.sparkles==sparkles)
assert(#vertices==42 and #cracks==2 and #sparkles==8,'Visual buffers never grow')
beam:draw(); assert(meshes==1,'Mesh is reused')
beam:startRelease(); beam:update(1,origin,direction)
assert(not beam.isVisible and not beam:containsPoint(vector(100,0)))
beam:destroy(); beam:destroy(); assert(released==1)
local Player=require('src.player')
local player=Player.new(0,0)
-- Simulate repeated beam taps through the real player update path.
for _=1,20 do
  keys={space=true,right=true}
  Player.update(player,0.05)
  Player.draw(player)
  assert(player.currentBeam and #player.allBeams==1)
  keys={}
  Player.update(player,0.1)
  assert(not player.currentBeam and #player.allBeams==0,'Finished beams are removed immediately')
end
assert(meshes==released,'Completed beams release every mesh')
print('Beam tests passed: bounded geometry, flicker, unchanged collision, draw purity and repeated-release cleanup')
