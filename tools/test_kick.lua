-- Run from the repository root: luajit tools/test_kick.lua
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
    newShader = function() return {hasUniform = function() return true end,
      send = noop, release = noop} end,
    getDPIScale = function() return 1 end,
    newCanvas = function(w, h) return {setFilter = noop, setWrap = noop, release = noop,
      getPixelDimensions = function() return w, h end} end,
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

local vector = require("lib.hump.vector")
local Player = require("src.player")
local Kick = require("src.kick")
local CreatureSystem = require("systems.creature")
local behavior = require("behavior")
local MapSystem = require("systems.map")
local Structure = require("src.structure")
local HC = require("lib.HC")
local function near(actual, expected, message)
  assert(math.abs(actual - expected) < 1e-7, (message or "Mismatch") .. ": " .. actual .. " ~= " .. expected)
end
local function count(values)
  local n = 0
  for _ in pairs(values) do n = n + 1 end
  return n
end

local healResource = require('src.heal_resource').new(100, 0)
healResource:add(100)
local player, creatures = Player.new(0, 0), CreatureSystem.new()
local monster = creatures:create("death_slime", 40, 0)
keys.f = true
Player.update(player, 0, healResource)
assert(Player.resolveKick(player, creatures) and monster.knockback)
assert(monster.health == 1 and player.kick.cooldownRemaining == 0.65)
assert(not Player.resolveKick(player, creatures), "One request is consumed once")
Player.update(player, 1, healResource)
assert(not Player.resolveKick(player, creatures), "Holding never repeats after cooldown")
keys = {}; Player.update(player, 0, healResource)
keys.f = true; Player.update(player, 0, healResource)
assert(Player.resolveKick(player, creatures), "Release rearms the action")
keys = {}; Player.update(player, 0.1, healResource)
keys.f = true; Player.update(player, 0.1, healResource)
assert(not Player.resolveKick(player, creatures), "Early presses are discarded")
Player.update(player, 1, healResource)
assert(not Player.resolveKick(player, creatures), "No queued kick when cooldown expires")

keys = {a = true, up = true}
Player.update(player, 0, healResource)
assert(player.kickDirection == vector(0, -1), "Healing aim wins over movement")
keys = {s = true}; Player.update(player, 0, healResource)
assert(player.kickDirection == vector(0, 1), "Movement is the fallback")
keys = {}; Player.update(player, 0, healResource)
assert(player.kickDirection == vector(0, 1), "Idle preserves the last direction")

player = Player.new(0, 0)
axes = {triggerleft = 0.24}
Player.update(player, 0, healResource)
assert(not Player.resolveKick(player, creatures), "Trigger noise below deadzone is ignored")
axes = {triggerleft = 0.8, triggerright = 0.8, righty = -1, leftx = 1}
Player.update(player, 0.01, healResource)
assert(Player.resolveKick(player, creatures), "Actual Baton gamepad mapping fires")
assert(player.currentBeam and player.currentBeam.isActive, "Kick and heal can run together")
assert(player.x > 0 and player.kick.direction == vector(0, -1))
near(player.kick.origin.x, player.x, "Kick uses the latest position")
Player.update(player, 1, healResource)
assert(not Player.resolveKick(player, creatures), "Held analog trigger never repeats")
axes.triggerleft = 0; Player.update(player, 0, healResource)
axes.triggerleft = 1; Player.update(player, 0, healResource)
assert(Player.resolveKick(player, creatures))
axes = {}; keys = {}

creatures = CreatureSystem.new()
local positions = {{80, 0, true}, {40, 40, true}, {0, 0, true},
  {80.01, 0, false}, {40, 40.01, false}, {-10, 0, false}, {0, 20, false}}
for _, p in ipairs(positions) do creatures:create("death_slime", p[1], p[2]) end
local kick = Kick.new()
assert(kick:tryActivate(0, 0, vector(7, 0), creatures))
for i, creature in ipairs(creatures:getAll()) do
  assert((creature.knockback ~= nil) == positions[i][3], "Arc/range case " .. i)
  assert(creature.health == 1)
