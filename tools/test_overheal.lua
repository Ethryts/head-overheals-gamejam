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


local Knight = require("src.knight")
local Player = require("src.player")
local knight = Knight.new(100, 200)
local bodies = {getAll = function() return {} end}
local player = {allBeams = {}, lastDrainAmount = 0}
knight.idleTimer = 100
local rectangles, lines, polygons, layers = {}, 0, 0, {}
love.graphics.rectangle = function(mode, x, y, w, h)
  rectangles[#rectangles+1] = {mode=mode, x=x, y=y, w=w, h=h}
end
love.graphics.line = function() lines = lines+1 end
love.graphics.polygon = function() polygons = polygons+1 end
love.graphics.draw = function(image, quad, x, y)
  layers[#layers+1] = {image=image,x=x,y=y}
end
local function draw(health)
  knight:setHealth(health)
  rectangles, lines, polygons, layers = {}, 0, 0, {}
  knight:draw()
end
draw(50)
assert(rectangles[2].w == 20, "Half normal max health fills half the bar")
draw(100)
assert(rectangles[2].w == 40 and #rectangles == 3, "Bar fills at normal max, without glow")
draw(125)
assert(rectangles[4].w == 40 and #rectangles == 5 and lines == 0, "Overheal adds glow, not extra fill")
assert(knight.animation.headScale == 3.75)
draw(149)
assert(lines == 0 and #knight.healthBar.shards == 0)
draw(150)
assert(lines > 0 and polygons == 4, "Cracks and glass start halfway to the overheal limit")
local shards, bursts = #knight.healthBar.shards, knight.healthBar.bursts
knight:setHealth(151)
assert(knight.healthBar.bursts == bursts, "Tiny healing ticks do not emit every frame")
knight:setHealth(155)
assert(#knight.healthBar.shards > shards and knight.healthBar.bursts == bursts+1)
knight:update(0.05, bodies, player)
knight:draw()
local x,y = knight.healthBar:headShake(false)
assert(x == 0 and y == 0, "An overhealed but unhealed head stays still")
local overlap = Player.doesBeamOverlapWithPoint
Player.doesBeamOverlapWithPoint = function() return true end
player.lastDrainAmount = 1
knight:update(0.05, bodies, player)
x,y = knight.healthBar:headShake(knight.healedThisUpdate)
assert(x ~= 0 or y ~= 0)
layers = {}
knight:draw()
assert(layers[1].x == knight.position.x and layers[1].y == knight.position.y, "Body stays anchored")
assert(layers[2].x == knight.position.x+x and layers[2].y == knight.position.y+y, "Only head shakes")
local time, age, count = knight.healthBar.time, knight.healthBar.shards[1].age, #knight.healthBar.shards
knight:draw(); knight:draw()
assert(knight.healthBar.time == time and knight.healthBar.shards[1].age == age and #knight.healthBar.shards == count,
  "Drawing during pause never animates or emits")
Player.doesBeamOverlapWithPoint = overlap
knight:update(0.1, bodies, player)
x,y = knight.healthBar:headShake(knight.healedThisUpdate)
assert(x == 0 and y == 0, "Shake stops when healing stops")
knight:takeDamage(20)
assert(knight.healthBar.overheal < 0.5)
knight.healthBar:update(1)
assert(#knight.healthBar.shards == 0, "Shards expire")
knight.stats.maxHealth = 200
knight:setHealth(299)
assert(knight.healthBar.overheal < 0.5)
knight:setHealth(300)
assert(knight.healthBar.overheal == 0.5 and knight.animation.headScale == 4.5,
  "Threshold follows upgraded max health")
for _=1,100 do knight:setHealth(300); knight:setHealth(390) end
assert(#knight.healthBar.shards <= 24)
knight:setHealth(400)
assert(knight.overhealed, "Fatal overheal remains unchanged")
print("Overheal tests passed: capped fill, glow, cracks, shard budget, head-only shake, pause and upgraded thresholds")
