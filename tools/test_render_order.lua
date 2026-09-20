-- Run from the repository root: luajit tools/test_render_order.lua
package.path = "game/?.lua;game/?/init.lua;game/src/?.lua;game/src/?/init.lua;" .. package.path
local function noop() end
local draws = {}
local function record(name) draws[#draws + 1] = name end
love = {graphics = {push = noop, pop = noop, translate = noop, setColor = noop,
  draw = function() record("floor") end}}
package.loaded["gamestate.deps"] = {Gamestate = {}}
package.loaded["gamestate.ui"] = {width = 960, height = 540, background = noop}
package.loaded["src.player"] = {draw = function() record("healer") end}
for _, module in ipairs({"src.pickups", "src.knight", "systems.spawner", "systems.projectile"}) do
  package.loaded[module] = {}
end
local CreatureSystem = require("systems.creature")
local PlayerAnimation = require("src.player_animation")
local MapSystem = require("systems.map")
local game = require("gamestate.game")
local function animation(scale)
  return setmetatable({bodyScale = scale, headScale = 100,
    body = {animation = {getDimensions = function() return 16, 16 end}}}, PlayerAnimation)
end
local function pillar(name, y)
  return {y = y, draw = function() record(name) end}
end
local creature = {position = {x = 0, y = 70}, scale = 2,
  animations = {idle = {getDimensions = function() return 16, 16 end,
    draw = function() record("creature") end}}}
game.creatures = setmetatable({creatures = {creature}}, CreatureSystem)
game.player = {x = 0, y = 120, animation = animation(2)}
game.knight = {position = {x = 0, y = 80}, animation = animation(2),
  draw = function() record("knight") end}
-- Deliberately reversed chunk order; both floors must precede all bodies.
game.map = setmetatable({chunkSize = 100, tileScale = 1, visible = {
  {x = 0, y = 1, batches = {{}}, structures = {pillar("front pillar", 150)}},
  {x = 0, y = 0, batches = {{}}, structures = {pillar("pillar", 100)}},
}}, MapSystem)
game.pickups = {draw = function() record("pickups") end}
game.worldCanvas = {draw = function(_, draw) draw() end}
game.fx = {particles = {}, draw = noop}
game.projectiles = {projectiles = {{position = {y = 200}}},
  drawProjectile = function() record("projectiles") end}
local function check(expected)
  draws = {}
  game:drawWorld()
  assert(table.concat(draws, ",") == expected, table.concat(draws, ","))
end
check("floor,floor,pickups,creature,knight,pillar,healer,front pillar,projectiles")
-- Moving only the healer must not change which side the other actors occupy.
game.player.y = 0
check("floor,floor,pickups,healer,creature,knight,pillar,front pillar,projectiles")
-- Feet and body scale determine depth, independent of oversized heads.
creature.scale = 4
game.knight.position.y = 110
check("floor,floor,pickups,healer,pillar,creature,knight,front pillar,projectiles")
-- A character at the same base depth is covered until strictly in front.
creature.position.y = 68
check("floor,floor,pickups,healer,creature,pillar,knight,front pillar,projectiles")
check("floor,floor,pickups,healer,creature,pillar,knight,front pillar,projectiles")
game.fx.draw = function() record("dust") end
game.fx.particles = {{preset = {layer = "air"}, depth = 105}}
game.fx.drawParticle = function() record("spark") end
game.projectiles.projectiles[1].position.y = 90
check("floor,floor,dust,pickups,healer,projectiles,creature,pillar,spark,knight,front pillar")
print("Render order tests passed: independent actors, chunk order, scaling and equal depth")
