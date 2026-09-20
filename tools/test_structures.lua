-- Run from the repository root: luajit tools/test_structures.lua
-- Real HC geometry (the vendored library targets LuaJIT), mocked rendering.
package.path = "game/?.lua;game/?/init.lua;game/src/?.lua;" .. package.path
local draws, imageLoads = {}, 0
local function uint32(data, offset)
  local a,b,c,d = data:byte(offset, offset + 3)
  return ((a * 256 + b) * 256 + c) * 256 + d
end
love = {
  math = {newRandomGenerator = function(seed)
    local state = seed % 2147483647 + 1
    return {random = function(_, low, high)
      state = state * 48271 % 2147483647
      return low + state % (high - low + 1)
    end}
  end},
  graphics = {
    newImage = function(path)
      local file = assert(io.open("game/" .. path, "rb"))
      local header = file:read(24); file:close()
      local w, h = uint32(header, 17), uint32(header, 21)
      imageLoads = imageLoads + 1
      return {path = path, getWidth = function() return w end, getHeight = function() return h end,
        setFilter = function(_, min, mag) assert(min == "nearest" and mag == "nearest") end}
    end,
    newSpriteBatch = function()
      return {add = function() end, flush = function() end, release = function() end}
    end,
    push = function() end, pop = function() end, setColor = function() end,
    ellipse = function() end,
    draw = function(...) draws[#draws + 1] = {...} end,
  },
}
local vector = require("lib.hump.vector")
local HC = require("lib.HC")
local Structure = require("src.structure")
local StructureSystem = require("systems.structure")
local MapSystem = require("systems.map")
local system = StructureSystem.new(4)
local pillar = Structure.new("pillar_round", 0, 0, 4, system.world)
local actorWorld = HC.new()
local actor = {x = 100, y = -10, shape = actorWorld:circle(100, -10, 16)}
local loads = 0
system:resolveMovement(actor, -100, -10, function() loads = loads + 1 end)
assert(actor.x < -35.9 and actor.x > -36.1 and math.abs(actor.y + 10) < 0.1)
assert(loads >= 25, "Long movement is split into steps")
assert(not actor.shape:collidesWith(pillar.shape), "Actor must finish outside the base")
actor.x, actor.y = 0, 100
system:resolveMovement(actor, 0, -100, function() end)
assert(actor.y < -47.9 and actor.y > -48.1, "Approaching from above stops at the taller base")
local head = actorWorld:circle(0, -100, 8)
assert(not pillar:collidesWith(head), "Tall artwork is not a full-height collider")
actor.x, actor.y = 100, 90
system:resolveMovement(actor, -100, -10, function() end)
assert(actor.y > -10 and not actor.shape:collidesWith(pillar.shape), "Diagonal motion slides past")
pillar:draw()
assert(draws[1][7] == 8 and draws[1][8] == 32, "Draw from the base center")
pillar:destroy(); pillar:destroy(); system:prune()
assert(next(system.world:hash():shapes()) == nil and next(system.world:hash().cells) == nil)

local function allStructures(map)
  local result = {}
  for _, chunk in pairs(map.chunks) do
    for _, structure in ipairs(chunk.structures) do result[#result + 1] = structure end
  end
  table.sort(result, function(a,b) if a.y == b.y then return a.x < b.x end return a.y < b.y end)
  return result
end
local function signature(map)
  local parts = {}
  for _, s in ipairs(allStructures(map)) do
    parts[#parts + 1] = s.kind .. ":" .. s.x .. ":" .. s.y
  end
  return table.concat(parts, "|")
end
-- Prop randomness must never replace or shift the original pillars.
local function generateWithPropSeed(seed)
  local placement = StructureSystem.new(4)
  local props = placement:createChunk({x = 1024, y = 1024, size = 1024,
    random = love.math.newRandomGenerator(12), propRandom = love.math.newRandomGenerator(seed)})
  local pillars = {}
  for _, s in ipairs(props) do
    if s.kind:match("^pillar_") then pillars[#pillars + 1] = s.kind .. ":" .. s.x .. ":" .. s.y end
    s:destroy()
  end
  return table.concat(pillars, "|")
end
local originalPillars = generateWithPropSeed(1)
assert(#originalPillars > 0 and originalPillars == generateWithPropSeed(99),
  "Prop generation is independent of pillar placement")

local map = MapSystem.new({seed = 1})
map:update(0, 0, 960, 540)
local initial = allStructures(map)
local baseline = signature(map)
assert(#initial > 0)
local origin = actorWorld:circle(0, 0, 100)
for _, s in ipairs(initial) do assert(not s:collidesWith(origin), "Origin must be clear") end
local generatedKinds = {}
for _, s in ipairs(initial) do
  generatedKinds[s.kind] = true
  local isProp = s.kind == "crate" or s.kind == "brazier" or s.kind == "barrel"
  assert(s.breakable == (s.kind == "crate" or s.kind == "barrel"), "Only crates and barrels break")
  assert(s.scale == (s.breakable and 2.5 or isProp and 3.5 or 4), "Braziers are larger than breakables")
end
for _, kind in ipairs({"crate", "brazier", "barrel"}) do
  assert(generatedKinds[kind], "Generated map must include " .. kind)
end
for _, chunk in pairs(map.chunks) do
  for _, s in ipairs(chunk.structures) do
    assert(s.x - s.image:getWidth() * s.scale / 2 >= chunk.x * map.chunkSize)
    assert(s.x + s.image:getWidth() * s.scale / 2 <= (chunk.x + 1) * map.chunkSize)
    assert(s.y - s.image:getHeight() * s.scale >= chunk.y * map.chunkSize)
    assert(s.y <= (chunk.y + 1) * map.chunkSize)
  end
end
for i, a in ipairs(initial) do
  for j = i + 1, #initial do
    assert(not a:collidesWith(initial[j].shape), "Props and pillars must not overlap")
  end
end
local other = MapSystem.new({seed = 1})
other:update(10000, -10000, 960, 540)
other:update(0, 0, 960, 540)
assert(signature(other) == baseline, "Placement is independent of visitation order")
assert(other.structureSystem.world ~= map.structureSystem.world)
other:destroy()
local alternate = MapSystem.new({seed = 2})
alternate:update(0, 0, 960, 540)
assert(signature(alternate) ~= baseline)
alternate:destroy()
map:update(10000, 10000, 960, 540)
for _, s in ipairs(initial) do assert(s.shape == nil, "Unloading releases colliders") end
map:update(0, 0, 960, 540)
assert(signature(map) == baseline, "Unloaded structures regenerate identically")
local brokenProp
for _, s in ipairs(allStructures(map)) do
  if s.breakable then brokenProp = s; break end
end
local drops = 0
map.structureSystem.onBreak = function() drops = drops + 1 end
local brokenKind, brokenX, brokenY = brokenProp.kind, brokenProp.x, brokenProp.y
assert(brokenProp:launch(vector(1, 0)))
brokenProp:updateFlight(1, function() end)
assert(brokenProp.broken and not brokenProp.shape)
assert(not brokenProp:tryBreak() and drops == 1, "A prop drops loot only once")
draws = {}
brokenProp:draw()
assert(#draws == 0, "Broken props are invisible")
map:update(10000, 10000, 960, 540)
map:update(0, 0, 960, 540)
for _, s in ipairs(allStructures(map)) do
  assert(s.kind ~= brokenKind or s.x ~= brokenX or s.y ~= brokenY, "Broken props stay gone after reloading")
  if not s.breakable then assert(not s:tryBreak() and s.shape, "Pillars cannot break") end
end
assert(drops == 1, "Chunk unloading never drops loot")
for i = 1, 60 do
  map:update(i * 1000, -i * 1000, 960, 540)
  local shapes = map.structureSystem.world:hash():shapes()
  local count = 0
  for _ in pairs(shapes) do count = count + 1 end
  assert(count == #allStructures(map) and count <= 560)
  local cells = 0
  for _, row in pairs(map.structureSystem.world:hash().cells) do
    for _ in pairs(row) do cells = cells + 1 end
  end
  assert(cells <= 2240, "Empty collision cells must not accumulate along the route")
end
map:update(0, 0, 960, 540)
draws = {}
map:draw(0)
for _, draw in ipairs(draws) do
  if draw[1].path then assert(draw[3] <= 0, "Background structures sort behind player") end
end
draws = {}
map:drawForeground(0)
for _, draw in ipairs(draws) do assert(draw[3] > 0) end
map:destroy(); map:destroy()
assert(next(map.structureSystem.world:hash():shapes()) == nil)
assert(next(map.structureSystem.world:hash().cells) == nil)
assert(imageLoads <= 17, "Structure and floor images are shared")
-- Controlled throws: animation, swept impacts and frame-independent landing.
local flightMap = MapSystem.new()
flightMap.createStructures = function() return {} end
flightMap:update(0, 0, 960, 540)
local world = flightMap.structureSystem.world
local function add(kind, x, y)
  local prop = Structure.new(kind, x, y, 4, world)
  table.insert(flightMap.chunks["0:0"].structures, prop)
  return prop
end
local crate = add("crate", 0, 0)
local loot = 0
crate.onBreak = function() loot = loot + 1 end
assert(crate:launch(vector(1, 0)) and not crate:launch(vector(-1, 0)))
assert(not crate.shape and not crate.broken and loot == 0)
flightMap:updateStructures(0, {})
assert(crate.x == 0 and crate.flight.elapsed == 0, "Paused throws do not advance")
flightMap:updateStructures(0.225, {})
assert(math.abs(crate.x - 90) < 1e-6 and math.abs(crate.lift - 40) < 1e-6)
assert(crate.angle > 0 and not crate.broken and loot == 0)
draws = {}
crate:draw()
assert(draws[1][4] == crate.angle and draws[1][3] < crate.y, "Airborne art spins above its ground position")
flightMap:updateStructures(0.225, {})
assert(crate.broken and crate.x == 180 and crate.lift == 0 and loot == 1)
flightMap:updateStructures(1, {})
assert(loot == 1)
local barrel = add("barrel", 0, 0)
barrel:launch(vector(-1, 0))
flightMap:updateStructures(1, {})
assert(barrel.broken and barrel.x == -180 and barrel.angle < 0, "Long frames land at the same range")
local brazier = add("brazier", -100, 100)
assert(not brazier:launch(vector(1, 0)) and not brazier:tryBreak() and brazier.shape)

local obstacle = add("pillar_round", 100, 0)
local thrown = add("crate", 0, 0)
thrown:launch(vector(1, 0))
flightMap:updateStructures(1, {})
assert(thrown.broken and math.abs(thrown.x - 65) < 1e-6, "Sweeps stop at pillars even in a long frame")
assert(obstacle.shape and not obstacle.broken)
local target = {position = vector(50, -10), health = 1, scale = 1}
local atCreature = add("crate", 0, 0)
atCreature:launch(vector(1, 0))
flightMap:updateStructures(1, {target})
assert(atCreature.broken and math.abs(atCreature.x - 29) < 1e-6, "The nearer creature wins over the pillar")
assert(target.health == 1, "Prop impacts do not add unrequested creature damage")
local pastDead = add("crate", 0, 0)
pastDead:launch(vector(1, 0))
target.health = 0
flightMap:updateStructures(1, {target})
assert(math.abs(pastDead.x - 65) < 1e-6, "Dead creatures do not intercept props")
obstacle:destroy()

-- Active throws retain their owner chunk and stream geometry across borders.
local crossing = add("barrel", 490, 100)
crossing:launch(vector(1, 0))
flightMap.createStructures = function(self, context)
  if context.chunkX == 1 and context.chunkY == 0 then
    return {Structure.new("pillar_round", 550, 100, 4, self.structureSystem.world)}
  end
  return {}
end
flightMap:update(10000, 10000, 960, 540)
assert(flightMap.chunks["0:0"] and crossing.flight, "An active throw survives chunk eviction")
local found = false
for _, structure in ipairs(flightMap:getVisibleStructures()) do
  if structure == crossing then found = true end
end
assert(found, "Moving props remain available to the draw queue outside their owner chunk")
flightMap:updateStructures(1, {})
assert(crossing.broken and math.abs(crossing.x - 517.5) < 1e-6, "Flight loads obstacles in the next chunk")
flightMap:update(10000, 10000, 960, 540)
assert(not flightMap.chunks["0:0"], "Finished throws release their owner chunk")
flightMap:destroy()
assert(next(world:hash():shapes()) == nil and next(world:hash().cells) == nil)
-- Ambient fire follows visible chunks, without accumulating duplicate emitters.
local fireMap = MapSystem.new({seed = 1})
local fx = require("systems.fx").new()
fireMap:update(0, 0, 960, 540)
fireMap:updateStructureEffects(fx)
local fires = 0
for _, structure in ipairs(fireMap:getVisibleStructures()) do
  if structure.kind == "brazier" then
    fires = fires + 1
    assert(structure.emitters.brazier_flame.active and structure.emitters.embers.active)
    assert(structure.emitters.brazier_flame.y == structure.y - 9 * structure.scale)
    assert(structure.emitters.brazier_flame.options.depth == structure.y)
  end
end
assert(fires > 0 and #fx.emitters == fires * 2)
fireMap:updateStructureEffects(fx)
assert(#fx.emitters == fires * 2, "Updating fire does not duplicate emitters")
fx:update(0.1)
assert(#fx.particles > 0, "Braziers continuously produce particles")
local oldEmitters = {}
for _, emitter in ipairs(fx.emitters) do oldEmitters[#oldEmitters + 1] = emitter end
fireMap.visible = {}
fireMap:updateStructureEffects(fx)
for _, emitter in ipairs(oldEmitters) do assert(not emitter.active, "Offscreen braziers stop emitting") end
fx:update(2)
assert(#fx.emitters == 0 and #fx.particles == 0)
fireMap:update(0, 0, 960, 540)
fireMap:updateStructureEffects(fx)
assert(#fx.emitters == fires * 2, "Visible braziers restart their fire")
fireMap:destroy()
for _, emitter in ipairs(fx.emitters) do assert(not emitter.active, "Unloading cleans up fire") end
fx:update(2)
assert(#fx.emitters == 0 and #fx.particles == 0)
print("Structure tests passed: generation, collision, flight, impacts, streaming, brazier particles and cleanup")
