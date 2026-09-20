local Gamestate = require("gamestate.deps").Gamestate
local UI = require("gamestate.ui")
local CreatureSystem = require("systems.creature")
local ProjectileSystem = require("systems.projectile")
local MapSystem = require("systems.map")
local FxSystem = require("systems.fx")
local WorldCanvas = require("src.world_canvas")
local DrawQueue = require("fx.draw_queue")
local vector = require("lib.hump.vector")
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
---@field fx FxSystem
---@field worldCanvas WorldCanvas
---@field healingEmitter? FxEmitter
---@field dustDistance number
---@field knightDustDistance number
---@field pickups Pickups
---@field spawner Spawner
---@field timer number Seconds since the game started.
---@field hud GameHud
---@field healResource HealResource
---@field score integer Coins collected during the current run.
local game = {isMenu = false}
local Player = require("src.player")
local HC = require("lib.HC")
local Pickups = require("src.pickups")
local Knight = require("src.knight")
local Spawner = require("systems.spawner")
local Hud = require("ui.hud")
local HealResource = require("src.heal_resource")

function game:enter(previous)
  self.score = 0
  self.fx = FxSystem.new()
  self.worldCanvas = WorldCanvas.new()
  self.healingEmitter = nil
  self.dustDistance = 0
  self.knightDustDistance = 0
  self.ui = UI.new()
  self.healResource = HealResource.new(100, 5)
  self.player = Player.new(0, 0)
  self.player.shape = HC.circle(self.player.x, self.player.y, 16)
  self.map = MapSystem.new({ seed = 1 })
  self.map:update(self.player.x, self.player.y, UI.width, UI.height)

  self.pickups = Pickups.new(self.player)
  self.pickups:spawn(15)

  self.creatures = CreatureSystem.new(self.fx)
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
  self.hud = Hud.new(self)
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
  local oldX, oldY = self.player.x, self.player.y
  Player.update(game.player, dt, self.healResource)
  self.healResource:update(dt, self.player.currentBeam ~= nil)
  self.pickups:update(dt)
  self.map:resolveMovement(self.player, oldX, oldY)
  self.map:update(self.player.x, self.player.y, UI.width, UI.height)
  self.pickups:checkCollected(self.player, self.knight, self)
  local function traceBeam(origin, destination, radius)
    return self.map:traceProjectile(origin, destination, radius)
  end
  for _, beam in ipairs(self.player.allBeams or {}) do
    beam:clipAgainstWorld(traceBeam, vector(self.player.x, self.player.y))
    beam:updateImpact(dt, self.fx)
  end
  local dx, dy = self.player.x - oldX, self.player.y - oldY
  self.dustDistance = self.dustDistance + math.sqrt(dx * dx + dy * dy)
  if self.dustDistance >= 24 then
    self.fx:emit("dust", self.player.x, self.player.animation:getFeetY(self.player.y))
    self.dustDistance = self.dustDistance % 24
  end
  if Player.resolveKick(self.player, self.creatures, self.projectiles, self.fx) then
    self.fx:emit("dust", self.player.x, self.player.animation:getFeetY(self.player.y))
  end

  local knightX, knightY = self.knight.position.x, self.knight.position.y
  self.knight:update(dt, self.creatures, game.player)
  local kdx, kdy = self.knight.position.x - knightX, self.knight.position.y - knightY
  self.knightDustDistance = self.knightDustDistance + math.sqrt(kdx * kdx + kdy * kdy)
  if self.knightDustDistance >= 24 then
    self.fx:emit("dust", self.knight.position.x, self.knight.animation:getFeetY(self.knight.position.y))
    self.knightDustDistance = self.knightDustDistance % 24
  end


  self.spawner:update(dt, self.player.x, self.player.y)

  ---@type CreatureSystemContext
  local context = {
    knight = self.knight,
    projectiles = self.projectiles,
    fx = self.fx,
    healer = self.healer,
    resolveKnockback = function(creature, destination)
      return self.map:resolveKnockback(creature.position, destination, 6 * creature.scale)
    end,
  }
  self.creatures:update(dt, context)
  self.projectiles:update(dt, {
    fx = self.fx,
    knight = self.knight,
    traceWorld = function(origin, destination, radius)
      return self.map:traceProjectile(origin, destination, radius)
    end,
  })

  local feetY = self.knight.animation:getFeetY(self.knight.position.y)
  if self.knight.healedThisUpdate and not self.knight.dead and not self.knight.overhealed then
    if not self.healingEmitter then
      self.healingEmitter = self.fx:start("healing", self.knight.position.x, self.knight.position.y, {depth = feetY})
    end
    self.healingEmitter:setPosition(self.knight.position.x, self.knight.position.y, feetY)
  elseif self.healingEmitter then
    self.healingEmitter:stop()
    self.healingEmitter = nil
  end
  self.fx:update(dt)
  self.hud:update(dt, self)

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
  self.worldCanvas:draw(function()
    love.graphics.translate(UI.width / 2 - self.player.x, UI.height / 2 - self.player.y)
    self.map:drawFloor()
    self.fx:draw("ground")
    self.pickups:draw()
    local queue = DrawQueue.new()
    for _, creature in ipairs(self.creatures:getAll()) do
      queue:add(self.creatures:getFeetY(creature), function() self.creatures:drawCreature(creature) end)
    end
    queue:add(self.knight.animation:getFeetY(self.knight.position.y), function() self.knight:draw() end)
    queue:add(self.player.animation:getFeetY(self.player.y), function() Player.draw(self.player) end)
    -- Pillars cover bodies at equal depth until their feet move in front.
    for _, structure in ipairs(self.map:getVisibleStructures()) do
      queue:add(structure.y, function() structure:draw() end)
    end
    for _, shot in ipairs(self.projectiles.projectiles) do
      queue:add(shot.position.y, function() self.projectiles:drawProjectile(shot) end)
    end
    for _, particle in ipairs(self.fx.particles) do
      if particle.preset.layer == "air" then
        queue:add(particle.depth, function() self.fx:drawParticle(particle) end)
      end
    end
    queue:draw()
  end)
end

function game:draw()
  self:drawScene()
  self:drawUI()
end

function game:drawScene()
  self:drawWorld()
end

function game:drawUI()
  UI.draw(self.ui)
  self.hud:draw(self)
  UI.healBar(self.healResource)
end

function game:leave()
  for _, beam in ipairs(self.player.allBeams or {}) do beam:destroy() end
  self.fx:destroy()
  self.worldCanvas:destroy()
  self.healingEmitter = nil
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

function game:gamepadpressed(joystick, button)
  if button == "start" then
    return Gamestate.push(require("gamestate.pause"))
  end
end

return game
