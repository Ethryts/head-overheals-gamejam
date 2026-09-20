local HC = require("lib.HC")
local Structure = require("src.structure")

---@class StructureImpact
---@field x number World-space contact point on the pillar footprint.
---@field y number
---@field normalX number Outward unit normal, pointing away from the pillar.
---@field normalY number

---@class StructureSystem
---@field world table Private HC world containing only this map's pillars.
---@field scale number
local StructureSystem = {}
StructureSystem.__index = StructureSystem

function StructureSystem.new(scale)
  return setmetatable({ world = HC.new(), scale = scale or 4 }, StructureSystem)
end

-- HC retains empty spatial-hash cells after removal and neighbor queries.
-- Drop those cells so exploring an endless map doesn't leave an empty history.
function StructureSystem:prune()
  local rows = self.world:hash().cells
  for x, row in pairs(rows) do
    for y, cell in pairs(row) do
      if next(cell) == nil then row[y] = nil end
    end
    if next(row) == nil then rows[x] = nil end
  end
end

-- All art and base colliders fit inside their placement cells, including at
-- chunk borders. Candidate order is fixed, and only the chunk RNG is used.
---@param context MapChunkContext
---@return MapStructure[]
function StructureSystem:createChunk(context)
  local result = {}
  local cellSize = 64 * self.scale
  local cells = math.floor(context.size / cellSize)
  local kinds = { "pillar_round", "pillar_square", "pillar_broken", "pillar_wide" }
  for row = 0, cells - 1 do
    for column = 0, cells - 1 do
      local roll = context.random:random(1, 100)
      local kind = kinds[context.random:random(1, #kinds)]
      local x = context.x + (column + 0.5) * cellSize
      local y = context.y + (row + 0.75) * cellSize
      -- Reserve a clear area around the player's origin, across all chunks.
      local clearSpawn = math.abs(x) < 48 * self.scale and math.abs(y) < 48 * self.scale
      if roll <= 55 and not clearSpawn then
        result[#result + 1] = Structure.new(kind, x, y, self.scale, self.world)
      end
    end
  end
  return result
end

---@param actor table Moving actor with x, y, and an HC shape.
---@param oldX number Position before movement.
---@param oldY number
---@param loadAt fun(x: number, y: number) Loads map geometry along the movement path.
---@param stopOnCollision? boolean Stop knockback at its first impact; ordinary movement slides.
---@return boolean collided
---@return StructureImpact? impact First contact point and outward normal.
function StructureSystem:resolveMovement(actor, oldX, oldY, loadAt, stopOnCollision)
  local dx, dy = actor.x - oldX, actor.y - oldY
  -- Substeps prevent a long frame from skipping completely over a pillar base.
  local steps = math.max(1, math.ceil(math.max(math.abs(dx), math.abs(dy)) / (2 * self.scale)))
  actor.shape:moveTo(oldX, oldY)
  local collided = false
  local impact
  local function separate()
    local contact = false
    local x, y = actor.shape:center()
    loadAt(x, y)
    for _ = 1, 4 do
      local candidates = {}
      for shape in pairs(self.world:neighbors(actor.shape)) do
        candidates[#candidates + 1] = shape
      end
      table.sort(candidates, function(a, b)
        local sa, sb = a.structure, b.structure
        if sa.y == sb.y then return sa.x < sb.x end
        return sa.y < sb.y
      end)
      local moved = false
      for _, shape in ipairs(candidates) do
        local hit, pushX, pushY = actor.shape:collidesWith(shape)
        if hit and (math.abs(pushX) > 1e-7 or math.abs(pushY) > 1e-7) then
          actor.shape:move(pushX, pushY)
          if not impact then
            local cx, cy = actor.shape:center()
            local left, top, right, bottom = shape:bbox()
            local length = math.sqrt(pushX * pushX + pushY * pushY)
            impact = {x = math.max(left, math.min(right, cx)), y = math.max(top, math.min(bottom, cy)),
              normalX = pushX / length, normalY = pushY / length}
          end
          moved = true
          contact = true
        end
      end
      if not moved then break end
    end
    return contact
  end
  -- Chasing monsters may already be inside a pillar when kicked.
  if stopOnCollision and separate() then
    actor.x, actor.y = actor.shape:center()
    return true, impact
  end
  for _ = 1, steps do
    actor.shape:move(dx / steps, dy / steps)
    local contact = separate()
    collided = collided or contact
    if stopOnCollision and contact then break end
  end
  actor.x, actor.y = actor.shape:center()
  return collided, impact
end

-- Slab intersection against a pillar footprint expanded by shot radius.
local function traceBox(origin, destination, left, top, right, bottom)
  local enter, leave = 0, 1
  local function axis(start, delta, low, high)
    if delta == 0 then return start >= low and start <= high end
    local a, b = (low - start) / delta, (high - start) / delta
    if a > b then a, b = b, a end
    enter, leave = math.max(enter, a), math.min(leave, b)
    return enter <= leave
  end
  if axis(origin.x, destination.x - origin.x, left, right)
      and axis(origin.y, destination.y - origin.y, top, bottom) then
    return enter
  end
end

---@param origin HumpVector
---@param destination HumpVector
---@param radius number
---@return number? fraction Earliest pillar impact along the segment.
function StructureSystem:traceProjectile(origin, destination, radius)
  local candidates = self.world:hash():inSameCells(
    math.min(origin.x, destination.x) - radius, math.min(origin.y, destination.y) - radius,
    math.max(origin.x, destination.x) + radius, math.max(origin.y, destination.y) + radius)
  local earliest
  for shape in pairs(candidates) do
    local left, top, right, bottom = shape:bbox()
    local hit = traceBox(origin, destination, left - radius, top - radius, right + radius, bottom + radius)
    if hit and (not earliest or hit < earliest) then earliest = hit end
  end
  return earliest
end

return StructureSystem
