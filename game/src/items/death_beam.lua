---@type Item
local item = {
  color = {0.8, 0.15, 0.2},
  id = "death_beam",
  name = "Death beam",
  rarity = "rare",
  weight = 5,
  description = "Changes the healing beam into a death beam for 10 seconds.",
  imagePath = "assets/images/dungeon-items/individual/" .. "flame.png",
  soundEffectName = "Powerup",
  onCollect = function(pickup, context)
    context.player.beamMode = "death"
    context.player.beamModeDuration = 10
  end,
}

return item
