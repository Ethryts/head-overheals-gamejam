---@class EndlessDifficulty
---@field start number Seconds before endless escalation begins.
---@field stepEvery number Seconds between increases.
---@field intervalMultiplier number Multiplies the stage interval for each step.
---@field minInterval number Shortest interval between spawn events.
---@field hordeWeightGrowth number Added to the swarm weight multiplier each step.
---@field maxHordeWeightMultiplier number Maximum multiplier; group sizes stay fixed.
---@field maxActiveCreatures integer Population ceiling, including individual spawns.

---@type EndlessDifficulty
return {
  start = 120,
  stepEvery = 30,
  intervalMultiplier = 0.95,
  minInterval = 0.5,
  hordeWeightGrowth = 0.25,
  maxHordeWeightMultiplier = 4,
  maxActiveCreatures = 150,
}
