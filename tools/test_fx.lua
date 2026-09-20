-- Run from the repository root: luajit tools/test_fx.lua
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

local Fx=require('systems.fx')
local presets=require('fx.presets')
local function near(a,b) assert(math.abs(a-b)<1e-7,a..' ~= '..b) end
for name,preset in pairs(presets) do
  local fx=Fx.new({seed=5})
  fx:emit(name,100,200,{angle=-math.pi/2,depth=220,color={0.2,0.8,1}})
  assert(#fx.particles==preset.count)
  for _,p in ipairs(fx.particles) do
    assert(p.depth==220 and p.age==0)
    assert(p.lifetime>=preset.lifetime[1] and p.lifetime<=preset.lifetime[2])
    assert(math.abs(p.x-100)<=preset.spreadX and math.abs(p.y-200)<=preset.spreadY)
  end
  fx:update(0.05)
  local p=fx.particles[1]
  local x,y,age=p.x,p.y,p.age
  fx:draw('ground'); fx:draw('air'); fx:draw()
  assert(p.x==x and p.y==y and p.age==age,'Drawing does not simulate')
  assert(p.depth==220,'Rising particles retain their ground-depth anchor')
  fx:update(5); assert(#fx.particles==0)
end
local a,b=Fx.new({seed=7}),Fx.new({seed=7})
a:emit('sparks',0,0); b:emit('sparks',0,0)
a:update(0.1); b:update(0.05); b:update(0.05)
for i,p in ipairs(a.particles) do near(p.x,b.particles[i].x); near(p.y,b.particles[i].y) end
local fx=Fx.new({maxParticles=20,maxEmitters=1})
local fire=fx:start('embers',0,0)
assert(not fx:start('embers',0,0).active,'Emitter budget is bounded')
fx:update(0.5); assert(#fx.particles==4)
fire:setPosition(100,200,230)
fx:update(0.5)
local last=fx.particles[#fx.particles]
assert(last.x>90 and last.y>180 and last.depth==230)
local count=#fx.particles
fire:stop(); fx:update(0.01)
assert(#fx.emitters==0 and #fx.particles==count,'Stop preserves existing particles')
fx:update(2); assert(#fx.particles==0)
for _=1,100 do fx:emit('pickup',0,0) end
assert(#fx.particles==20)
fx:start('embers',0,0); fx:update(1000)
assert(#fx.particles<=20 and #fx.emitters==1,'Long frames stay bounded')
fx:destroy(); assert(#fx.particles==0 and #fx.emitters==0)
local color={0.1,0.2,0.3}
fx:emit('pickup',0,0,{color=color}); color[1]=1
assert(fx.particles[1].color[1]==0.1,'Emitter/burst options are copied')
assert(not pcall(fx.emit,fx,'missing',0,0))
-- FX randomness must not consume the gameplay RNG.
math.randomseed(87); local expected=math.random()
math.randomseed(87); fx:emit('dust',0,0); assert(math.random()==expected)
local queue=require('fx.draw_queue').new()
local order={}
queue:add(20,function() order[#order+1]='actor' end)
queue:add(10,function() order[#order+1]='rear effect' end)
queue:add(20,function() order[#order+1]='front effect' end)
queue:add(30,function() order[#order+1]='pillar' end)
queue:draw(); assert(table.concat(order,',')=='rear effect,actor,front effect,pillar')

-- Real gameplay FX hooks and lifecycle.
dofile('game/main.lua')
local GS=require('gamestate.deps').Gamestate
love.load(); love.update(0); love.keypressed('return'); love.update(0)
local game=require('gamestate.game')
game.spawner:setEnabled(false); game.pickups:destroy(); game.pickups.batchSize=0
local recorded={}
local emit=game.fx.emit
game.fx.emit=function(self,name,x,y,options)
  recorded[name]=(recorded[name] or 0)+1
  emit(self,name,x,y,options)
end
keys={d=true}; love.update(0.13); keys={}; love.update(0)
assert(recorded.dust,'Walking creates foot dust')
local coin=game.pickups:create(require('src.items.gold_coin'),game.player.x,game.player.y)
game.pickups:checkCollected(game.player,game.knight,game)
assert(recorded.pickup and coin.removed)
local enemy=game.creatures:create('death_slime',400,0)
game.creatures:damage(enemy,1,game.knight.position); assert(recorded.sparks)
local Player=require('src.player')
local overlap=Player.doesBeamOverlapWithPoint
Player.doesBeamOverlapWithPoint=function() return true end
love.update(0.1); assert(game.healingEmitter and game.healingEmitter.active)
local emitter=game.healingEmitter
Player.doesBeamOverlapWithPoint=function() return false end
love.update(0.01); assert(not emitter.active and not game.healingEmitter)
Player.doesBeamOverlapWithPoint=overlap
local p=game.fx.particles[1]
local age=p.age
love.keypressed('escape'); love.update(1); love.draw()
assert(p.age==age,'Pause draws frozen effects')
love.keypressed('return'); love.update(0)
love.keypressed('f3'); love.update(0)
local debug=GS.current(); debug:selectTest(require('debug.fx'))
local preview=debug.activeTest
preview.selected='embers'; preview:mousepressed(400,250,1); preview:update(0.1); preview:draw()
assert(#preview.fx.particles>0)
love.keypressed('escape'); assert(debug.activeTest==nil and #preview.fx.particles==0)
love.keypressed('f3'); love.update(0)
local oldFx=game.fx
love.keypressed('f2'); love.update(0)
assert(#oldFx.particles==0 and #oldFx.emitters==0)
love.keypressed('return'); love.update(0)
assert(game.fx~=oldFx and #game.fx.particles==0)
game:leave()
print('FX tests passed: presets, independent RNG, emission/stop, timing, budgets, draw order, hooks, pause, debug and restart')
