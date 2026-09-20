---@type Item
local item = {
  color = {1, 0.45, 0.1},
  id = "super_kick",
  name = "Super kick",
  rarity = "rare",
  weight = 5,
  description = "Kicks launch creatures out of view for 10 seconds.",
  imagePath = "assets/images/dungeon-items/individual/" .. "gauntlet.png",
  soundEffectName = "Powerup",
  onCollect = function(pickup, context)
    context.player.superKickDuration = 10
  end,
}

return item
