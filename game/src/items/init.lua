-- Add item modules here to include them in random pickup spawning.
---@type Item[]
local items = {
  (require("src.items.healer_boots")),
  (require("src.items.knight_feather")),
  (require("src.items.party_haste")),
  (require("src.items.gold_coin")),
}

return items
