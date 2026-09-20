---@type Item
local item = {
  id = "knight_feather",
  name = "Knight feather",
  rarity = "uncommon",
  weight = 25,
  description = "+10 knight movement speed for this run. Stacks on collection.",
  imagePath = "assets/images/dungeon-items/individual/" .. "white_feather.png",
	soundEffectName = "Powerup",
  onCollect = function(pickup, context)
    if context.knight then context.knight.stats.speed = context.knight.stats.speed + 10 end
  end,
}

return item
