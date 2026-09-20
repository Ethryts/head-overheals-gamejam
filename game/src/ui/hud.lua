local Skin = require("ui.skin")
local Hud = {}
Hud.__index = Hud
local duration = 2
local stats = {
  { key = "speed",     label = "Speed" },
  { key = "maxHealth", label = "Max health" },
  { key = "healSpeed", label = "Heal rate" },
}

---@class GameHud
---@field values table<string, number>
---@field flashes table<string, {remaining: number, amount: number}>
---@field time number
---@return GameHud
function Hud.new(game)
  local self = setmetatable({ values = {}, flashes = {}, time = 0 }, Hud)
  self:update(0, game)
  return self
end

-- Observe actual stat changes, so item hooks remain independent of the HUD.
function Hud:update(dt, game)
  self.time = self.time + dt
  for key, flash in pairs(self.flashes) do
    flash.remaining = flash.remaining - dt
    if flash.remaining <= 0 then self.flashes[key] = nil end
  end
  local function track(key, value)
    local previous = self.values[key]
    if previous and value > previous then
      local flash = self.flashes[key]
      self.flashes[key] = {
        remaining = duration,
        amount = value - previous + (flash and flash.amount or 0)
      }
    end
    self.values[key] = value
  end
  track("score", game.score)
  for _, actor in ipairs({ "player", "knight" }) do
    for _, stat in ipairs(stats) do
      track(actor .. "." .. stat.key, game[actor].stats[stat.key] or 0)
    end
  end
end

function Hud:row(key, label, x, y)
  local flash = self.flashes[key]
  local glow = flash and flash.remaining / duration or 0
  if flash then
    love.graphics.setColor(0.15, 1, 0.4, glow * (0.14 + 0.06 * math.sin(self.time * 14)))
    love.graphics.rectangle("fill", x - 4, y, 144, 28)
  end
  love.graphics.setColor(0.8, 0.83, 0.85)
  love.graphics.print(label, x, y)
  love.graphics.setColor(flash and 0.4 or 1, 1, flash and 0.6 or 0.9)
  love.graphics.printf(string.format("%g", self.values[key]), x, y, 136, "right")
  if flash then
    love.graphics.setColor(0.4, 1, 0.6, math.min(1, glow * 3))
    love.graphics.print(string.format("+%g %s", flash.amount, label), x, y + 14)
  end
end

function Hud:draw(game)
  love.graphics.push("all")
  -- Keep the top-left margin while halving the panels, text and highlights together.
  love.graphics.translate(16, 16)
  love.graphics.scale(0.7, 0.7)
  love.graphics.translate(-16, -16)
  love.graphics.setFont(Skin.font(20))
  Skin.panel(16, 16, 176, 48)
  self:row("score", "Coins", 36, 28)
  for index, actor in ipairs({ "player", "knight" }) do
    local y = 72 + (index - 1) * 136
    Skin.panel(16, y, 176, 128)
    love.graphics.setColor(1, 0.8, 0.52)
    love.graphics.print(actor == "player" and "HEALER" or "KNIGHT", 36, y + 12)
    local row = 0
    for _, stat in ipairs(stats) do
      if actor ~= "player" or stat.key ~= "maxHealth" then
        self:row(actor .. "." .. stat.key, stat.label, 36, y + 32 + row * 28)
        row = row + 1
      end
    end
  end
  love.graphics.pop()
end

return Hud
