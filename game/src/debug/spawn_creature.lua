local CreatureSystem = require("systems.creature")
local behavior = require("behavior")
local vector = require("lib.hump.vector")
local project = require("project")
local UI = require("gamestate.ui")

local options = {
  { id = "death_slime", label = "Death Slime" },
  { id = "bloodshot_eye", label = "Bloodshot Eye" },
  { id = "ochre_jelly", label = "Ochre Jelly" },
}
local dropdown = { x = project.width - 280, y = 20, width = 260, height = 36, spacing = 40 }

local test = { label = "Spawn creature on click" }
test.__index = test

function test.new()
  return setmetatable({
    creatures = CreatureSystem.new(),
    ui = UI.new(),
    selectedCreature = options[1],
    dropdownOpen = false,
    ---@type CreatureSystemContext
    context = { knight = { position = vector(project.width / 2, project.height / 2) } },
  }, test)
end

function test:update(dt)
  UI.begin(self.ui)
  if self.ui:Button("Creature: " .. self.selectedCreature.label .. " v",
      { id = "creature-selector" }, dropdown.x, dropdown.y, dropdown.width, dropdown.height).hit then
    self.dropdownOpen = not self.dropdownOpen
  end
  if self.dropdownOpen then
    for i, option in ipairs(options) do
      if self.ui:Button(option.label, { id = option.id }, dropdown.x,
          dropdown.y + i * dropdown.spacing, dropdown.width, dropdown.height).hit then
        self.selectedCreature = option
        self.dropdownOpen = false
      end
    end
  end
  self.creatures:update(dt, self.context)
end

function test:draw()
  self.creatures:draw()
  local position = self.context.knight.position
  love.graphics.setColor(1, 0.75, 0.25, 1)
  love.graphics.circle("line", position.x, position.y, 8)
  love.graphics.line(position.x - 12, position.y, position.x + 12, position.y)
  love.graphics.line(position.x, position.y - 12, position.x, position.y + 12)
  love.graphics.print("Knight (stub)", position.x + 16, position.y - 8)
  UI.draw(self.ui)
end

function test:mousepressed(x, y, button)
  if button ~= 1 then return end
  local height = dropdown.height + (self.dropdownOpen and #options * dropdown.spacing or 0)
  if x >= dropdown.x and x <= dropdown.x + dropdown.width
      and y >= dropdown.y and y <= dropdown.y + height then
    return -- SUIT handles the selector on release; never spawn underneath it.
  end
  if self.dropdownOpen then
    self.dropdownOpen = false
    return -- Clicking outside dismisses the dropdown without spawning.
  end
  self.creatures:create(self.selectedCreature.id, x, y, {
    behavior = behavior.chase,
    speed = 60,
    scale = 2,
  })
end

return test
