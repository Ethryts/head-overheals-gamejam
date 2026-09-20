-- Run from the repository root: luajit tools/test_swarms.lua
package.path = "game/?.lua;game/?/init.lua;game/src/?.lua;game/src/?/init.lua;" .. package.path
local Spawner = require("systems.spawner")
local groups = require("spawns")
local endless = require("src.endless")
local function system()
  local creatures = {items = {}}
  function creatures:getAll() return self.items end
  function creatures:create(id, x, y, options)
    local creature = {kind = id, x = x, y = y, options = options}
    self.items[#self.items + 1] = creature
    return creature
  end
  return creatures
end
local originalRandom = math.random
local roll, edge = 0.5, 1
math.random = function(low, high)
  if not low then return roll end
  if not high then return edge end
  return 0
end

-- One formation, every member offscreen on the same edge, at arbitrary world coordinates.
for direction = 1, 4 do
  edge = direction
  local creatures = system()
  local spawner = Spawner.new(creatures, {pool = {{id = "slime_swarm"}}})
  local first, count = spawner:spawnOne(-1200, 800)
  assert(count == 8 and first == creatures.items[1])
  local counts = {}
  for i, c in ipairs(creatures.items) do
    counts[c.kind] = (counts[c.kind] or 0) + 1
    local x, y = c.x + 1200, c.y - 800
    assert((edge == 1 and y+32 < -270) or (edge == 2 and y-32 > 270)
      or (edge == 3 and x+32 < -480) or (edge == 4 and x-32 > 480))
    for j = 1, i-1 do
      local other = creatures.items[j]
      local distance = math.sqrt((c.x-other.x)^2 + (c.y-other.y)^2)
      assert(distance >= 40 and distance <= 120, "Swarm is spaced, compact and non-overlapping")
    end
  end
  assert(counts.death_slime == 6 and counts.ochre_jelly == 2)
end
for _, id in ipairs({"eye_swarm", "ogre_escort"}) do
  local creatures = system()
  local spawner = Spawner.new(creatures, {pool = {{id = id}}})
  local _, count = spawner:spawnOne(0, 0)
  assert(count == (id == "eye_swarm" and 6 or 5))
  for _, creature in ipairs(creatures.items) do
    assert(not groups[creature.kind], "No invisible swarm parent is created")
    if creature.kind == "ocular_watcher" or creature.kind == "brawny_ogre" then
      assert(creature.options == nil, "Special creatures retain their default movement and stats")
    end
  end
end

local creatures = system()
local pool = {{id = "death_slime", weight = 1}, {id = "slime_swarm", weight = 1}}
local spawner = Spawner.new(creatures, {pool = pool, interval = 1.5, endless = endless})
roll = 0.45
spawner:update(120, 0, 0)
assert(spawner.endlessStep == 0 and spawner.interval == 1.5 and #creatures.items == 1)
spawner:update(29.99, 0, 0)
assert(spawner.endlessStep == 0)
spawner:update(0.01, 0, 0)
assert(spawner.endlessStep == 1 and math.abs(spawner.interval - 1.425) < 1e-7)
assert(spawner.hordeWeightMultiplier == 1.25)
local before = #creatures.items
spawner:spawnOne(0, 0)
assert(#creatures.items == before+8, "The same roll selects a swarm as its weight grows")
spawner:update(10000, 0, 0)
assert(spawner.interval == 0.5 and spawner.hordeWeightMultiplier == 4)
assert(pool[1].weight == 1 and pool[2].weight == 1 and groups.slime_swarm.members[1].count == 6,
  "Endless scaling never mutates shared definitions")
local elapsed, timer, population = spawner.elapsed, spawner.timer, #creatures.items
spawner:setEnabled(false)
spawner:update(100, 0, 0)
assert(spawner.elapsed == elapsed and spawner.timer == timer and #creatures.items == population)
local restarted = Spawner.new(system(), {pool = pool, interval = 1.5, endless = endless})
assert(restarted.elapsed == 0 and restarted.endlessStep == 0 and restarted.hordeWeightMultiplier == 1)

local capped = system()
local limited = Spawner.new(capped, {pool = {{id = "slime_swarm"}}, maxActiveCreatures = 10})
local _, count = limited:spawnOne(0, 0)
assert(count == 8)
_, count = limited:spawnOne(0, 0)
assert(count == 2 and #capped.items == 10, "Partial swarms fill only available capacity")
local first
first, count = limited:spawnOne(0, 0)
assert(not first and count == 0)
limited:update(10000, 0, 0)
assert(#capped.items == 10 and limited.timer == limited.interval)
table.remove(capped.items)
limited:update(limited.interval, 0, 0)
assert(#capped.items == 10, "Freed capacity does not release a queued burst")
assert(not limited:spawnAt("death_slime", 0, 0), "Single spawns share the cap")
math.random = originalRandom
print("Swarm tests passed: formations, mixed defaults, endless thresholds, weights, caps, pause and restart")
