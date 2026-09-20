---@type Item
local item = {
  color = {0.65, 0.4, 0.2},
  id = "healer_boots",
  name = "Healer boots",
  rarity = "common",
  weight = 30,
  description = "+10 healer movement speed for this run. Stacks on collection.",
  imagePath = "assets/images/dungeon-items/individual/" .. "boots.png",
	soundEffectName = "Powerup",
  onCollect = function(pickup, context)
    context.player.stats.speed = context.player.stats.speed + 10
  end,
}

return item
