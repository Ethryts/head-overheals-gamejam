-- Run from the repository root: luajit tools/test_demo.lua
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


require("shader_config").enabled = false
dofile("game/main.lua")
local GS = require("gamestate.deps").Gamestate
local Demo = require("debug.demo")
local debugState = require("gamestate.debug")
local game = require("gamestate.game")
love.load()
love.keypressed("f3"); debugState:selectTest(Demo)
local panel = debugState.activeTest
assert(not panel.game)
panel:startGame()
panel = debugState.activeTest
assert(GS.current() == debugState and panel.game == game)
assert(game.demo and not game.demo.autoSpawn and not require("debug.hud").visible)
local elapsed = game.timer
love.update(2); love.draw()
assert(game.timer == elapsed, "Staging does not advance the real game")
-- Activate actual stat buttons through controller navigation.
local hp = game.knight.health
panel.ui.navigation.selected = 6
local UI = require("gamestate.ui")
UI.gamepadpressed(panel.ui, "a")
love.update(0)
assert(game.knight.health == hp+5, "Knight health uses the real setter")
-- Camera conversion and spread around a player away from the world origin.
game.player.x, game.player.y = 700, -300
panel:clearEnemies()
panel.settings.count = 5
panel:mousepressed(700, 270, 1)
local x, y = 0, 0
for _, creature in ipairs(game.creatures:getAll()) do
  x, y = x+creature.position.x, y+creature.position.y
end
assert(#game.creatures:getAll() == 5)
assert(game.creatures:getAll()[1].speed > 0, "Staged slimes use gameplay movement defaults")
assert(math.abs(x/5-920) < 0.001 and math.abs(y/5+300) < 0.001)
panel:mousepressed(200, 270, 1); panel:mousepressed(700, 270, 2)
assert(#game.creatures:getAll() == 5, "UI and right clicks do not spawn")
for i = 1, 6 do
  panel.settings.creature = i
  panel.settings.count = 1
  panel:mousepressed(750, 300, 1)
end
assert(#game.creatures:getAll() == 11, "Every creature can be staged")
panel.settings.tool = "knight"
panel:mousepressed(700, 270, 1)
assert(game.knight.position.x == 920 and game.knight.patrolAnchor.x == 920)
panel.settings.tool = "healer"
panel:mousepressed(700, 270, 1)
assert(game.player.x == 920 and game.player.y == -300)
local sx, sy = game.player.shape:center()
assert(sx == 920 and sy == -300, "Healer collision moves with its sprite")
panel:clearEnemies()
assert(#game.creatures:getAll() == 0 and #game.projectiles.projectiles == 0)
local spawnTime = game.spawner.elapsed
panel:play()
assert(GS.current() == game and not require("debug.hud").visible)
love.update(0.1)
assert(game.timer > elapsed and game.spawner.elapsed == spawnTime)
game.demo.autoSpawn = true
love.update(0.1)
assert(game.spawner.elapsed > spawnTime, "Auto spawning can resume")
game.demo.hideHud = true
local drawn = 0
local draw = game.hud.draw
game.hud.draw = function() drawn = drawn+1 end
game:drawUI(); assert(drawn == 0)
game.demo.hideHud = false
game:drawUI(); assert(drawn == 1)
game.hud.draw = draw
love.keypressed("escape"); love.keypressed("f3")
debugState:selectTest(Demo)
panel = debugState.activeTest
assert(panel.settings == game.demo and panel.settings.autoSpawn)
panel:play()
assert(GS.current() == game, "Play demo also closes an underlying pause menu")
GS.switch(require("gamestate.menu"))
GS.switch(game)
assert(game.demo == nil, "Demo settings never leak into a fresh normal run")
game:leave()
print("Demo tests passed: menu entry, frozen staging, stat controls, camera placement, all creatures, resume, HUD and lifecycle")
