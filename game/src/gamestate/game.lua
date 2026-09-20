local Gamestate = require("gamestate.deps").Gamestate
local UI = require("gamestate.ui")
local CreatureSystem = require("systems.creature")
local ProjectileSystem = require("systems.projectile")
local MapSystem = require("systems.map")
---@class GameContext
---@field player? Player
---@field knight? Knight
---@field healer? CreatureActor Optional vector-based healer target for creature behaviors.

---@class GameResult
---@field title? string
---@field message? string

---@class GameState: GameContext Fields are initialized by enter().
---@field player Player
---@field knight Knight
---@field map MapSystem
---@field creatures CreatureSystem
---@field projectiles ProjectileSystem
---@field pickups Pickups
---@field spawner Spawner
---@field timer number Seconds since the game started.
---@field score integer Coins collected during the current run.
local game = {}
local Player = require("src.player")
local HC = require("lib.HC")
local Pickups = require("src.pickups")
local Knight = require("src.knight")
local Spawner = require("systems.spawner")
local HealResource = require("src.heal_resource")

function game:enter(previous)
  self.score = 0
  self.ui = UI.new()
  self.healResource = HealResource.new(100, 5)
  self.player = Player.new(0, 0)
  self.player.shape = HC.circle(self.player.x, self.player.y, 16)
  self.map = MapSystem.new({ seed = 1 })
  self.map:update(self.player.x, self.player.y, UI.width, UI.height)

  self.pickups = Pickups.new(self.player)
  self.pickups:spawn(15)

  self.creatures = CreatureSystem.new()
  self.creatures:create("death_slime", UI.width / 2, UI.height / 2, {
    scale = 4,
  })

  self.knight = Knight.new(0, 0)
  self.knight:setPatrolRadius(600)

  self.spawner = Spawner.new(self.creatures, {
    interval = 2.5,
    speed = 60,
    scale = 2,
  })
  self.projectiles = ProjectileSystem.new()
end

function game:resume(previous)
  self.ui = UI.new()
  Player.resume(self.player)
end

---@param dt number Elapsed seconds.
function game:update(dt)
  game.timer = (game.timer or 0) + dt
  self.spawner.interval = math.max(0.5, 2.5 - game.timer / 30) -- gradually increase spawn rate over time

  UI.begin(self.ui)
  if self.ui:Button("Pause", UI.width - 144, 20, 120, 40).hit then
    return Gamestate.push(require("gamestate.pause"))
  end

  local oldX, oldY = self.player.x, self.player.y
  Player.update(game.player, dt, self.healResource)
  self.healResource:update(dt, self.player.currentBeam ~= nil)
  self.pickups:update(dt)
  self.map:resolveMovement(self.player, oldX, oldY)
  self.map:update(self.player.x, self.player.y, UI.width, UI.height)
  self.pickups:checkCollected(self.player, self.knight, self)
  Player.resolveKick(self.player, self.creatures, self.projectiles)

  self.knight:update(dt, self.creatures, game.player, self.healResource)


  self.spawner:update(dt, self.player.x, self.player.y)

  ---@type CreatureSystemContext
  local context = {
    knight = self.knight,
    projectiles = self.projectiles,
    healer = self.healer,
    resolveKnockback = function(creature, destination)
      return self.map:resolveKnockback(creature.position, destination, 6 * creature.scale)
    end,
  }
  self.creatures:update(dt, context)
  self.projectiles:update(dt, {
    knight = self.knight,
    traceWorld = function(origin, destination, radius)
      return self.map:traceProjectile(origin, destination, radius)
    end,
  })

  if self.knight.dead then
    Gamestate.soundEffectsSystem:stopAllSoundEffects()
    Gamestate.soundEffectsSystem:playSoundEffect("Death")
    return self:finish({ title = "You lost", message = "The knight has fallen." })
  elseif self.knight.overhealed then
    Gamestate.soundEffectsSystem:stopAllSoundEffects()
    Gamestate.soundEffectsSystem:playSoundEffect("HeadOverhealed")
    return self:finish({ title = "Overhealed", message = "The knight's head exploded." })
  end

  Gamestate.musicSystem:receiveHealthUpdate(self.knight:GetHealthPercentage())
  -- When finished: return self:finish({ title = "Finished", message = "..." })
end

function game:drawWorld()
  -- Keep drawing free of updates; pause also calls this method.
  UI.background()
  love.graphics.push("all")
  love.graphics.translate(UI.width / 2 - self.player.x, UI.height / 2 - self.player.y)
  local playerFeetY = self.player.animation:getFeetY(self.player.y)
  self.map:draw(playerFeetY)
  self.pickups:draw()
  self.creatures:draw()
  self.knight:draw()
  Player.draw(self.player)
  self.projectiles:draw()
  self.map:drawForeground(playerFeetY)
  love.graphics.pop()
end

function game:draw()
  self:drawWorld()
  UI.draw(self.ui)
  love.graphics.print("Score: " .. self.score, 24, 20)
  self.player.kick:drawStatus(24, 48)
  UI.footer("Esc: pause     F2: preview end screen, F3: debug, F4: debug HUD")
  UI.healBar(self.healResource)
end

function game:leave()
  self.pickups:destroy()
  self.projectiles:destroy()
  HC.remove(self.player.shape)
  self.map:destroy()
end

---@param result GameResult
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
