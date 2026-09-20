-- Run from the repository root: lua tools/test_creatures.lua
-- Real anim8/HUMP/state code, with graphics and input stubbed for headless use.
unpack = unpack or table.unpack
package.path = "game/?.lua;game/?/init.lua;game/src/?.lua;game/src/?/init.lua;" .. package.path

local function noop() end
local font = {setFilter = function() end,
  getWidth = function(_, text) return #text * 9 end,
  getHeight = function() return 18 end,
}
local imageLoads, draws = 0, {}
local windowWidth, windowHeight = 960, 540
local mouseX, mouseY, mouseDown = 0, 0, false
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
    newShader = function() return {hasUniform = function() return true end,
      send = noop, release = noop} end,
    getDPIScale = function() return 1 end,
    newCanvas = function(w, h) return {setFilter = noop, setWrap = noop, release = noop,
      getPixelDimensions = function() return w, h end} end,
    newImage = function(path)
      local file = assert(io.open("game/" .. path, "rb"))
      local header = file:read(24)
      file:close()
      local width, height = read32(header, 17), read32(header, 21)
      assert((width == 64 and height == 16) or (width == 152 and height == 112), path)
      imageLoads = imageLoads + 1
      return {
        isUi = width == 152 and height == 112,
        getWidth = function() return width end,
        getHeight = function() return height end,
        setFilter = function(_, min, mag)
          assert(min == "nearest" and mag == "nearest")
        end,
      }
    end,
    newQuad = function(x, y, w, h, sw, sh)
      assert((w == 16 and h == 16 and y == 0 and x >= 0 and x <= 48)
        or (sw == 152 and sh == 112 and x + w <= sw and y + h <= sh))
      return {getViewport = function() return x, y, w, h end}
    end,
    draw = function(image, ...)
      if not image.isUi then draws[#draws + 1] = {image, ...} end
    end,
    newFont = function() return font end,
    getFont = function() return font end,
    getDimensions = function() return windowWidth, windowHeight end,
  }, {__index = function() return noop end}),
  mouse = {
    getPosition = function() return mouseX, mouseY end,
    getX = function() return mouseX end,
    getY = function() return mouseY end,
    isDown = function() return mouseDown end,
  },
  system = {getOS = function() return "Linux" end},
}

local CreatureSystem = require("systems.creature")
local first, second = CreatureSystem.new(), CreatureSystem.new()
local a = first:create("death_slime", 10, 20, {health = 10, speed = 40, scale = 4})
local b = second:create("death_slime", 30, 40)
assert(imageLoads == 1 and a.image == b.image)
assert(a.health == 10 and a.speed == 40 and a.scale == 4)
assert(b.health == 1 and b.speed == 0 and b.scale == 1)
assert(b.attack.type == "melee" and b.attack.damage == 1 and b.attack.range == 24)
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
assert(draws[1][8] == 8 and draws[1][9] == 8, "Draw origin is the unscaled frame center")
assert(draws[2][8] == 8 and draws[2][9] == 8, "Centering is independent of sprite scale")
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

local vector = require("lib.hump.vector")
local behavior = require("behavior")
local movers = CreatureSystem.new()
local chaser = movers:create("death_slime", 0, 0, {speed = 10, movementBehavior = behavior.chase})
local stationary = movers:create("red_cap", 0, 0, {speed = 10})
local context = {
  knight = {position = vector(30, 40)},
  healer = {position = vector(-30, -40)},
}
stationary.velocity = vector(100, 100)
movers:update(0.5, context)
assert(chaser.position == vector(3, 4), "Chase uses normalized direction and speed")
assert(chaser.velocity == vector(6, 8))
assert(stationary.position == vector(0, 0) and stationary.velocity == vector(0, 0))
assert(context.knight.position == vector(30, 40) and context.healer.position == vector(-30, -40))
context.knight.position = vector(3, 14)
movers:update(0.5, context)
assert(chaser.position == vector(3, 9), "Chase reads a replaced knight position")
movers:update(10, context)
assert(chaser.position == context.knight.position, "Large dt must not overshoot")
movers:update(0.5, context)
assert(chaser.velocity == vector(0, 0), "Coincident positions must stop without NaN")
context.knight.position = vector(3, 24)
movers:update(0, context)
assert(chaser.position == vector(3, 14) and chaser.velocity == vector(0, 0))
chaser.speed = 0
movers:update(1, context)
assert(chaser.position == vector(3, 14), "Zero speed stays stationary")
chaser.speed = 10
movers:update(0.1, context)
context.knight = nil
movers:update(1, context)
assert(chaser.position == vector(3, 15) and chaser.velocity == vector(0, 0),
  "Missing knight must stop; never target the healer")
