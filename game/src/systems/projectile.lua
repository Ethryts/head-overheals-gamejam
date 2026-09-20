---@class ProjectileTarget: CreatureActor
---@field dead? boolean
---@field overhealed? boolean
---@field takeDamage fun(self: ProjectileTarget, amount: number)

---@class ProjectileOptions
---@field position HumpVector World-space origin; copied on spawn.
---@field direction HumpVector Normalized on spawn.
---@field speed? number Defaults to 240 world pixels per second.
---@field damage? number Defaults to 1.
---@field radius? number Defaults to 4 world pixels.
---@field lifespan? number Defaults to 3 seconds.
---@field owner? Creature

---@class Projectile
---@field position HumpVector
---@field velocity HumpVector World pixels per second; fixed at firing time.
---@field damage number
---@field radius number
---@field lifespan number Seconds remaining.
---@field owner? Creature Attribution only; shots survive their owner's death.

---@class ProjectileContext
---@field knight? ProjectileTarget
---@field fx? FxSystem
---@field traceWorld? fun(origin: HumpVector, destination: HumpVector, radius: number): number? Earliest blocking fraction in [0, 1].

---@class ProjectileSystem
---@field projectiles Projectile[]
local ProjectileSystem = {}
ProjectileSystem.__index = ProjectileSystem

---@return ProjectileSystem
function ProjectileSystem.new()
  return setmetatable({ projectiles = {} }, ProjectileSystem)
end

---@param options ProjectileOptions
---@return Projectile? projectile Nil for a zero direction or nonpositive speed/lifespan.
function ProjectileSystem:spawn(options)
  local speed, lifespan = options.speed or 240, options.lifespan or 3
  if options.direction:len() == 0 or speed <= 0 or lifespan <= 0 then return nil end
  local projectile = {
    position = options.position:clone(), velocity = options.direction:normalized() * speed,
    damage = options.damage or 1, radius = options.radius or 4,
    lifespan = lifespan, owner = options.owner,
  }
  assert(projectile.radius >= 0, "Projectile radius must be nonnegative")
  self.projectiles[#self.projectiles + 1] = projectile
  return projectile
end

-- Swept point against a circle expanded by the projectile's radius.
local function traceKnight(origin, destination, center, radius)
  local offset, delta = origin - center, destination - origin
  local c = offset.x * offset.x + offset.y * offset.y - radius * radius
  if c <= 0 then return 0 end
  local a = delta.x * delta.x + delta.y * delta.y
  if a == 0 then return nil end
  local b = offset.x * delta.x + offset.y * delta.y
  local discriminant = b * b - a * c
  if discriminant < 0 then return nil end
  local t = (-b - math.sqrt(discriminant)) / a
  if t >= 0 and t <= 1 then return t end
end

---@param dt number
---@param context? ProjectileContext
function ProjectileSystem:update(dt, context)
  if dt <= 0 then return end
  context = context or {}
  for i = #self.projectiles, 1, -1 do
    local shot = self.projectiles[i]
    local travelTime = math.min(dt, shot.lifespan)
    local destination = shot.position + shot.velocity * travelTime
    local wall = context.traceWorld and context.traceWorld(shot.position, destination, shot.radius)
    local knight, target = context.knight, nil
    if knight and not knight.dead and not knight.overhealed then
      target = traceKnight(shot.position, destination, knight.position, 16 + shot.radius)
    end
    if target and (not wall or target < wall) then
      knight:takeDamage(shot.damage)
    end
    local impact = wall and target and math.min(wall, target) or wall or target
    if impact and context.fx then
      local at = shot.position + (destination - shot.position) * impact
      context.fx:emit("sparks", at.x, at.y, {angle = math.atan2(-shot.velocity.y, -shot.velocity.x)})
    end
    shot.lifespan = shot.lifespan - travelTime
    if wall or target or shot.lifespan <= 0 then
      table.remove(self.projectiles, i)
    else
      shot.position = destination
    end
  end
end

---@param shot Projectile
function ProjectileSystem:drawProjectile(shot)
  love.graphics.push("all")
  love.graphics.setColor(1, 0.2, 0.15, 1)
  love.graphics.circle("fill", shot.position.x, shot.position.y, shot.radius)
  love.graphics.pop()
end

function ProjectileSystem:draw()
  for _, shot in ipairs(self.projectiles) do self:drawProjectile(shot) end
end

---@param predicate fun(projectile: Projectile): boolean
---@return integer removed
function ProjectileSystem:removeWhere(predicate)
  local removed = 0
  for i = #self.projectiles, 1, -1 do
    if predicate(self.projectiles[i]) then
      table.remove(self.projectiles, i)
      removed = removed + 1
    end
  end
  return removed
end

function ProjectileSystem:destroy()
  self.projectiles = {}
end

return ProjectileSystem
