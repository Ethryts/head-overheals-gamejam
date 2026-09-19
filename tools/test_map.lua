-- Run from the repository root: lua tools/test_map.lua
package.path = "game/?.lua;game/?/init.lua;game/src/?.lua;" .. package.path

local imageLoads, batchesCreated, batchesAlive, drawn = 0, 0, 0, 0
love = {
  math = {
    -- A deterministic stand-in: MapSystem must seed a private stream per chunk.
    newRandomGenerator = function(seed)
      local state = seed % 2147483647 + 1
      return {random = function(_, low, high)
        state = state * 48271 % 2147483647
        return low + state % (high - low + 1)
      end}
    end,
  },
  graphics = {
    newImage = function(path)
      local file = assert(io.open("game/" .. path, "rb"))
      local header = file:read(24)
      file:close()
      assert(header:sub(17, 24) == "\0\0\0\16\0\0\0\16", "Floor tiles must be 16x16")
      imageLoads = imageLoads + 1
      return {path = path, setFilter = function(_, min, mag)
        assert(min == "nearest" and mag == "nearest")
      end}
    end,
    newSpriteBatch = function(image, capacity, usage)
      assert(usage == "static")
      batchesCreated, batchesAlive = batchesCreated + 1, batchesAlive + 1
      return {
        tiles = {},
        add = function(self, x, y)
          assert(not self.released and #self.tiles < capacity)
          self.tiles[#self.tiles + 1] = x .. "," .. y
        end,
        flush = function(self) self.flushed = true end,
        release = function(self)
          assert(not self.released, "Batch released twice")
          self.released = true
          batchesAlive = batchesAlive - 1
        end,
      }
    end,
    push = function() end, pop = function() end, setColor = function() end,
    draw = function(batch)
      assert(batch.flushed and not batch.released)
      drawn = drawn + 1
    end,
  },
}
local MapSystem = require("systems.map")
local function count(t)
  local n = 0
  for _ in pairs(t) do n = n + 1 end
  return n
end
local function signature(chunk)
  local parts = {}
  for tile = 1, 10 do
    local batch = chunk.batches[tile]
    parts[#parts + 1] = tile .. ":" .. (batch and table.concat(batch.tiles, ";") or "")
  end
  return table.concat(parts, "|")
end

local originalRandom = math.random
math.random = function() error("Map generation must not use global RNG") end
local map = MapSystem.new({seed = "test-world"})
map:update(0, 0, 960, 540)
assert(imageLoads == 10 and count(map.chunks) == 16 and #map.visible == 4)
local original = map.chunks["-2:-2"]
local layout = signature(original)
local created = batchesCreated
map:update(0, 0, 960, 540)
assert(batchesCreated == created, "Stationary update must reuse cached batches")
map:draw()
assert(batchesCreated == created and drawn > 0 and drawn <= 40, "Draw only visible cached chunks")
map:update(600, 0, 960, 540)
assert(map.chunks["-2:-2"] == original, "Retain chunks outside load margin but inside unload margin")
map:update(1600, 0, 960, 540)
assert(map.chunks["-2:-2"] == nil, "Evict chunks beyond unload margin")
for _, batch in pairs(original.batches) do assert(batch.released) end
map:update(0, 0, 960, 540)
assert(signature(map.chunks["-2:-2"]) == layout, "Regenerate identical layout after unloading")

local other = MapSystem.new({seed = "test-world"})
other:update(-10000, 8000, 960, 540)
other:update(0, 0, 960, 540)
assert(imageLoads == 10, "Share tile images across maps")
for id, chunk in pairs(other.chunks) do
  assert(signature(chunk) == signature(map.chunks[id]), "Generation is independent of travel order")
end
other:destroy()
local different = MapSystem.new({seed = "different-world"})
different:update(0, 0, 960, 540)
assert(signature(different.chunks["-2:-2"]) ~= layout, "Seed changes the layout")
different:destroy()
for step = 1, 100 do
  map:update(step * 600, -step * 300, 960, 540)
  assert(count(map.chunks) <= 35 and batchesAlive <= 350, "Travel must keep memory bounded")
end
map:update(-100000, -100000, 960, 540)
assert(count(map.chunks) <= 20 and map.chunks["0:0"] == nil,
  "Teleport loads only the destination")
map:update(0, 0, 1920, 1080)
assert(#map.visible > 4, "Changing view dimensions changes visible coverage")
map:destroy()
map:destroy()
assert(batchesAlive == 0)

local spawned, destroyed, structureDraws = 0, 0, 0
local structures = MapSystem.new({seed = "test-world", createStructures = function(context)
  assert(context.x == context.chunkX * context.size and context.y == context.chunkY * context.size)
  for _ = 1, 20 do context.random:random(1, 10) end
  spawned = spawned + 1
  return {{
    draw = function() structureDraws = structureDraws + 1 end,
    destroy = function() destroyed = destroyed + 1 end,
  }}
end})
structures:update(0, 0, 960, 540)
assert(signature(structures.chunks["-2:-2"]) == layout, "Structures use an independent random stream")
structures:draw()
assert(spawned == 16 and structureDraws == 4)
structures:update(100000, 100000, 960, 540)
assert(destroyed == 16, "Unloading destroys structure resources")
structures:destroy()
assert(spawned == destroyed and batchesAlive == 0)

local removed
package.preload["lib.HC"] = function() return {remove = function(shape) removed = shape end} end
local Structure = require("src.structure")
local structure = Structure.new(12, 34)
assert(not structure:collidesWith({}))
local shape = {collidesWith = function() return true end}
structure.shape = shape
assert(structure:collidesWith({}))
structure:destroy()
structure:destroy()
assert(removed == shape and structure.shape == nil)
math.random = originalRandom
print("Map tests passed: deterministic generation, signed coordinates, caching, margins, bounded memory, structure lifecycle")
