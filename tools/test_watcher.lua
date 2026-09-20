-- Run from the repository root: luajit tools/test_watcher.lua
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

local movement = require("behavior.watcher")
local function near(a, b) assert(math.abs(a-b) < 1e-7, a .. " ~= " .. b) end
local system = Creatures.new()
local spawner = Spawner.new(system, {pool = {{id = "ocular_watcher"}}, speed = 60})
local eye = spawner:spawnOne(0, 0)
assert(eye.kind == "ocular_watcher" and eye.speed == 55 and eye.attack.type == "ranged")
assert(eye.movementBehavior == movement)
eye.position = vector(0, 0)
local bursts, shots = 0, 0
local context = {
  knight = {position = vector(220, 0), health = 100, takeDamage = noop},
  healer = {position = vector(-20, 0)},
  fx = {emit = function(_, name, x, y, options)
    assert(name == "dodge"); bursts = bursts + 1
    assert(options.depth == y+16)
  end},
  projectiles = {spawn = function(_, options)
    assert(options.owner == eye and options.damage == 1)
    shots = shots + 1
    return {}
  end},
}
system:update(0, context)
assert(bursts == 0, "No dash or FX while paused")
system:update(0.09, context)
near(eye.position.x, 32); near(eye.position.y, 0)
assert(bursts == 1 and shots == 1)
context.healer.position = vector(100, 0)
system:update(0.09, context)
near(eye.position.x, 64)
assert(bursts == 1, "Dash locks its direction and emits once")
system:update(0.1, context)
assert(bursts == 1 and eye.velocity:len() <= eye.speed+1e-7, "Cooldown returns to normal orbit speed")
assert(eye.velocity.y ~= 0, "Orbit differs from the stationary bloodshot eye")
context.healer.position = eye.position:clone()
system:update(2.2, context)
assert(bursts == 2 and eye.position.x == eye.position.x, "Dash recharges and handles overlapping targets")
local fresh = Creatures.new()
local other = fresh:create("ocular_watcher", 0, 0)
fresh:update(0.5, {healer = {position = vector(-10, 0)}})
near(other.position.x, 64)
assert(other.watcher ~= eye.watcher, "Dash state is per creature")
local stopped = other.position:clone()
fresh:update(0.1, {})
assert(other.position == stopped, "Missing targets are safe")

-- Actual pillar sweep clips the voluntary dash without killing the watcher.
local world = require("systems.structure").new()
local pillar = world.world:rectangle(40, -30, 20, 60)
pillar.structure = {x = 50, y = 30}
local wallSystem = Creatures.new()
local wallEye = wallSystem:create("ocular_watcher", 0, 0)
wallSystem:update(0.18, {
  healer = {position = vector(-10, 0)},
  resolveMovement = function(creature, destination)
    local actor = {x = destination.x, y = destination.y,
      shape = require("lib.HC.shapes").newCircleShape(creature.position.x, creature.position.y, 12)}
    world:resolveMovement(actor, creature.position.x, creature.position.y, noop, true)
    return vector(actor.x, actor.y)
  end,
})
assert(wallEye.position.x < 40 and wallEye.health == 1 and not wallEye.knockback)
local interrupted = Creatures.new()
local kicked = interrupted:create("ocular_watcher", 0, 0)
interrupted:update(0.05, {healer = {position = vector(-10, 0)}})
assert(kicked.watcher.remaining > 0)
interrupted:applyKnockback(kicked, vector(-1, 0), 50, 0.25)
assert(kicked.watcher.remaining == 0, "A kick cancels the dash")
local before = kicked.position.x
interrupted:update(0.05, {healer = {position = vector(-10, 0)}})
assert(kicked.position.x < before, "Dash cannot override knockback")
local schedule = require("src.difficulty")
for _, stage in ipairs(schedule) do
  local found = false
  for _, entry in ipairs(stage.pool) do if entry.id == "ocular_watcher" then found = true end end
  assert(found == (stage.at >= 60), "Watcher only joins later stages")
end
print("Watcher tests passed: alternate sprite, ranged attacks, orbit, dash timing, FX, cooldown, walls and kick interruption")