movers:update(1)
assert(chaser.position == vector(3, 15), "Omitted context must stop")
context.knight = {position = vector(3, 100)}
movers:update(0.1, context)
chaser.movementBehavior = behavior.idle
movers:update(1, context)
assert(chaser.position == vector(3, 16) and chaser.velocity == vector(0, 0),
  "Switching to idle clears previous movement")

local whole, split = CreatureSystem.new(), CreatureSystem.new()
local wholeCreature = whole:create("death_slime", 0, 0, {speed = 10, movementBehavior = behavior.chase})
local splitCreature = split:create("death_slime", 0, 0, {speed = 10, movementBehavior = behavior.chase})
local target = {knight = {position = vector(100, 0)}}
whole:update(1, target)
split:update(0.5, target)
split:update(0.5, target)
assert(wholeCreature.position == splitCreature.position, "Movement scales with dt")

-- Isolate the creature/debug lifecycle from other game-state subsystems.
-- Map streaming has its own test_map.lua suite; native smoke tests cover
-- integration with the real player, pickups, and LuaJIT-only HC library.
package.preload["lib.HC"] = function()
  return {circle = function() return {} end, remove = noop}
end
-- Rendering/FX have their own suite; keep this fixture focused on creature state.
package.preload["src.world_canvas"] = function()
  return {new = function() return {draw = function(_, draw) draw() end, destroy = noop} end}
end
package.preload["systems.fx"] = function()
  return {new = function() return {particles = {}, update = noop, draw = noop, emit = noop, destroy = noop} end}
end
package.preload["src.player"] = function()
  return {new = function(x, y)
    return {x = x, y = y, kick = {drawStatus = noop},
      stats = {speed = 200, maxHealth = 100, healSpeed = 10},
      animation = {getFeetY = function(_, py) return py + 32 end}}
  end, update = noop, draw = noop, resolveKick = noop, resume = noop}
end
package.preload["src.pickups"] = function()
  return {new = function() return {
    spawn = noop, checkCollected = noop, draw = noop, update = noop, destroy = noop,
  } end}
end
package.preload["systems.music"] = function()
  return {new = function() return {receiveHealthUpdate = noop} end}
end
package.preload["systems.sound_effects"] = function()
  return {new = function() return {
    playSoundEffect = noop, stopSoundEffect = noop, stopAllSoundEffects = noop, playWithLowPass = noop,
  } end}
end
package.preload["src.knight"] = function()
  return {OVERHEAL_LIMIT = 200, new = function(x, y) return {
    position = vector(x, y), update = noop, draw = noop, setPatrolRadius = noop,
    stats = {speed = 60, maxHealth = 100, healSpeed = 10},
    animation = {getFeetY = function(_, py) return py + 32 end},
    GetHealthPercentage = function() return 100 end,
  } end}
end
package.preload["systems.map"] = function()
  return {new = function() return {
    structureSystem = {}, updateStructures = noop, updateStructureEffects = noop,
    update = noop, draw = noop, drawForeground = noop, drawFloor = noop, destroy = noop, resolveMovement = noop,
    getVisibleStructures = function() return {} end,
  } end}
end
package.preload["ui.menu_scene"] = function()
  return {new = function() return {update = noop, draw = noop, destroy = noop} end}
end
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
game.knight.position = vector(10, 0)
game.healer = {position = vector(-10, 0)}
local follower = game.creatures:create("death_slime", 0, 0, {speed = 5, movementBehavior = behavior.chase})
love.update(1)
assert(follower.position == vector(5, 0), "Game forwards the knight in context")
love.keypressed("escape")
love.update(1)
assert(follower.position == vector(5, 0), "Pause freezes movement too")
print("CreatureSystem tests passed: behaviors, context, movement, catalog, playback, pause, restart")

local debugState = require("gamestate.debug")
local hud = require("debug.hud")
local prior = GS.current()
love.keypressed("f3")
love.update(0)
assert(GS.current() == debugState and debugState.menuOpen)
love.keypressed("f3", nil, true)
assert(GS.current() == debugState, "Repeated function keys must not toggle")
love.keypressed("f4")
assert(hud.visible)
love.keypressed("f4", nil, true)
assert(hud.visible)
love.keypressed("f4")
assert(not hud.visible)

local function frame(dt)
  draws = {}
  love.update(dt or 0)
  love.draw()
