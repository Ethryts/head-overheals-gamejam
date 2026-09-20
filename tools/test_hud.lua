package.path = "game/?.lua;game/?/init.lua;game/src/?.lua;game/src/?/init.lua;" .. package.path
local Hud = require("ui.hud")
local game = {score = 0, player = {stats = {speed = 200, maxHealth = 100, healSpeed = 10}},
  knight = {stats = {speed = 60, maxHealth = 100, healSpeed = 10}}}
local hud = Hud.new(game)
assert(next(hud.flashes) == nil, "Initial values do not flash")
local context = {player = game.player, knight = game.knight, game = game}
require("src.items.party_haste").onCollect({}, context)
hud:update(0.1, game)
assert(hud.flashes["player.speed"].amount == 10 and hud.flashes["knight.speed"].amount == 10)
require("src.items.healer_boots").onCollect({}, context)
hud:update(0.1, game)
assert(hud.flashes["player.speed"].amount == 20, "Rapid pickups aggregate")
assert(hud.values["player.speed"] == 220)
require("src.items.golden_heart").onCollect({}, context)
require("src.items.emerald").onCollect({}, context)
game.score = 5
hud:update(0.1, game)
assert(hud.flashes["knight.maxHealth"].amount == 10)
assert(hud.flashes["knight.healSpeed"].amount == 1 and hud.flashes.score.amount == 5)
local remaining = hud.flashes.score.remaining
hud:update(0, game)
assert(hud.flashes.score.remaining == remaining, "Paused time preserves flashes")
hud:update(3, game)
assert(next(hud.flashes) == nil and hud.values["player.speed"] == 220)
game.player.stats.speed = 200
hud:update(0.1, game)
assert(not hud.flashes["player.speed"], "Decreases do not get a positive highlight")
assert(next(Hud.new(game).flashes) == nil, "Restart clears highlights")
print("HUD tests passed: actual item hooks, both actors, stacking, score, expiry, pause and restart")
