---@type Item
local item = {
  id = "party_haste",
  name = "Party haste",
  rarity = "rare",
  weight = 5,
  description = "+10 movement speed for both heroes for this run. Stacks on collection.",
  imagePath = "assets/images/dungeon-items/individual/" .. "lightning_bolt.png",
  onCollect = function(pickup, context)
    context.player.stats.speed = context.player.stats.speed + 10
    if context.knight then context.knight.stats.speed = context.knight.stats.speed + 10 end
  end,
}

return item
