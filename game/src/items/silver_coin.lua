local Gamestate = require("gamestate.deps").Gamestate
---@type Item
local item = {
  id = "silver_coin",
  name = "Silver coin",
  rarity = "common",
  weight = 10,
  description = "+5 score for this run.",
  imagePath = "assets/images/dungeon-items/individual/silver_coin.png",
	soundEffectName = "Pickup",
  onCollect = function(pickup, context)
    if context.game then
      context.game.score = context.game.score + 5
    end
  end,
}

return item
