local Gamestate = require("gamestate.deps").Gamestate
local UI = require("gamestate.ui")
local CreatureSystem = require("systems.creature")
local game = {}

function game:enter(previous)
  self.ui = UI.new()
  self.creatures = CreatureSystem.new()
  self.creatures:create("death_slime", UI.width / 2 - 32, UI.height / 2, {
    scale = 4,
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

  self.creatures:update(dt)
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
  UI.draw(self.ui)
  UI.footer("Esc: pause     F2: preview end screen")
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
