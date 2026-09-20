---@type Item
local item = {
  id = "healer_boots",
  name = "Healer boots",
  rarity = "common",
  weight = 70,
  description = "+10 healer movement speed for this run. Stacks on collection.",
  imagePath = "assets/images/dungeon-items/individual/" .. "boots.png",
  onCollect = function(pickup, context)
    context.player.stats.speed = context.player.stats.speed + 10
  end,
}

return item
