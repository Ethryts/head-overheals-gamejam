-- Run from the repository root: luajit tools/test_beam.lua
package.path = "game/?.lua;game/?/init.lua;game/src/?.lua;game/src/?/init.lua;" .. package.path
local function noop() end
package.loaded["gamestate.deps"] = {Gamestate = {soundEffectsSystem = {
  playSoundEffect = noop, stopSoundEffect = noop,
}}}
local polygons = {}
love = {graphics = {setColor = noop, polygon = function(_, ...) polygons[#polygons + 1] = {...} end}}
local vector = require("lib.hump.vector")
local Beam = require("src.beam")
local StructureSystem = require("systems.structure")
local world = StructureSystem.new()
world.world:rectangle(80, -30, 20, 60)
local function trace(a, b, radius) return world:traceProjectile(a, b, radius) end
local function beam(bend)
  local result = Beam:new(vector(0, 0), vector(1, 0))
  result.tip, result.length, result.bend = vector(200, 0), 200, bend or 0
  return result
end
local straight = beam()
straight:clipAgainstWorld(trace)
assert(math.abs(straight.points[#straight.points].x - 75) < 1e-7)
assert(straight:containsPoint(vector(40, 0)))
assert(not straight:containsPoint(vector(130, 0), 60), "Healing tolerance must not reach through pillars")
straight:draw()
for _, polygon in ipairs(polygons) do
  for i = 1, #polygon, 2 do assert(polygon[i] <= 80) end
end
straight:startRelease()
for i = 1, 30 do
  straight:update(0.01, vector(0, 0))
  straight:clipAgainstWorld(trace)
  assert(not straight:containsPoint(vector(110, 0)), "Released beam cannot emerge beyond pillar")
end
assert(not straight.isVisible)
-- A bend can hit an obstacle even when the straight aim line is clear.
local curvedWorld = StructureSystem.new()
curvedWorld.world:rectangle(80, 35, 20, 20)
local curved = beam(100)
curved:clipAgainstWorld(function(a, b, r) return curvedWorld:traceProjectile(a, b, r) end)
assert(#curved.points < 21 and curved.points[#curved.points].x < 100)
assert(not curved:containsPoint(vector(190, 0)))
-- Moving/aiming clear restores the full path; zero-distance impacts are empty.
straight.isActive, straight.isVisible = true, true
straight.tip, straight.length = vector(200, -100), 200
straight:clipAgainstWorld(trace, vector(0, -100))
assert(#straight.points == 21 and straight:containsPoint(vector(180, -100)))
straight.tip = vector(200, 0)
straight:clipAgainstWorld(trace, vector(90, 0))
assert(#straight.points == 1 and not straight:containsPoint(vector(90, 0)))
print("Beam tests passed: clipping, width, curved paths, healing occlusion, release and corrected origin")
