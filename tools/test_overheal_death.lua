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
    newMesh = function() return {setVertices = noop, release = noop} end,
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
local knight = Knight.new(0, 0)
knight:setHealth(knight.stats.maxHealth*2)
assert(knight.dying and knight.state == "dying" and not knight.dead)
local position = knight.position:clone()
knight:update(0.99, {}, {})
assert(knight.position == position and not knight.headBurst and not knight.dead)
knight:heal(10); knight:takeDamage(10)
assert(knight.health == 200, "Dying knights cannot be healed or damaged")
knight:update(0.01, {}, {})
assert(knight.headBurst and #knight.headBurst.pieces == 16 and not knight.animation.headVisible)
assert(knight.dying and not knight.dead)
local burst = knight.headBurst
knight:draw(); knight:draw()
assert(knight.headBurst == burst and burst.age == 0, "Drawing never advances or repeats the pop")
knight:update(0.4, {}, {})
assert(knight.headBurst == burst and knight.dying)
knight:update(0.41, {}, {})
assert(knight.dead and not knight.dying and knight.state == "dead")
knight:setHealth(100)
assert(not knight.dead and not knight.dying and not knight.headBurst and knight.animation.headVisible,
  "Debug reset restores the head and clears death visuals")
knight:setHealth(200); knight:update(3, {}, {})
assert(knight.dead and knight.headBurst.age == Knight.overhealDeath.fragmentDuration,
  "Long frames cross thresholds once without extending the sequence")

-- Verify actual state transition, sound ownership, gameplay freeze and pause.
require("shader_config").enabled = false
dofile("game/main.lua")
local GS = require("gamestate.deps").Gamestate
love.load(); love.update(0); love.keypressed("return"); love.update(0)
local game = require("gamestate.game")
local sounds = GS.soundEffectsSystem
local play = sounds.playSoundEffect
local explosions, deaths = 0, 0
sounds.playSoundEffect = function(self, name, ...)
  if name == "HeadOverhealed" then explosions = explosions+1 end
  if name == "Death" then deaths = deaths+1 end
  return play(self, name, ...)
end
local timer, spawned, x = game.timer, game.spawner.elapsed, game.player.x
game.knight:setHealth(game.knight.stats.maxHealth*2)
love.update(0.4)
assert(GS.current() == game and game.knight.dying and explosions == 1)
assert(game.timer == timer and game.spawner.elapsed == spawned and game.player.x == x)
love.keypressed("escape"); love.update(2); love.draw()
assert(game.knight.deathElapsed == 0.4, "Pause freezes dying animation")
love.keypressed("return"); love.update(0)
love.update(0.6); love.draw()
assert(GS.current() == game and game.knight.headBurst and not game.knight.dead)
love.update(0.4); love.draw()
assert(GS.current() == game and explosions == 1)
love.update(0.41)
assert(GS.current() == require("gamestate.endscreen") and game.knight.dead)
assert(explosions == 1 and deaths == 0, "Overheal uses one explosion, never a second death sound")
assert(GS.current().result.title == "Overhealed")
love.update(0); love.keypressed("return"); love.update(0)
assert(not game.knight.dying and not game.knight.headBurst and game.knight.animation.headVisible ~= false)
game:leave()
print("Overheal death tests passed: buildup, sprite fracture, timing, sound once, pause, gameplay freeze and restart")
