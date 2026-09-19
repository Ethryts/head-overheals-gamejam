---@class MapSystem
---@field seed integer|string
---@field private chunks table<string, table>
---@field private visible table[]
local MapSystem = {}
MapSystem.__index = MapSystem

local TILE_PIXELS = 16
local TILE_COUNT = 10
local images

local function loadImages()
  if not images then
    images = {}
    for i = 1, TILE_COUNT do
      local image = love.graphics.newImage(string.format("assets/images/Tileset/floor_%02d.png", i))
      image:setFilter("nearest", "nearest")
      images[i] = image
    end
  end
  return images
end

-- Keep products below 2^53 so this hash is exact in native and web Lua.
-- Separate channels let structures evolve without changing the floor tiles.
local function chunkSeed(seed, x, y, channel)
  local hash = 1
  local key = tostring(seed) .. ":" .. x .. ":" .. y .. ":" .. channel
  for i = 1, #key do hash = (hash * 131 + key:byte(i)) % 2147483647 end
  return hash
end

local function bounds(x, y, width, height, margin, chunkSize)
  return {
    left = math.floor((x - width * (0.5 + margin)) / chunkSize),
    right = math.ceil((x + width * (0.5 + margin)) / chunkSize) - 1,
    top = math.floor((y - height * (0.5 + margin)) / chunkSize),
    bottom = math.ceil((y + height * (0.5 + margin)) / chunkSize) - 1,
  }
end

local function key(x, y) return x .. ":" .. y end

local function releaseChunk(chunk)
  for _, structure in ipairs(chunk.structures) do structure:destroy() end
  for _, batch in pairs(chunk.batches) do batch:release() end
end

---@class MapChunkContext
---@field x number World-space left edge of the chunk.
---@field y number World-space top edge of the chunk.
---@field size number Chunk side length in world pixels.
---@field chunkX integer
---@field chunkY integer
---@field random love.RandomGenerator Private seeded generator for structure placement.

---@class MapOptions
---@field seed? integer|string Defaults to 1; the same seed recreates the same map.
---@field tileScale? number Defaults to 4 (64 world pixels per tile).
---@field chunkTiles? integer Defaults to 8 tiles per side.
---@field loadMargin? number Extra screen widths/heights beyond each edge; defaults to 0.5.
---@field unloadMargin? number Retention margin beyond each edge; defaults to 1.
---@field createStructures? fun(context: MapChunkContext): MapStructure[] Optional deterministic factory; defaults to empty chunks.

---@param options? MapOptions
---@return MapSystem
function MapSystem.new(options)
  options = options or {}
  local tileScale = options.tileScale or 4
  local chunkTiles = options.chunkTiles or 8
  local loadMargin = options.loadMargin or 0.5
  local unloadMargin = options.unloadMargin or 1
  assert(tileScale > 0, "tileScale must be positive")
  assert(chunkTiles > 0 and chunkTiles == math.floor(chunkTiles), "chunkTiles must be a positive integer")
  assert(loadMargin >= 0 and unloadMargin > loadMargin, "unloadMargin must exceed loadMargin >= 0")
  return setmetatable({
    seed = options.seed or 1,
    tileScale = tileScale,
    chunkTiles = chunkTiles,
    chunkSize = TILE_PIXELS * tileScale * chunkTiles,
    loadMargin = loadMargin,
    unloadMargin = unloadMargin,
    createStructures = options.createStructures,
    images = loadImages(),
    chunks = {},
    visible = {},
  }, MapSystem)
end


function MapSystem:createStructures(context: MapChunkContext)
  return {}
end

function MapSystem:createChunk(cx, cy)
  local random = love.math.newRandomGenerator(chunkSeed(self.seed, cx, cy, "floor"))
  local chunk = { x = cx, y = cy, batches = {}, structures = {} }
  for y = 0, self.chunkTiles - 1 do
    for x = 0, self.chunkTiles - 1 do
      local tile = random:random(1, TILE_COUNT)
      local batch = chunk.batches[tile]
      if not batch then
        batch = love.graphics.newSpriteBatch(self.images[tile], self.chunkTiles ^ 2, "static")
        chunk.batches[tile] = batch
      end
      batch:add(x * TILE_PIXELS, y * TILE_PIXELS)
    end
  end
  for _, batch in pairs(chunk.batches) do batch:flush() end
  if self.createStructures then
    chunk.structures = self.createStructures({
      x = cx * self.chunkSize, y = cy * self.chunkSize,
      size = self.chunkSize, chunkX = cx, chunkY = cy,
      random = love.math.newRandomGenerator(chunkSeed(self.seed, cx, cy, "structures")),
    })
  end
  return chunk
end

---@param x number Player/camera center in world coordinates.
---@param y number
---@param viewWidth number Visible world width, not physical window pixels.
---@param viewHeight number Visible world height.
function MapSystem:update(x, y, viewWidth, viewHeight)
  assert(viewWidth > 0 and viewHeight > 0, "Map view dimensions must be positive")
  local keep = bounds(x, y, viewWidth, viewHeight, self.unloadMargin, self.chunkSize)
  -- Evict first so a teleport doesn't temporarily retain both distant regions.
  for id, chunk in pairs(self.chunks) do
    if chunk.x < keep.left or chunk.x > keep.right or chunk.y < keep.top or chunk.y > keep.bottom then
      releaseChunk(chunk)
      self.chunks[id] = nil
    end
  end
  local load = bounds(x, y, viewWidth, viewHeight, self.loadMargin, self.chunkSize)
  for cy = load.top, load.bottom do
    for cx = load.left, load.right do
      local id = key(cx, cy)
      if not self.chunks[id] then self.chunks[id] = self:createChunk(cx, cy) end
    end
  end
  local view = bounds(x, y, viewWidth, viewHeight, 0, self.chunkSize)
  self.visible = {}
  for cy = view.top, view.bottom do
    for cx = view.left, view.right do
      self.visible[#self.visible + 1] = self.chunks[key(cx, cy)]
    end
  end
end

-- Caller applies the world/camera transform. No generation occurs during draw.
function MapSystem:draw()
  love.graphics.push("all")
  love.graphics.setColor(1, 1, 1, 1)
  for _, chunk in ipairs(self.visible) do
    for _, batch in pairs(chunk.batches) do
      love.graphics.draw(batch, chunk.x * self.chunkSize, chunk.y * self.chunkSize,
        0, self.tileScale, self.tileScale)
    end
  end
  -- Structures draw after all floor chunks so adjacent floors can't cover them.
  for _, chunk in ipairs(self.visible) do
    for _, structure in ipairs(chunk.structures) do structure:draw() end
  end
  love.graphics.pop()
end

function MapSystem:destroy()
  for _, chunk in pairs(self.chunks) do releaseChunk(chunk) end
  self.chunks = {}
  self.visible = {}
end

return MapSystem
