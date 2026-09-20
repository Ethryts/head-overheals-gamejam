-- Run from the repository root: luajit tools/test_difficulty.lua
package.path = "game/?.lua;game/?/init.lua;game/src/?.lua;game/src/?/init.lua;" .. package.path
love = {graphics = {getDimensions = function() return 960, 540 end}}
local Spawner = require("systems.spawner")
local schedule = require("src.difficulty")
local spawned = {}
local creatures = {create = function(_, id, x, y, options)
  local creature = {id = id, x = x, y = y, options = options}
  spawned[#spawned + 1] = creature
  return creature
end}
local originalRandom = math.random
local roll = 0.99
math.random = function(...)
  if select("#", ...) == 0 then return roll end
  return originalRandom(...)
end
local spawner = Spawner.new(creatures, {difficulty = schedule})
assert(spawner.stage == 1 and spawner.timer == 2.5)
spawner:update(2.5, 100, 200)
assert(#spawned == 1 and spawned[1].id == "death_slime")
spawner:update(27.49, 100, 200)
assert(spawner.stage == 1 and spawned[#spawned].id == "death_slime")
local pending = spawner.timer
spawner:update(0.01, 100, 200)
assert(spawner.stage == 2 and spawner.interval == 2)
assert(math.abs(spawner.timer - (pending - 0.01)) < 1e-7, "Stage changes preserve pending spawn")
spawner:spawnOne(100, 200)
assert(spawned[#spawned].id == "bloodshot_eye")
roll = 0.79
spawner:spawnOne(100, 200)
assert(spawned[#spawned].id == "death_slime", "Slimes retain 80% of stage two weight")
roll = 0.81
spawner:spawnOne(100, 200)
assert(spawned[#spawned].id == "bloodshot_eye")
spawner:setEnabled(false)
local elapsed, timer = spawner.elapsed, spawner.timer
spawner:update(100, 100, 200)
assert(spawner.elapsed == elapsed and spawner.timer == timer, "Disabled spawning freezes progression")
spawner:setEnabled(true)
roll = 0.99
spawner:update(9.99, 100, 200)
assert(spawner.stage == 2 and spawned[#spawned].id == "bloodshot_eye", "No ogres before 40 seconds")
spawner:update(0.01, 100, 200)
assert(spawner.stage == 3)
spawner:spawnOne(100, 200)
assert(spawned[#spawned].id == "brawny_ogre" and not spawned[#spawned].options,
  "Ogres keep their own defaults")
roll = 0.97
spawner:spawnOne(100, 200)
assert(spawned[#spawned].id ~= "brawny_ogre", "Ogres are below 3% at 40 seconds")
spawner:update(20, 100, 200)
assert(spawner.stage == 4 and spawner.interval == 1.5 and spawned[#spawned].id == "brawny_ogre",
  "Ogres become more common at 60 seconds")
roll = 0.94
spawner:spawnOne(100, 200)
assert(spawned[#spawned].id == "ochre_jelly", "Ogres remain below 6%")
local count = #spawned
spawner:update(10000, 100, 200)
assert(spawner.stage == 4 and #spawned == count + 1, "Final stage persists without catch-up floods")
assert(spawned[1].id == "death_slime", "Existing creatures are untouched")
local restarted = Spawner.new(creatures, {difficulty = schedule})
assert(restarted.stage == 1 and restarted.elapsed == 0 and #restarted.pool == 1)
local skipped = Spawner.new(creatures, {difficulty = schedule})
skipped:update(65, 0, 0)
assert(skipped.stage == 4, "Long frames advance through every elapsed stage")
local fixed = Spawner.new(creatures, {interval = 4, pool = {{id = "death_slime"}}})
fixed:update(100, 0, 0)
assert(fixed.stage == 0 and fixed.interval == 4 and spawned[#spawned].id == "death_slime")
assert(schedule[1].at == 0 and #schedule[1].pool == 1, "Shared schedule remains unchanged")
math.random = originalRandom
print("Difficulty tests passed: thresholds, weights, pending spawns, disabled time, restart, long frames and fixed pools")
