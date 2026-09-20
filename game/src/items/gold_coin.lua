local Gamestate = require("gamestate.deps").Gamestate
---@type Item
local item = {
  color = {1, 0.75, 0.15},
  id = "gold_coin",
  name = "Gold coin",
  rarity = "common",
  weight = 70,
  description = "+1 score and 5 heal charge for this run.",
  imagePath = "assets/images/dungeon-items/individual/gold_coin.png",
	soundEffectName = "Pickup",
  onCollect = function(pickup, context)
    if context.game then
      context.game.score = context.game.score + 1
      if context.game.healResource then context.game.healResource:add(5) end
    end
  end,
}

return item
