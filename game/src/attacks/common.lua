local common = {}

-- Cooldowns advance even when knockback prevents an attack this update.
---@param creature Creature
---@param dt number
---@param context CreatureSystemContext
---@param canAttack boolean
---@param defaultRange number
---@return ProjectileTarget? target
function common.readyTarget(creature, dt, context, canAttack, defaultRange)
  creature.attackCooldownRemaining = math.max(0, creature.attackCooldownRemaining - dt)
  if not canAttack or creature.health <= 0 or not creature.attack
      or creature.attackCooldownRemaining > 0 then return nil end
  local target = context.knight
  if not (target and target.position and type(target.takeDamage) == "function")
      or target.dead or target.overhealed then return nil end
  local range = creature.attack.range or defaultRange
  if (target.position - creature.position):len() <= range + 1e-7 then return target end
end

return common
