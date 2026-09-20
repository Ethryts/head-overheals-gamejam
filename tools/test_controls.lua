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


dofile("game/main.lua")
local GS = require("gamestate.deps").Gamestate
local menu = require("gamestate.menu")
local game = require("gamestate.game")
local pause = require("gamestate.pause")
local help = require("gamestate.help")
local ends = require("gamestate.endscreen")
love.load()
local function tick() love.update(0); love.draw() end
local function press(button) love.gamepadpressed(joystick, button); tick() end
tick()
press("dpup")
assert(menu.ui.navigation.selected == 4)
press("a"); tick()
assert(GS.current() == help, "A opens Help")
press("b"); tick()
assert(GS.current() == menu)
local scene = menu.scene
local volume
love.audio.setVolume = function(value) volume = value end
press("dpdown"); press("a"); tick()
assert(GS.current() == require("gamestate.settings"))
press("a")
assert(math.abs(volume - 0.9) < 1e-7, "Settings volume is functional")
press("b"); tick()
assert(menu.scene == scene, "Returning from a page preserves the chamber")
press("dpdown"); press("dpdown"); press("a"); tick()
assert(GS.current() == require("gamestate.credits"))
press("b"); tick()
love.gamepadaxis(joystick, "lefty", 0.2)
assert(menu.ui.navigation.selected == 1, "Stick drift does not move selection")
love.gamepadaxis(joystick, "lefty", 0.8)
assert(menu.ui.navigation.selected == 2)
love.gamepadaxis(joystick, "lefty", 0.9)
assert(menu.ui.navigation.selected == 2, "Held axis does not repeat for every event")
love.gamepadaxis(joystick, "lefty", 0)
love.gamepadaxis(joystick, "lefty", -0.8)
assert(menu.ui.navigation.selected == 1)
press("a"); tick()
assert(GS.current() == game)
press("start"); tick()
assert(GS.current() == pause)
local timer = game.timer
press("dpdown"); press("dpdown"); press("a"); tick()
assert(GS.current() == help and game.timer == timer, "Help preserves paused game")
press("start"); tick()
assert(GS.current() == game, "Start resumes through pause Help")
press("start"); tick(); press("b"); tick()
assert(GS.current() == game, "B resumes pause")
love.keypressed("f2"); tick()
assert(GS.current() == ends)
press("dpdown"); press("a"); tick()
assert(GS.current() == menu, "Endscreen Main menu selection")
press("a"); tick()
love.keypressed("f2"); tick(); press("a"); tick()
assert(GS.current() == game, "Endscreen replay")
love.keypressed("f3"); tick()
local debug = GS.current()
press("dpdown"); press("a"); tick()
assert(debug.activeTest and not debug.menuOpen)
local health = game.knight.health
press("a")
assert(game.knight.health == health-1, "Debug health buttons support controllers")
press("b"); tick()
assert(debug.menuOpen)
press("b"); tick()
assert(GS.current() == game)

-- Exercise real player beam/kick input at nonzero world coordinates and a scaled viewport.
local mx, my, left, right = 1200, 540, false, false
love.mouse.getPosition = function() return mx, my end
love.mouse.isDown = function(button) return button == 1 and left or button == 2 and right end
love.graphics.getDimensions = function() return 1920, 1080 end
local Player = require("src.player")
local resource = require("src.heal_resource").new(100, 0)
resource:add(100)
local player = Player.new(-900, 600)
left = true
Player.update(player, 0.05, resource)
assert(player.currentBeam and player.currentBeam.direction.x == 1 and player.currentBeam.direction.y == 0,
  "Mouse uses camera-relative aim, not player world coordinates")
mx, my = 960, 200
Player.update(player, 0.01, resource)
assert(player.currentBeam.direction.y == -1, "Held click tracks mouse aim")
right = true
Player.update(player, 0.01, resource)
assert(player.kickRequested and player.kickDirection.y == -1)
Player.update(player, 0.01, resource)
assert(not player.kickRequested, "Held right click never repeats a kick")
left, right = false, false
Player.update(player, 0.01, resource)
assert(not player.currentBeam)
left, right = true, true
Player.resume(player)
Player.update(player, 0.01, resource)
assert(not player.currentBeam and not player.kickRequested, "Pause presses do not leak into gameplay")
left, right = false, false
Player.update(player, 0.01, resource)
left, right = true, true
Player.update(player, 0.01, resource, true)
assert(not player.currentBeam and not player.kickRequested, "Interactive HUD clicks cannot attack")
Player.update(player, 0.01, resource)
assert(not player.currentBeam, "Dragging a blocked click into the world does not heal")
left, right = false, false
Player.update(player, 0.01, resource)
love.graphics.getDimensions = function() return 1920, 1200 end
my = 10
left, right = true, true
Player.update(player, 0.01, resource)
assert(not player.currentBeam and not player.kickRequested, "Letterbox clicks cannot attack")
game:leave()
print("Controls tests passed: menu traversal, Help, pause, debug, stick deadzone, mouse aim, scaling and click isolation")
