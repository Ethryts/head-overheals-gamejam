-- Run from the repository root: lua tools/test_creatures.lua
-- Real anim8/HUMP/state code, with graphics and input stubbed for headless use.
unpack = unpack or table.unpack
package.path = "game/?.lua;game/?/init.lua;game/src/?.lua;" .. package.path

local function noop() end
local font = {
  getWidth = function(_, text) return #text * 9 end,
  getHeight = function() return 18 end,
}
local imageLoads, draws = 0, {}
local function read32(data, offset)
  local a, b, c, d = data:byte(offset, offset + 3)
  return ((a * 256 + b) * 256 + c) * 256 + d
end
love = {
  handlers = {},
  filesystem = {
    getRequirePath = function() return package.path end,
    setRequirePath = function(path) package.path = path end,
  },
  graphics = setmetatable({
    newImage = function(path)
      local file = assert(io.open("game/" .. path, "rb"))
      local header = file:read(24)
      file:close()
      local width, height = read32(header, 17), read32(header, 21)
      assert(width == 64 and height == 16, path)
      imageLoads = imageLoads + 1
      return {
        getWidth = function() return width end,
        getHeight = function() return height end,
        setFilter = function(_, min, mag)
          assert(min == "nearest" and mag == "nearest")
        end,
      }
    end,
    newQuad = function(x, y, w, h)
      assert(w == 16 and h == 16 and y == 0 and x >= 0 and x <= 48)
      return {getViewport = function() return x, y, w, h end}
    end,
    draw = function(...) draws[#draws + 1] = {...} end,
    newFont = function() return font end,
    getFont = function() return font end,
    getDimensions = function() return 960, 540 end,
  }, {__index = function() return noop end}),
  mouse = {
    getPosition = function() return 0, 0 end,
    getX = function() return 0 end,
    getY = function() return 0 end,
    isDown = function() return false end,
  },
  system = {getOS = function() return "Linux" end},
}

local CreatureSystem = require("systems.creature")
local first, second = CreatureSystem.new(), CreatureSystem.new()
local a = first:create("death_slime", 10, 20, {health = 10, speed = 40, scale = 4})
local b = second:create("death_slime", 30, 40)
assert(imageLoads == 1 and a.image == b.image)
assert(a.health == 10 and a.speed == 40 and a.scale == 4)
assert(b.health == 1 and b.speed == 0 and b.scale == 1 and b.attack == nil)
assert(a.position ~= b.position and not rawequal(a.velocity, b.velocity))
a.velocity.x = 8
a.position.x = 12
assert(b.velocity.x == 0 and b.position.x == 30)
first:update(0.21)
assert(a.animations.idle.position == 2 and b.animations.idle.position == 1)
a.animations.idle:flipH()
assert(not b.animations.idle.flippedH)
a.animations.idle:flipH()
first:update(0.6)
assert(a.animations.idle.position == 1)
local c = first:create("red_cap", 50, 60, {frameDuration = 0.1})
assert(a.animations.idle.timer > 0 and c.animations.idle.timer == 0)
first:update(0.11)
assert(c.animations.idle.position == 2)
local beforeDraw = a.animations.idle.timer
first:draw()
assert(a.animations.idle.timer == beforeDraw and #draws == 2)
assert(draws[1][1] == a.image and draws[2][1] == c.image)
assert(draws[1][3] == 12 and draws[1][4] == 20 and draws[1][6] == 4)
second:draw()
assert(#draws == 3)
local ok, message = pcall(first.create, first, "missing", 0, 0)
assert(not ok and message:find("Unknown monster ID: missing", 1, true))

local catalog = CreatureSystem.new()
for _, id in ipairs({
  "blinded_grimlock", "bloodshot_eye", "brawny_ogre", "crimson_slaad",
  "crushing_cyclops", "death_slime", "fungal_myconid", "humongous_ettin",
  "murky_slaad", "ochre_jelly", "ocular_watcher", "red_cap",
  "shrieker_mushroom", "stone_troll", "swamp_troll",
}) do
  local creature = catalog:create(id, 0, 0)
  assert(#creature.animations.idle.frames == 4)
end
assert(imageLoads == 15)

dofile("game/main.lua")
local GS = require("gamestate.deps").Gamestate
local game = require("gamestate.game")
love.load()
love.update(0)
love.keypressed("return")
love.update(0.21)
local run = game.creatures
draws = {}
love.draw()
local frame = draws[1][2]
love.keypressed("escape")
love.update(2)
draws = {}
love.draw()
assert(draws[1][2] == frame and game.creatures == run)
love.keypressed("return")
love.update(0.21)
draws = {}
love.draw()
assert(draws[1][2] ~= frame and game.creatures == run)
love.keypressed("f2")
love.update(0)
love.keypressed("return")
love.update(0)
assert(GS.current() == game and game.creatures ~= run)
draws = {}
love.draw()
local x = draws[1][2]:getViewport()
assert(x == 0, "New run starts at frame one")
print("CreatureSystem tests passed: catalog, isolation, playback, drawing, pause, restart")
