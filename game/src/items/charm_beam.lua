---@type Item
local item = {
  color = {0.65, 0.3, 1},
  id = "charm_beam",
  name = "Charm beam",
  rarity = "rare",
  weight = 5,
  description = "Charm creatures to attack each other for 10 seconds, then die.",
  imagePath = "assets/images/dungeon-items/individual/" .. "purple_potion.png",
  soundEffectName = "Powerup",
  onCollect = function(pickup, context)
    context.player.beamMode = "charm"
    context.player.beamModeDuration = 10
  end,
}

return item