end
local effect = kick.effectRemaining
kick:draw(); kick:drawStatus(24, 48); creatures:draw()
assert(kick.effectRemaining == effect, "Rendering never advances effects")
local miss = Kick.new()
assert(miss:tryActivate(1000, 1000, vector(1, 0), creatures))
assert(miss.cooldownRemaining == Kick.tuning.cooldown, "A miss also consumes cooldown")

local function travel(steps)
  local system = CreatureSystem.new()
  local creature = system:create("death_slime", 0, 0, {speed = 40, movementBehavior = behavior.chase})
  system:applyKnockback(creature, vector(1, 0), 180, 0.25)
  for _, dt in ipairs(steps) do system:update(dt, {knight = {position = vector(-1000, 0)}}) end
  return creature
end
near(travel({0.25}).position.x, 180)
near(travel({0.05, 0.05, 0.05, 0.05, 0.05}).position.x, 180)
near(travel({0.5}).position.x, 170, "Chase consumes only post-knockback time")
near(travel({0.1, 0.1, 0.3}).position.x, 170)
near(travel({0}).position.x, 0)
local interruptions = CreatureSystem.new()
local blocked = interruptions:create("death_slime", 0, 0, {speed = 60, movementBehavior = behavior.chase})
local hits, resolutions = 0, 0
local context = {
  knight = {position = vector(0, 0), takeDamage = function() hits = hits + 1 end},
  resolveKnockback = function(creature)
    resolutions = resolutions + 1
    return creature.position, true
  end,
}
interruptions:applyKnockback(blocked, vector(1, 0), 180, 0.25)
interruptions:update(0, context)
interruptions:update(0.1, context)
assert(hits == 0 and blocked.knockback.blocked)
interruptions:update(0.15, context)
assert(hits == 0 and resolutions == 1 and not blocked.knockback,
  "Pillar impact stops travel but preserves the full attack interruption")
interruptions:update(0.01, context)
assert(hits == 1 and blocked.health == 1, "Normal attacks resume without kick damage")

-- Controlled pillars in real streamed chunks and HC geometry.
local map = MapSystem.new()
map.createStructures = function() return {} end
map:update(0, 0, 960, 540)
local pillar = Structure.new("pillar_round", 100, 0, 4, map.structureSystem.world)
map.chunks["0:0"].structures[1] = pillar
local visible, chunks, shapes = map.visible, count(map.chunks), count(map.structureSystem.world:hash():shapes())
local position, hit = map:resolveKnockback(vector(0, -10), vector(300, -10), 12)
assert(hit); near(position.x, 68)
local probe = require("lib.HC.shapes").newCircleShape(position.x, position.y, 12)
assert(not probe:collidesWith(pillar.shape), "Long-frame sweep cannot tunnel through a pillar")
position, hit = map:resolveKnockback(vector(0, -50), vector(300, 50), 12)
assert(hit and position.x < 100 and position.y < 0, "Diagonal knockback stops at first contact")
position, hit = map:resolveKnockback(vector(100, -10), vector(300, -10), 12)
probe:moveTo(position.x, position.y)
assert(hit and not probe:collidesWith(pillar.shape), "Initial overlap is separated")
assert(map.visible == visible and count(map.chunks) == chunks)
assert(count(map.structureSystem.world:hash():shapes()) == shapes, "Probes are not registered")

-- Crossing into unloaded geometry must neither evict nor recenter visible chunks.
map.createStructures = function(self, chunk)
  if chunk.chunkX == 4 and chunk.chunkY == 0 then
    return {Structure.new("pillar_round", 2080, 64, 4, self.structureSystem.world)}
  end
  return {}
