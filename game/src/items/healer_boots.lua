---@type Item
local item = {
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
