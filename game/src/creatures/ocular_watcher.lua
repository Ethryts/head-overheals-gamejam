---@type CreatureOptions
return {
  health = 1,
  speed = 55,
  scale = 2,
  movementBehavior = require("behavior.watcher"),
  knockbackResponse = {distanceMultiplier = 1.2, speedMultiplier = 1.15},
  attack = {type = "ranged", damage = 1, cooldown = 1.8, range = 300,
    projectile = {speed = 220, radius = 4, lifespan = 3}},
}
