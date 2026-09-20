-- Run from the repository root: luajit tools/test_ogre.lua
package.path = "game/?.lua;game/?/init.lua;game/src/?.lua;game/src/?/init.lua;" .. package.path
local function noop() end
love = {graphics = {
  newImage = function(path)
    local file = assert(io.open("game/" .. path, "rb")); file:close()
    return {getWidth = function() return 64 end, getHeight = function() return 16 end, setFilter = noop}
  end,
  newQuad = function(x, y, w, h) return {getViewport = function() return x, y, w, h end} end,
  getDimensions = function() return 960, 540 end,
}}
package.loaded["gamestate.deps"] = {Gamestate = {soundEffectsSystem = {playSoundEffect = noop}}}
local vector = require("lib.hump.vector")
local Creatures = require("systems.creature")
local Spawner = require("systems.spawner")
local system = Creatures.new()
local spawner = Spawner.new(system, {pool = {{id = "brawny_ogre"}}, speed = 60, scale = 2})
local ogre = spawner:spawnOne(0, 0)
assert(ogre.health == 4 and ogre.speed == 32 and ogre.scale == 3)
assert(ogre.attack.damage == 5 and ogre.attack.cooldown == 1.8)
ogre.position = vector(0, 0)
local target = {position = vector(10000, 0), health = 100,
  takeDamage = function(self, damage) self.health = self.health - damage end}
