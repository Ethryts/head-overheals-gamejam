local UI = require("gamestate.ui")
local Knight = require("src.knight")

local test = {
  label = "Set knight health",
  footer = "Drag slider / +/-: set health     Esc: test menu     F3: exit debug     F4: HUD",
}
test.__index = test

function test.new(game)
  local knight = game and game.knight
  return setmetatable({
    knight = knight,
    ui = UI.new(),
    health = { value = knight and knight.health or 0, min = 0, max = Knight.OVERHEAL_LIMIT },
  }, test)
end

function test:update(dt)
  UI.begin(self.ui)
  if not self.knight then return end

  local x = (UI.width - 360) / 2
  local changed = self.ui:Slider(self.health, x, 270, 360, 28).changed
  if self.ui:Button("-1", x, 318, 172, 40).hit then
    self.health.value = self.health.value - 1
    changed = true
  end
  if self.ui:Button("+1", x + 188, 318, 172, 40).hit then
    self.health.value = self.health.value + 1
    changed = true
  end
  if changed then
    self.knight:setHealth(math.floor(self.health.value + 0.5))
    self.health.value = self.knight.health
  end
end

function test:draw()
  if not self.knight then
    UI.heading(self.label, "Start a game first to edit the knight's health.")
  else
    local status = self.knight.dead and "Dead" or self.knight.overhealed and "Overhealed" or "Alive"
    UI.heading(self.label, string.format("HP: %d / %d (%s)",
      self.knight.health, self.health.max, status))
    self.knight.animation:draw(UI.width / 2, 420, self.knight.direction)
  end
  UI.draw(self.ui)
end

return test
