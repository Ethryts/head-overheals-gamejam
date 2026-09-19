local vector = require("lib.hump.vector")
local animations = require("systems.monster_animations")

---@class Attack
---@field type "melee"|"ranged"
---@field damage number
---@field cooldown number Seconds between attacks.
---@field animations? table<string, Anim8Animation>

---@class Creature
---@field kind string Monster catalog ID.
---@field health number
---@field speed number Game pixels per second; movement is not implemented yet.
---@field position HumpVector Top-left corner in game coordinates.
---@field velocity HumpVector
---@field image love.Image
---@field animations table<string, Anim8Animation>
---@field scale number
---@field attack? Attack

---@class CreatureOptions
---@field health? number Defaults to 1.
---@field speed? number Defaults to 0.
---@field scale? number Defaults to 1.
---@field frameDuration? number Seconds per frame; defaults to 0.2.

---@class CreatureSystem
---@field private creatures Creature[]
local CreatureSystem = {}
CreatureSystem.__index = CreatureSystem

---@return CreatureSystem
function CreatureSystem.new()
  return setmetatable({ creatures = {} }, CreatureSystem)
end

---@param monsterId string
---@param x number
---@param y number
---@param options? CreatureOptions
---@return Creature
function CreatureSystem:create(monsterId, x, y, options)
  options = options or {}
  local image, clips = animations.loadMonster(monsterId, options.frameDuration)
  ---@type Creature
  local creature = {
    kind = monsterId,
    health = options.health or 1,
    speed = options.speed or 0,
    position = vector(x, y),
    velocity = vector(0, 0),
    image = image,
    animations = clips,
    scale = options.scale or 1,
  }
  self.creatures[#self.creatures + 1] = creature
  return creature
end

---@param dt number Elapsed seconds.
function CreatureSystem:update(dt)
  for _, creature in ipairs(self.creatures) do
    creature.animations.idle:update(dt)
  end
end

function CreatureSystem:draw()
  love.graphics.push("all")
  love.graphics.setColor(1, 1, 1, 1)
  for _, creature in ipairs(self.creatures) do
    creature.animations.idle:draw(creature.image,
      creature.position.x, creature.position.y, 0, creature.scale, creature.scale)
  end
  love.graphics.pop()
end

return CreatureSystem