local context = {knight = target}
system:update(2, context)
assert(ogre.position.x == 64)
system:update(0.5, context)
assert(ogre.position.x == 64 and ogre.velocity:len() == 0, "Ogre rests between pursuits")
system:update(0.5, context)
system:update(1, context)
assert(ogre.position.x == 96, "Ogre resumes chasing")
local second = system:create("brawny_ogre", 0, 0)
assert(not second.pursuitTime, "Movement state is per creature")
local long = Creatures.new()
local other = long:create("brawny_ogre", 0, 0)
long:update(4, context)
assert(other.position.x == ogre.position.x, "Walk/rest travel is independent of frame subdivision")
target.position = vector(other.position.x, 0)
long:update(0, context)
assert(target.health == 95, "Ogre deals melee damage")
long:update(0.5, context)
assert(target.health == 95, "Attack cooldown prevents repeated damage")
long:update(1.3, context)
assert(target.health == 90)
local phase = other.pursuitTime
long:applyKnockback(other, vector(-1, 0), 20, 1)
long:update(0.5, context)
assert(other.pursuitTime == phase and target.health == 90, "Knockback interrupts movement and attacks")
long:damage(other, 1)
assert(other.health == 3 and #long:getAll() == 1, "Ogre survives one knight hit")
long:damage(other, 3)
assert(#long:getAll() == 0)
local custom = system:create("brawny_ogre", 0, 0, {health = 9, speed = 12})
assert(custom.health == 9 and custom.speed == 12, "Explicit options override ogre defaults")
print("Ogre tests passed: real asset, spawn defaults, walk/rest cycle, frame timing, independent state, damage and knockback")

-- Creature weight scales distance and initial speed independently.
for _, tuning in ipairs({
  {"brawny_ogre", 0.35, 0.5}, {"death_slime", 0.85, 0.9},
  {"ochre_jelly", 0.85, 0.9}, {"bloodshot_eye", 1.2, 1.15},
}) do
  local pushed = Creatures.new()
  local creature = pushed:create(tuning[1], 0, 0)
  pushed:applyKnockback(creature, vector(1, 0), 180, 0.25)
  assert(math.abs(creature.knockback.distance - 180*tuning[2]) < 1e-7)
  assert(math.abs(creature.knockback.distance/creature.knockback.duration - 720*tuning[3]) < 1e-7)
  pushed:update(creature.knockback.duration, {})
  assert(math.abs(creature.position.x - 180*tuning[2]) < 1e-7)
end
local heavySystem = Creatures.new()
local heavy = heavySystem:create("brawny_ogre", 0, 0)
local light = heavySystem:create("death_slime", 0, 0)
local hitCount = 0
local wallContext = {
  knight = {position = vector(100, 0), takeDamage = function() hitCount = hitCount + 1 end},
  resolveKnockback = function(creature, destination)
    if destination.x >= 100 then return vector(100, 0), true end
    return destination, false
  end,
}
heavySystem:applyKnockback(heavy, vector(1, 0), 180, 0.25)
heavySystem:applyKnockback(light, vector(1, 0), 180, 0.25)
heavySystem:update(0.25, wallContext)
assert(heavy.health == 4 and light.health == 0 and #heavySystem:getAll() == 1,
  "The same kick reaches the wall for slime but not for ogre")
assert(hitCount == 0, "Fatal wall impacts cannot attack or chase during leftover frame time")
local another = heavySystem:create("brawny_ogre", 0, 0)
heavy.knockbackResponse.distanceMultiplier = 0
assert(another.knockbackResponse.distanceMultiplier == 0.35, "Responses are owned by each creature")
assert(not heavySystem:applyKnockback(heavy, vector(1, 0), 180, 0.25))
print("Knockback weight tests passed: travel, speed, per-creature tuning, wall reach and fatal impact interruption")

local giants = Creatures.new()
local giantSpawner = Spawner.new(giants, {pool = {{id = "humongous_ettin"}}, speed = 60, scale = 2})
local giant = giantSpawner:spawnOne(0, 0)
assert(giant.health == 10 and giant.speed == 24 and giant.scale == 4)
assert(giant.attack.damage == 10 and giant.attack.range == 40 and giant.attack.cooldown == 2.2)
giant.position = vector(0, 0)
local distantKnight = {position = vector(1000, 0)}
giants:update(2, {knight = distantKnight})
assert(giant.position.x == 48)
giants:update(1, {knight = distantKnight})
assert(giant.position.x == 48, "Ettin shares the ogre rest cycle")
local victim = {position = giant.position:clone(), health = 100,
  takeDamage = function(self, amount) self.health = self.health - amount end}
giants:update(0, {knight = victim})
assert(victim.health == 90)
giants:update(1, {knight = victim})
assert(victim.health == 90, "Heavy attacks retain their longer cooldown")
giants:damage(giant, 4)
assert(giant.health == 6 and #giants:getAll() == 1, "Ettin survives damage that kills a normal ogre")
giants:applyKnockback(giant, vector(1, 0), 180, 0.25)
local near = function(a, b) assert(math.abs(a-b) < 1e-7) end
near(giant.knockback.distance, 32.4)
near(giant.knockback.distance/giant.knockback.duration, 216)
print("Two-headed ogre tests passed: spawn defaults, stronger stats, rest cycle, melee cooldown and heavier knockback")

local impacts = Creatures.new()
local survivor = impacts:create("ochre_jelly", 0, 0)
assert(survivor.health == 2 and impacts:create("death_slime", 1000, 0).health == 1)
local wall = {resolveKnockback = function(creature) return creature.position, true end}
impacts:applyKnockback(survivor, vector(1, 0), 180, 0.25)
impacts:update(0.05, wall)
assert(survivor.health == 1, "Wall impact deals one damage")
impacts:update(0.05, wall)
impacts:update(0.2, wall)
assert(survivor.health == 1, "A blocked kick cannot repeatedly deal impact damage")
impacts:applyKnockback(survivor, vector(1, 0), 180, 0.25)
impacts:update(0.3, wall)
assert(survivor.health == 0 and #impacts:getAll() == 1, "A second kick can finish the jelly")
local tough = impacts:create("humongous_ettin", 0, 0)
impacts:applyKnockback(tough, vector(1, 0), 180, 0.25)
impacts:update(0.3, wall)
assert(tough.health == 9, "Ogres also take one damage, not an instant kill")
print("Wall damage tests passed: one damage per kick, surviving impacts, repeat kicks and tougher jellies")
