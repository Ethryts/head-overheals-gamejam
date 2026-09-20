---@type Item
local item = {
  color = {1, 0.7, 0.15},
  id = "golden_heart",
  name = "Golden heart",
  rarity = "rare",
  weight = 5,
  description = "+10 max health for the Knight for this run. Stacks on collection.",
  imagePath = "assets/images/dungeon-items/individual/" .. "golden_heart.png",
	soundEffectName = "Powerup",
  onCollect = function(pickup, context)
    if context.knight then context.knight.stats.maxHealth = context.knight.stats.maxHealth + 10 end
  end,
}

return item
