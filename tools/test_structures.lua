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
    draw = function(...) draws[#draws + 1] = {...} end,
  },
}
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
local map = MapSystem.new({seed = 1})
map:update(0, 0, 960, 540)
local initial = allStructures(map)
local baseline = signature(map)
assert(#initial > 0)
local origin = actorWorld:circle(0, 0, 100)
for _, s in ipairs(initial) do assert(not s:collidesWith(origin), "Origin must be clear") end
for _, chunk in pairs(map.chunks) do
  for _, s in ipairs(chunk.structures) do
    assert(s.x - s.image:getWidth() * s.scale / 2 >= chunk.x * map.chunkSize)
    assert(s.x + s.image:getWidth() * s.scale / 2 <= (chunk.x + 1) * map.chunkSize)
    assert(s.y - s.image:getHeight() * s.scale >= chunk.y * map.chunkSize)
    assert(s.y <= (chunk.y + 1) * map.chunkSize)
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
assert(signature(map) == baseline, "Unloaded pillars regenerate identically")
for i = 1, 60 do
  map:update(i * 1000, -i * 1000, 960, 540)
  local shapes = map.structureSystem.world:hash():shapes()
  local count = 0
  for _ in pairs(shapes) do count = count + 1 end
  assert(count == #allStructures(map) and count <= 140)
  local cells = 0
  for _, row in pairs(map.structureSystem.world:hash().cells) do
    for _ in pairs(row) do cells = cells + 1 end
  end
  assert(cells <= 560, "Empty collision cells must not accumulate along the route")
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
assert(imageLoads <= 14, "Pillar and floor images are shared")
print("Structure tests passed: real HC blocking/sliding, seeded placement, clear spawn, layering, regeneration, bounded collider cleanup")
