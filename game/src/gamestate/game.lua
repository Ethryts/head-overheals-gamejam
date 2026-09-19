local Gamestate = require("gamestate.deps").Gamestate
local UI = require("gamestate.ui")
local CreatureSystem = require("systems.creature")
local game = {}
local Player = require("src.player")
local HC = require("lib.HC")
local Pickups = require("src.pickups")
local Knight = require("src.knight")
local Spawner = require("systems.spawner")

function game:enter(previous)
  self.ui = UI.new()
  self.player = Player.new(400, 300)
  self.player.shape = HC.circle(self.player.x, self.player.y, 16)

  self.pickups = Pickups.new(1600, 1200) -- TODO replace with real dimensions
  self.pickups:spawn(15)

  self.creatures = CreatureSystem.new()
  self.creatures:create("death_slime", UI.width / 2, UI.height / 2, {
    scale = 4,
  })
  
  self.knight = Knight.new(UI.width / 2, UI.height / 2)
  self.knight:setPatrolArea(40, 40, UI.width - 40, UI.height - 40)

  self.spawner = Spawner.new(self.creatures, {
      interval = 2.5,
      speed = 60,
      scale = 2,
    })
end

function game:resume(previous)
  self.ui = UI.new()
  -- Resuming the game from pause
end

function game:update(dt)
  UI.begin(self.ui)
  if self.ui:Button("Pause", UI.width - 144, 20, 120, 40).hit then
    return Gamestate.push(require("gamestate.pause"))
  end
  Player.update(game.player, dt)
  self.pickups:checkCollected(self.player.shape)

  self.knight:update(dt, self.creatures)

  self.spawner:update(dt)

  ---@type CreatureSystemContext
  local context = { knight = self.knight, healer = self.healer }
  self.creatures:update(dt, context)
  -- When finished: return self:finish({ title = "Finished", message = "..." })
end

function game:drawWorld()
  -- Keep drawing free of updates; pause also calls this method.
  UI.background()
  UI.heading("Game", "Idle creature preview")
  self.creatures:draw()
end

function game:draw()
  self:drawWorld()
  self.pickups:draw()
  UI.draw(self.ui)
  UI.footer("Esc: pause     F2: preview end screen, F3: debug, F4: debug HUD")
  self.knight:draw()
  Player.draw(game.player)
end

function game:finish(result)
  return Gamestate.switch(require("gamestate.endscreen"), result)
end

function game:keypressed(key, scancode, isrepeat)
  if isrepeat then return end
  if key == "escape" then
    return Gamestate.push(require("gamestate.pause"))
  elseif key == "f2" then
    -- Temporary shortcut to end
    return self:finish({ title = "Run complete", message = "End screen preview" })
  end
  -- TODO: Your gameplay key bindings.
end

function game:focus(focused)
  if not focused then
    return Gamestate.push(require("gamestate.pause"))
  end
end

return game
