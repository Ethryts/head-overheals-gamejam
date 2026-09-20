local UI = require("gamestate.ui")
local GS = require("gamestate.deps").Gamestate
local Skin = require("ui.skin")
local vector = require("lib.hump.vector")

local creatures = {
  {"death_slime", "Death Slime"}, {"ochre_jelly", "Ochre Jelly"},
  {"bloodshot_eye", "Bloodshot Eye"}, {"ocular_watcher", "Ocular Watcher"},
  {"brawny_ogre", "Brawny Ogre"}, {"humongous_ettin", "Two-headed Ogre"},
}

---@class DemoSettings
---@field autoSpawn boolean
---@field hideHud boolean
---@field creature integer Selected creature index.
---@field count integer Creatures per click.
---@field tool string World click action.
---@class DemoTest: DebugTest
---@field game? GameState
---@field settings DemoSettings
local Demo = {label = "Demo staging", hideDebugHud = true,
  footer = "Scene paused | Click to stage | Play demo to record | F3 to return"}
Demo.__index = Demo

function Demo.new(game)
  local valid = game and game.player and game.knight and game.spawner
  local settings = valid and game.demo or nil
  settings = settings or {autoSpawn = false, hideHud = false, creature = 1, count = 1, tool = "spawn"}
  if valid then game.demo = settings end
  return setmetatable({game = valid and game or nil, settings = settings, ui = UI.new(), tab = "Stats"}, Demo)
end

-- A fresh run is available when opening debug from the main menu.
function Demo:startGame()
  GS.pop()
  GS.switch(require("gamestate.game"))
  local debugState = require("gamestate.debug")
  GS.push(debugState)
  debugState:selectTest(Demo)
end

function Demo:play()
  require("debug.hud").visible = false
  GS.pop()
  if GS.current() == require("gamestate.pause") then GS.pop() end
end

function Demo:clearEnemies()
  -- Remove silently: no death bursts, sounds or drops in a staged shot.
  self.game.creatures.creatures = {}
  self.game.projectiles:destroy()
end

function Demo:adjust(label, value, min, max, step, y, apply)
  self.ui:Label(string.format("%s: %g", label, value), 28, y, 250, 32)
  if self.ui:Button("-", {id = label.."-"}, 280, y, 34, 32).hit then
    apply(math.max(min, value-step))
  end
  if self.ui:Button("+", {id = label.."+"}, 320, y, 34, 32).hit then
    apply(math.min(max, value+step))
  end
end

function Demo:update(dt)
  UI.begin(self.ui)
  if not self.game then
    if self.ui:Button("Start demo game", 300, 300, 360, 44).hit then return self:startGame() end
    return
  end
  local game, s = self.game, self.settings
  if self.ui:Button("Play demo", UI.width-200, 20, 180, 40).hit then return self:play() end
  for i, tab in ipairs({"Stats", "Spawn", "Scene"}) do
    if self.ui:Button(tab, 28+(i-1)*110, 76, 104, 36).hit then self.tab = tab end
  end
  if self.tab == "Stats" then
    local k, p = game.knight, game.player
    self:adjust("Knight HP", k.health, 0, k.stats.maxHealth*2, 5, 130, function(v) k:setHealth(v) end)
    self:adjust("Knight max HP", k.stats.maxHealth, 5, 1000, 5, 172, function(v)
      k.stats.maxHealth = v; k:setHealth(k.health)
    end)
    self:adjust("Knight speed", k.stats.speed, 0, 1000, 10, 214, function(v) k.stats.speed = v end)
    self:adjust("Healer speed", p.stats.speed, 0, 1000, 10, 256, function(v) p.stats.speed = v end)
    self:adjust("Healing rate", p.stats.healSpeed, 0, 500, 5, 298, function(v) p.stats.healSpeed = v end)
    self:adjust("Charge regen", game.healResource.regenRate, 0, 500, 5, 340, function(v) game.healResource.regenRate = v end)
    if self.ui:Button("Refill healing charge", 28, 390, 326, 36).hit then
      game.healResource:add(game.healResource.stats.maxHealth)
    end
    if self.ui:Button("Knight: full safe health", 28, 434, 326, 36).hit then k:setHealth(k.stats.maxHealth) end
  elseif self.tab == "Spawn" then
    for i, creature in ipairs(creatures) do
      if self.ui:Button((s.creature == i and "> " or "")..creature[2], 28, 124+(i-1)*40, 326, 34).hit then
        s.creature, s.tool = i, "spawn"
      end
    end
    self:adjust("Per click", s.count, 1, 20, 1, 374, function(v) s.count = v end)
    if self.ui:Button("Clear creatures / shots", 28, 422, 326, 36).hit then self:clearEnemies() end
  else
    local function button(label, row) return self.ui:Button(label, 28, 130+row*46, 326, 36).hit end
    if button("Auto spawn: "..(s.autoSpawn and "ON" or "OFF"), 0) then s.autoSpawn = not s.autoSpawn end
    if button("Game HUD: "..(s.hideHud and "hidden" or "visible"), 1) then s.hideHud = not s.hideHud end
    if button("Place knight on click", 2) then s.tool = "knight" end
    if button("Place healer on click", 3) then s.tool = "healer" end
    if button("Clear creatures / shots", 4) then self:clearEnemies() end
    if button("Refill healing charge", 5) then game.healResource:add(game.healResource.stats.maxHealth) end
  end
end

function Demo:mousepressed(x, y, button)
  if not self.game or button ~= 1 or x <= 380 or y <= 76 or y >= UI.height-60 then return end
  local g, s = self.game, self.settings
  local wx, wy = x-UI.width/2+g.player.x, y-UI.height/2+g.player.y
  if s.tool == "knight" then
    g.knight.position = vector(wx, wy)
    g.knight:setPatrolRadius(g.knight.patrolRadius or 600)
    g.knight.destination = nil
    if not g.knight.dying and not g.knight.dead then g.knight.state = "idle" end
  elseif s.tool == "healer" then
    g.player.x, g.player.y = wx, wy
    g.player.shape:moveTo(wx, wy)
    g.map:update(wx, wy, UI.width, UI.height)
  else
    for i = 1, s.count do
      local angle = (i-1)*math.pi*2/s.count
      local radius = s.count == 1 and 0 or 18*math.sqrt(s.count)
      g.spawner:spawnAt(creatures[s.creature][1], wx+math.cos(angle)*radius, wy+math.sin(angle)*radius)
    end
  end
end

function Demo:draw()
  if not self.game then
    UI.heading("Demo staging", "Start a fresh game to stage a recording.")
  else
    self.game:drawWorld()
    Skin.panel(16, 16, 352, UI.height-80)
    love.graphics.setFont(Skin.font(24))
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Demo staging - "..self.tab, 28, 30)
    love.graphics.print("Click: "..self.settings.tool, 392, 28)
  end
  UI.draw(self.ui)
end

return Demo