end
position, hit = map:resolveKnockback(vector(1990, 50), vector(2200, 50), 12)
assert(hit); near(position.x, 2048)
assert(map.visible == visible and map.chunks["0:0"] and map.chunks["4:0"])
map:update(0, 0, 960, 540)
assert(count(map.chunks) == chunks and not map.chunks["4:0"], "Extra geometry is reclaimed")
local before = count(HC.hash():shapes())
for _ = 1, 30 do map:resolveKnockback(vector(0, -10), vector(300, -10), 12) end
assert(count(HC.hash():shapes()) == before)
assert(count(map.structureSystem.world:hash():shapes()) == shapes)
map:destroy()
assert(next(map.structureSystem.world:hash():shapes()) == nil)
local emptyMap = MapSystem.new({structures = false})
position, hit = emptyMap:resolveKnockback(vector(0, 0), vector(180, 0), 12)
assert(position == vector(180, 0) and not hit)
emptyMap:destroy()

-- Drive the shipped game callbacks, with real player, knight, map and creatures.
dofile("game/main.lua")
local GS = require("gamestate.deps").Gamestate
love.load(); love.update(0); love.keypressed("return"); love.update(0)
local game = require("gamestate.game")
game.spawner:setEnabled(false)
game.pickups:destroy(); game.pickups.batchSize = 0
game.knight.attackCooldown = 10
game.knight.idleTimer = 100
game.creatures = CreatureSystem.new()
local threat = game.creatures:create("death_slime", 10, 0, {speed = 60, movementBehavior = behavior.chase})
local hp = game.knight.health
keys = {f = true, right = true}
love.update(0.01)
assert(threat.knockback and threat.position.x > 10 and game.knight.health == hp,
  "Kick interrupts an in-range attacker in the same game frame")
assert(threat.health == 1)
local cooldown, remaining, at = game.player.kick.cooldownRemaining,
  game.player.kick.effectRemaining, threat.position:clone()
love.keypressed("escape"); love.update(2); love.draw()
assert(game.player.kick.cooldownRemaining == cooldown and game.player.kick.effectRemaining == remaining)
assert(threat.position == at, "Pause freezes knockback and effect timers")
love.keypressed("return"); love.update(0)
assert(GS.current() == game and not game.player.kickRequested)
love.update(1)
assert(game.player.kick.cooldownRemaining == 0, "Held trigger does not fire on resume")
keys = {}; love.update(0)
love.keypressed("escape"); love.update(0)
keys = {f = true}; love.keypressed("return"); love.update(0)
assert(game.player.kick.cooldownRemaining == 0, "Presses during pause do not queue")
keys = {}; love.update(0)
keys.f = true; love.update(0)
assert(game.player.kick.cooldownRemaining > 0, "Fresh press works after resume")

-- Place the healer beside a pillar and move into it during the kick frame.
keys = {}; love.update(1)
local obstruction = Structure.new("pillar_round", 100, 0, 4, game.map.structureSystem.world)
table.insert(game.map.chunks["0:0"].structures, obstruction)
game.player.x, game.player.y = 60, -10
game.player.shape:moveTo(60, -10)
game.creatures = CreatureSystem.new()
local justOutOfReach = game.creatures:create("death_slime", 146, -10)
keys = {f = true, d = true, right = true}; love.update(0.1)
near(game.player.x, 64)
near(game.player.kick.origin.x, 64, "Activation occurs after healer collision correction")
assert(not justOutOfReach.knockback, "Targeting uses corrected position")
love.draw()
local oldMap, oldKick = game.map, game.player.kick
love.keypressed("f2"); love.update(0)
assert(count(HC.hash():shapes()) == 0, "Leaving cleans up normal actor and pickup colliders")
assert(next(oldMap.structureSystem.world:hash():shapes()) == nil)
keys = {}; love.keypressed("return"); love.update(0)
assert(game.player.kick ~= oldKick and game.player.kick.cooldownRemaining == 0)
assert(game.player.kick.effectRemaining == 0 and game.player.kickDirection == vector(1, 0))
for _, creature in ipairs(game.creatures:getAll()) do assert(not creature.knockback) end
game:leave()
print("Kick tests passed: real keyboard/gamepad input, aim, healing, arc, interruption, frame timing, pillars, streaming, pause and restart")