end
-- Exercise the real SUIT menu, including press/release ordering.
mouseX, mouseY = 480, 290
frame()
mouseDown = true
love.mousepressed(mouseX, mouseY, 1)
frame()
mouseDown = false
frame()
assert(not debugState.menuOpen and hud.visible)
assert(debugState.debugLabel == "Spawn creature on click")
assert(#draws == 0, "Selecting the test must not also spawn")
local sandbox = debugState.activeTest
assert(sandbox.context.knight.position == vector(480, 270))
assert(game.creatures ~= sandbox.creatures, "Debug owns a separate creature system")
windowWidth, windowHeight = 1280, 800
love.resize(windowWidth, windowHeight) -- 4/3 scale and 40-pixel top/bottom bars.
love.mousepressed(0, 0, 1)
love.mousepressed(160, 200, 2)
frame()
assert(#draws == 0, "Ignore letterbox and non-left clicks")
love.mousepressed(160, 200, 1) -- Game coordinates (120, 120).
frame()
assert(#draws == 1 and draws[1][3] == 120 and draws[1][4] == 120)
frame(1)
assert(draws[1][3] > 120 and draws[1][4] > 120, "Spawned creature chases center")
assert(follower.position == vector(5, 0), "Debug must not update the regular game")
local function clickInGame(x, y)
  mouseX, mouseY = x * 4 / 3, y * 4 / 3 + 40
  frame()
  mouseDown = true
  love.mousepressed(mouseX, mouseY, 1)
  frame()
  mouseDown = false
  frame()
end
local created = {}
local create = sandbox.creatures.create
sandbox.creatures.create = function(self, ...)
  local creature = create(self, ...)
  created[#created + 1] = creature
  return creature
end
clickInGame(700, 30)
assert(sandbox.dropdownOpen)
clickInGame(700, 110)
assert(sandbox.selectedCreature.id == "bloodshot_eye" and not sandbox.dropdownOpen)
assert(#created == 0, "Dropdown selection must not spawn")
clickInGame(200, 200)
assert(#created == 1 and created[1].kind == "bloodshot_eye")
assert((created[1].position - vector(200, 200)):len() < 1e-9)
assert(created[1].movementBehavior == behavior.ranged)
clickInGame(700, 30)
clickInGame(700, 150)
assert(sandbox.selectedCreature.id == "ochre_jelly")
clickInGame(240, 200)
assert(#created == 2 and created[2].kind == "ochre_jelly")
assert(created[1].kind == "bloodshot_eye", "Selection does not alter existing creatures")
frame(1)
assert(created[2].position.x > 240 and created[2].position.y > 200)
clickInGame(700, 30)
clickInGame(300, 200)
assert(not sandbox.dropdownOpen and #created == 2, "Outside click only dismisses")
clickInGame(700, 30)
clickInGame(700, 70)
assert(sandbox.selectedCreature.id == "death_slime")
assert(#created == 2, "Returning to default must not spawn")
love.keypressed("f4")
assert(not hud.visible and debugState.activeTest == sandbox)
love.keypressed("escape")
frame()
assert(debugState.menuOpen)
love.mousepressed(160, 200, 1)
assert(debugState.activeTest == nil and #created == 2, "Menu releases the test and must not dispatch clicks")
love.keypressed("f3")
love.update(0)
assert(GS.current() == prior and debugState.activeTest == nil)
love.keypressed("f4")
assert(hud.visible, "HUD can be toggled outside debug")
love.keypressed("f3")
frame()
assert(debugState.menuOpen and debugState.activeTest == nil, "Reentry starts fresh")
love.keypressed("escape")
love.update(0)
assert(GS.current() == prior)
print("Debug tests passed: toggles, real menu click, HUD, scaled input, chase, isolation, cleanup")

local viewport = require("src.viewport")
local transform = {}
love.graphics.translate = function(x, y) transform.x, transform.y = x, y end
love.graphics.scale = function(scale) transform.scale = scale end
-- Simulate compositor fullscreen: drawable dimensions change without a callback.
windowWidth, windowHeight = 1920, 1080
viewport.beginDraw()
viewport.endDraw()
assert(transform.x == 0 and transform.y == 0 and transform.scale == 2)
local gameX, gameY, inside = viewport.toGame(960, 540)
assert(gameX == 480 and gameY == 270 and inside)
-- Input must also resync if it arrives before the first draw at the new size.
windowWidth, windowHeight = 1200, 1200
gameX, gameY, inside = viewport.toGame(600, 600)
assert(gameX == 480 and gameY == 270 and inside)
local _, _, outside = viewport.toGame(0, 0)
assert(not outside, "Letterbox clicks remain excluded after fullscreen changes")
viewport.beginDraw()
viewport.endDraw()
assert(transform.x == 0 and transform.y == 262.5 and transform.scale == 1.25)
-- An older queued event must not override the actual graphics dimensions.
love.resize(960, 540)
viewport.beginDraw()
viewport.endDraw()
assert(transform.scale == 1.25 and transform.y == 262.5)

draws = {}
a.animations.idle:flipH()
first:draw()
assert(draws[1][3] == a.position.x and draws[1][4] == a.position.y)
assert(draws[1][6] == -4 and draws[1][8] == 8 and draws[1][9] == 8,
  "Flipping preserves the sprite center")
print("Viewport and sprite-origin tests passed: missed events, input sync, letterboxing, centered flips")
