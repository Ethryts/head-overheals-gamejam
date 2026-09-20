---@type CreatureOptions
return {
  health = 4,
  speed = 32,
  scale = 3,
  frameDuration = 0.3,
  knockbackResponse = {distanceMultiplier = 0.35, speedMultiplier = 0.5},
  movementBehavior = require("behavior.ogre"),
  attack = {type = "melee", damage = 5, cooldown = 1.8, range = 32},
}
