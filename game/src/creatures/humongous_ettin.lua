---@type CreatureOptions
return {
  health = 10,
  speed = 24,
  scale = 4,
  frameDuration = 0.4,
  knockbackResponse = {distanceMultiplier = 0.18, speedMultiplier = 0.3},
  movementBehavior = require("behavior.ogre"),
  attack = {type = "melee", damage = 10, cooldown = 2.2, range = 40},
}
