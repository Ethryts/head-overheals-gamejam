local CreatureSystem = require("systems.creature")
local ProjectileSystem = require("systems.projectile")
local behavior = require("behavior")
local vector = require("lib.hump.vector")
local project = require("project")
local UI = require("gamestate.ui")
local viewport = require("src.viewport")
local Fx = require("systems.fx")

local options = {
  { id = "death_slime", label = "Death Slime" },
  { id = "bloodshot_eye", label = "Bloodshot Eye" },
  { id = "ochre_jelly", label = "Ochre Jelly" },
  { id = "ocular_watcher", label = "Ocular Watcher" },
  { id = "brawny_ogre", label = "Brawny Ogre" },
  { id = "humongous_ettin", label = "Two-headed Ogre" },
}
local dropdown = { x = project.width - 280, y = 20, width = 260, height = 36, spacing = 40 }

local test = { label = "Spawn creature on click" }
test.__index = test

function test.new()
  local projectiles = ProjectileSystem.new()
  local knight = {
    position = vector(project.width / 2, project.height / 2), health = 100,
    takeDamage = function(self, amount) self.health = math.max(0, self.health - amount) end,
  }
  return setmetatable({
    creatures = CreatureSystem.new(),
    projectiles = projectiles,
    ui = UI.new(),
    selectedCreature = options[1],
    dropdownOpen = false,
    ---@type CreatureSystemContext
    context = { knight = knight, projectiles = projectiles },
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
  if self.selectedCreature.id == "ocular_watcher" and not self.fx then
    self.fx = Fx.new()
    self.context.fx = self.fx
  end
  if self.fx then
    local x, y, inside = viewport.toGame(love.mouse.getPosition())
    self.context.healer = inside and {position = vector(x, y)} or nil
  end
  self.creatures:update(dt, self.context)
  if self.fx then self.fx:update(dt) end
  self.projectiles:update(dt, { knight = self.context.knight })
end

function test:draw()
  self.creatures:draw()
  self.projectiles:draw()
  if self.fx then
    self.fx:draw()
    if self.context.healer then
      local p = self.context.healer.position
      love.graphics.setColor(0.55, 0.9, 1)
      love.graphics.circle("line", p.x, p.y, 8)
      love.graphics.print("Healer (mouse)", p.x+12, p.y+8)
    end
  end
  local position = self.context.knight.position
  love.graphics.setColor(1, 0.75, 0.25, 1)
  love.graphics.circle("line", position.x, position.y, 8)
  love.graphics.line(position.x - 12, position.y, position.x + 12, position.y)
  love.graphics.line(position.x, position.y - 12, position.x, position.y + 12)
  love.graphics.print("Knight (stub) HP: " .. self.context.knight.health, position.x + 16, position.y - 8)
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
  local id = self.selectedCreature.id
  if id == "ocular_watcher" or id == "brawny_ogre" or id == "humongous_ettin" then
    self.creatures:create(id, x, y)
    return
  end
  self.creatures:create(self.selectedCreature.id, x, y, {
    movementBehavior = self.selectedCreature.id == "bloodshot_eye" and behavior.ranged or behavior.chase,
    speed = 60,
    scale = 2,
  })
end

function test:destroy()
  self.projectiles:destroy()
  if self.fx then self.fx:destroy() end
end

return test
