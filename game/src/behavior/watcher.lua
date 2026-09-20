local vector = require("lib.hump.vector")
local idle = require("behavior.idle")
local chase = require("behavior.chase")

---@class WatcherMovementState
---@field cooldown number Seconds before another dodge can start.
---@field remaining number Seconds of the current dodge remaining.
---@field direction HumpVector Locked dodge direction.
---@field orbitDirection number Clockwise or counterclockwise orbit.

---@type CreatureMovementBehavior
local watcher = {}
watcher.tuning = {dodgeRange = 110, dodgeDistance = 64, dodgeDuration = 0.18, cooldown = 2.25, orbitRadius = 220}

local function move(creature, dt, context)
  if context.resolveMovement then
    local destination = context.resolveMovement(creature, creature.position + creature.velocity * dt)
    creature.velocity = (destination - creature.position) / dt
  end
end

function watcher.update(creature, dt, context)
  if dt <= 0 then return idle.update(creature, dt, context) end
  local state = creature.watcher
  if not state then
    state = {cooldown = 0, remaining = 0, direction = vector(1, 0),
      orbitDirection = math.floor(creature.position.x + creature.position.y) % 2 == 0 and 1 or -1}
    creature.watcher = state
  end
  state.cooldown = math.max(0, state.cooldown - dt)
  local healer = context.healer
  if state.remaining <= 0 and state.cooldown <= 0 and healer then
    local away = creature.position - healer.position
    if away:len() <= watcher.tuning.dodgeRange then
      if away:len() == 0 then away = vector(state.orbitDirection, 0) end
      state.direction = away:normalized()
      state.remaining = watcher.tuning.dodgeDuration
      state.cooldown = watcher.tuning.cooldown
      state.orbitDirection = -state.orbitDirection
      if context.fx then
        context.fx:emit("dodge", creature.position.x, creature.position.y, {
          angle = math.atan2(-state.direction.y, -state.direction.x),
          depth = creature.position.y + 8*creature.scale,
        })
      end
    end
  end
  if state.remaining > 0 then
    local activeDt = math.min(dt, state.remaining)
    state.remaining = math.max(0, state.remaining - activeDt)
    creature.velocity = state.direction * (watcher.tuning.dodgeDistance / watcher.tuning.dodgeDuration * activeDt / dt)
    move(creature, dt, context)
    return
  end

  local knight = context.knight
  if not knight then return idle.update(creature, dt, context) end
  local offset = knight.position - creature.position
  local distance = offset:len()
  if distance > watcher.tuning.orbitRadius + 60 then
    chase.update(creature, dt, context)
  else
    local toward = distance > 0 and offset / distance or vector(1, 0)
    local radialSpeed = math.max(-creature.speed, math.min(creature.speed,
      (distance - watcher.tuning.orbitRadius) / dt))
    local tangent = vector(-toward.y, toward.x) * state.orbitDirection
    creature.velocity = toward*radialSpeed + tangent*creature.speed*0.65
    if creature.velocity:len() > creature.speed then
      creature.velocity = creature.velocity:normalized()*creature.speed
    end
  end
  move(creature, dt, context)
end

return watcher
