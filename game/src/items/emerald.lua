---@type Item
local item = {
  color = {0.15, 0.9, 0.4},
  id = "emerald",
  name = "Emerald",
  rarity = "common",
  weight = 10,
  description = "+1 multiplier on heal speed recipient",
  imagePath = "assets/images/dungeon-items/individual/" .. "emerald.png",
	soundEffectName = "Pickup",
  onCollect = function(pickup, context)
    if context.knight then context.knight.stats.healSpeed = context.knight.stats.healSpeed + 1 end
  end,
}

return item
