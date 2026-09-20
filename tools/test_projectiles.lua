-- Run from the repository root: luajit tools/test_projectiles.lua
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
local font = {setFilter = function() end, getWidth = function(_, s) return #s * 9 end, getHeight = function() return 18 end}
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

local vector = require('lib.hump.vector')
local Projectiles = require('systems.projectile')
local Creatures = require('systems.creature')
local behavior = require('behavior')
local Map = require('systems.map')
local Structure = require('src.structure')
local HC = require('lib.HC')
local function near(a,b) assert(math.abs(a-b)<1e-7, a .. ' ~= ' .. b) end
local function target(x,y)
  return {position=vector(x,y), health=100, takeDamage=function(self,n) self.health=self.health-n end}
end
local shots=Projectiles.new()
local origin,direction=vector(0,0),vector(2,0)
local shot=shots:spawn({position=origin,direction=direction})
origin.x=500; direction.y=20
shots:update(0.5)
near(shot.position.x,120); near(shot.position.y,0); near(shot.lifespan,2.5)
assert(not shots:spawn({position=origin,direction=vector(0,0)}))
shots:destroy(); shots:destroy(); assert(#shots.projectiles==0)
local function fire(options)
  shots:destroy()
  options=options or {}
  options.position=options.position or vector(0,0)
  options.direction=options.direction or vector(1,0)
  return shots:spawn(options)
end
local knight=target(100,0)
fire(); shots:update(1,{knight=knight})
assert(knight.health==99 and #shots.projectiles==0, 'Fast shot crosses target and hits once')
shots:update(1,{knight=knight}); assert(knight.health==99)
fire(); shots:update(1,{knight=knight,traceWorld=function() return 0.1 end})
assert(knight.health==99 and #shots.projectiles==0, 'Pillar before target blocks damage')
fire(); shots:update(1,{knight=knight,traceWorld=function() return 0.8 end})
assert(knight.health==98, 'Target before pillar is hit')
fire(); shots:update(1,{knight=knight,traceWorld=function() return 80/240 end})
assert(knight.health==98, 'Pillar wins an equal-distance collision')
fire({position=knight.position}); shots:update(0.1,{knight=knight})
assert(knight.health==97, 'Initial target overlap hits')
fire({position=knight.position}); shots:update(0.1,{knight=knight,traceWorld=function() return 0 end})
assert(knight.health==97, 'Initial pillar overlap blocks')
fire({lifespan=0.1}); shots:update(2,{knight=knight})
assert(knight.health==97 and #shots.projectiles==0, 'No travel beyond lifespan')
knight.dead=true
fire(); shots:update(1,{knight=knight}); assert(knight.health==97)
knight.dead=nil
fire({position=vector(0,21)}); shots:update(1,{knight=knight})
assert(knight.health==97, 'Near miss stays a miss')

local creatures=Creatures.new()
knight=target(0,0)
local eye=creatures:create('bloodshot_eye',400,0,{speed=60,movementBehavior=behavior.ranged})
local context={knight=knight,projectiles=shots}
shots:destroy(); creatures:update(2,context)
near(eye.position.x,300)
assert(#shots.projectiles==1 and knight.health==100, 'Ranged attacks spawn without instant damage')
creatures:update(1,context); near(eye.position.x,300); assert(#shots.projectiles==1)
creatures:update(0.5,context); assert(#shots.projectiles==2, 'Cooldown permits next shot')
knight.position=vector(1000,0)
assert(shots.projectiles[1].velocity.x<0, 'Flight direction does not home')
creatures:damage(eye,10)
shots:update(0.1); assert(#shots.projectiles==2, 'Shots survive shooter death')
shots:destroy(); knight=target(0,0); context.knight=knight
local isolated=Creatures.new()
local noSystemEye=isolated:create('bloodshot_eye',200,0)
isolated:update(0.1,{knight=knight})
assert(noSystemEye.movementBehavior==behavior.ranged)
assert(knight.health==100 and noSystemEye.attackCooldownRemaining==0,
  'Missing projectile system never falls back to instant damage')
local melee=creatures:create('death_slime',10,0)
creatures:update(0.1,context); assert(knight.health==99 and #shots.projectiles==0)
local override=creatures:create('bloodshot_eye',10,0,{attack={type='melee',damage=2,cooldown=1,range=24}})
creatures:update(0.1,context); assert(knight.health==97, 'Explicit attack overrides eye default')
creatures=Creatures.new()
eye=creatures:create('bloodshot_eye',300,0,{movementBehavior=behavior.ranged})
creatures:applyKnockback(eye,vector(1,0),30,0.25)
creatures:update(0.2,context); assert(#shots.projectiles==0, 'Knockback interrupts firing')
creatures:update(0.1,context); assert(#shots.projectiles==0, 'Out of range after knockback')
knight.position=vector(30,0); creatures:update(0.01,context); assert(#shots.projectiles==1)

-- Movement behaviors stay independently selectable, regardless of attack type.
local actor={position=vector(400,0),velocity=vector(0,0),speed=60,
  attack={type='ranged',range=300}}
local movementContext={knight=target(0,0)}
behavior.ranged.update(actor,2,movementContext); near(actor.velocity.x,-50)
actor.position=vector(200,0)
behavior.ranged.update(actor,1,movementContext); near(actor.velocity:len(),0)
behavior.chase.update(actor,1,movementContext); near(actor.velocity.x,-60)
behavior.ranged.update(actor,1,{}); near(actor.velocity:len(),0)
actor.velocity=vector(10,0)
behavior.ranged.update(actor,0,movementContext); near(actor.velocity:len(),0)
local explicit=Creatures.new():create('bloodshot_eye',0,0,{movementBehavior=behavior.idle})
assert(explicit.movementBehavior==behavior.idle, 'Explicit behavior takes priority')

-- Every movement resolves before either independently selected attack runs.
local ordered=Creatures.new()
local events={}
local first,second
local movement={update=function(c,dt)
  events[#events+1]='move'
  c.velocity=vector(10,0)
end}
local attackBehavior={update=function(c,dt,ctx,canAttack)
  events[#events+1]='attack'
  near(first.position.x,10); near(second.position.x,110)
  assert(canAttack)
end}
first=ordered:create('death_slime',0,0,{movementBehavior=movement,attackBehavior=attackBehavior})
second=ordered:create('bloodshot_eye',100,0,{movementBehavior=movement,attackBehavior=attackBehavior})
ordered:update(1,{})
assert(table.concat(events,',')=='move,move,attack,attack')
local attacks=require('attacks')
ordered=Creatures.new(); knight=target(0,0)
first=ordered:create('death_slime',10,0)
second=ordered:create('death_slime',10,0)
first.attackCooldownRemaining=0.8
second.attackCooldownRemaining=0.3
ordered:update(0.4,{knight=knight})
near(first.attackCooldownRemaining,0.4)
near(second.attackCooldownRemaining,1)
assert(knight.health==99, 'Shared attack modules keep independent cooldowns')
ordered:applyKnockback(first,vector(1,0),1,0.5)
ordered:update(0.5,{knight=knight})
near(first.attackCooldownRemaining,0)
assert(knight.health==99, 'Cooldown advances but exact knockback completion does not attack')
ordered:update(0.01,{knight=knight}); assert(knight.health==98)
local mixed=Creatures.new()
local mixedCreature=mixed:create('bloodshot_eye',10,0,{
  movementBehavior=behavior.idle, attackBehavior=attacks.melee,
})
assert(mixedCreature.attackBehavior==attacks.melee)
mixed:update(0.1,{knight=knight,projectiles=shots})
assert(knight.health==97, 'Explicit attack behavior takes priority over type defaults')

local map=Map.new()
map.createStructures=function() return {} end
map:update(0,0,960,540)
local pillar=Structure.new('pillar_round',100,0,4,map.structureSystem.world)
table.insert(map.chunks['0:0'].structures,pillar)
local visible=map.visible
near(map:traceProjectile(vector(0,-10),vector(300,-10),4),76/300)
assert(map:traceProjectile(vector(0,10),vector(300,10),4)==nil)
near(map:traceProjectile(vector(100,-10),vector(300,-10),4),0)
near(map:traceProjectile(vector(100,-10),vector(100,-10),4),0)
assert(map:traceProjectile(vector(0,10),vector(0,10),4)==nil)
near(map:traceProjectile(vector(100,-100),vector(100,100),4),64/200)
near(map:traceProjectile(vector(300,-10),vector(0,-10),4),176/300)
-- A diagonal crossing also finds the expanded footprint.
assert(map:traceProjectile(vector(0,-100),vector(200,100),4))
map.createStructures=function(self,chunk)
  if chunk.chunkX==4 and chunk.chunkY==0 then
    return {Structure.new('pillar_round',2080,64,4,self.structureSystem.world)}
  end
  return {}
end
assert(not map.chunks['4:0'])
near(map:traceProjectile(vector(1990,50),vector(2200,50),4),66/210)
assert(map.visible==visible and map.chunks['4:0'] and map.chunks['0:0'])
map:update(0,0,960,540); assert(not map.chunks['4:0'], 'Trace-loaded chunks are reclaimed')
map:destroy(); assert(next(map.structureSystem.world:hash():shapes())==nil)
local empty=Map.new({structures=false})
assert(empty:traceProjectile(vector(0,0),vector(100,0),4)==nil); empty:destroy()

-- Kick clears every shot whose center is inside the same range/arc as creatures.
local Kick=require('src.kick')
local kick=Kick.new()
shots:destroy()
local function addShot(x,y)
  return shots:spawn({position=vector(x,y),direction=vector(-1,0)})
end
addShot(0,0); addShot(40,0); addShot(80,0); addShot(40,40)
local behind=addShot(-10,0)
local outsideArc=addShot(10,30)
local outsideRange=addShot(81,0)
local kickCreatures=Creatures.new()
local kicked=kickCreatures:create('death_slime',40,0)
assert(kick:tryActivate(0,0,vector(1,0),kickCreatures,shots))
assert(kicked.knockback and #shots.projectiles==3)
assert(shots.projectiles[1]==behind and shots.projectiles[2]==outsideArc and shots.projectiles[3]==outsideRange)
local later=addShot(40,0)
assert(not kick:tryActivate(0,0,vector(1,0),kickCreatures,shots))
assert(#shots.projectiles==4, 'Cooldown prevents projectile clearing too')
kick:update(1)
assert(not kick:tryActivate(0,0,vector(0,0),kickCreatures,shots))
assert(#shots.projectiles==4, 'Zero-direction kick clears nothing')
assert(kick:tryActivate(0,0,vector(1,0),kickCreatures,shots))
assert(#shots.projectiles==3, 'Fresh activation clears later shots')
shots:destroy()

-- Native game callbacks: world drawing, pause, debug isolation, death and restart.
dofile('game/main.lua')
local GS=require('gamestate.deps').Gamestate
love.load(); love.update(0); love.keypressed('return'); love.update(0)
local game=require('gamestate.game')
game.spawner:setEnabled(false); game.pickups:destroy(); game.pickups.batchSize=0
game.creatures=Creatures.new(); game.knight.idleTimer=100
local hp=game.knight.health
local startingHealth=hp
game.projectiles:spawn({position=vector(40,0),direction=vector(-1,0)})
keys={f=true,right=true}; love.update(0.2)
assert(#game.projectiles.projectiles==0 and game.knight.health==hp,
  'Game kick destroys the incoming shot before it can damage the knight')
keys={}; love.update(0)
local live=game.projectiles:spawn({position=vector(0,100),direction=vector(1,0)})
love.update(0.1)
local at=live.position:clone()
love.keypressed('escape'); love.update(1)
local drawCount=0
local drawShots=game.projectiles.drawProjectile
game.projectiles.drawProjectile=function(self, shot) drawCount=drawCount+1; drawShots(self, shot) end
love.draw(); assert(drawCount==1 and live.position==at, 'Paused world still draws frozen projectiles')
love.keypressed('return'); love.update(0.1); assert(live.position.x>at.x)
love.keypressed('f3')
local debug=GS.current(); debug:selectTest(require('debug.spawn_creature'))
local test=debug.activeTest
assert(test.projectiles~=game.projectiles and test.context.knight~=game.knight)
test.creatures:create('bloodshot_eye',0,270,{movementBehavior=behavior.ranged,speed=200})
test:update(1); assert(#test.projectiles.projectiles>0)
local health=test.context.knight.health; test:update(1)
assert(test.context.knight.health<health)
love.keypressed('f3'); assert(GS.current()==game)
game.projectiles:destroy()
game.knight:setHealth(1)
game.projectiles:spawn({position=game.knight.position,direction=vector(1,0)})
love.update(0.01)
assert(GS.current()==require('gamestate.endscreen'), 'Projectile death ends the run in the impact frame')
assert(#game.projectiles.projectiles==0 and next(HC.hash():shapes())==nil)
love.update(0) -- Let HUMP enter the end-screen event cycle before pressing restart.
love.keypressed('return'); love.update(0)
assert(GS.current()==game and #game.projectiles.projectiles==0 and game.knight.health==startingHealth)
game:leave()
print('Projectile tests passed: swept hits, pillars, streaming, ranged combat, kick destruction, pause, debug isolation and restart')
