---@type Item
local item = {
  id = "skull",
  name = "Skull ",
  rarity = "rare",
  weight = 10,
  description = "Clears every monster currently on the map.",
  imagePath = "assets/images/dungeon-items/individual/" .. "skull.png",
  soundEffectName = "Powerup",
  onCollect = function(pickup, context)
    if context.game and context.game.creatures then
      context.game.creatures:clearAll()
    end
  end,
}

return item
