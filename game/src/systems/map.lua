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
---@field structures? boolean Enable default pillars; defaults to true.
---@field createStructures? fun(context: MapChunkContext): MapStructure[] Overrides default placement; owns its collision response.

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
    structureFactory = options.createStructures,
    structureSystem = not options.createStructures and options.structures ~= false
      and require("systems.structure").new(tileScale) or nil,
    images = loadImages(),
    chunks = {},
    visible = {},
  }, MapSystem)
end

---@param context MapChunkContext
---@return MapStructure[]
function MapSystem:createStructures(context)
  if self.structureFactory then return self.structureFactory(context) end
  if self.structureSystem then return self.structureSystem:createChunk(context) end
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
    chunk.structures = self:createStructures({
      x = cx * self.chunkSize,
      y = cy * self.chunkSize,
      size = self.chunkSize,
      chunkX = cx,
      chunkY = cy,
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
  self.viewWidth, self.viewHeight = viewWidth, viewHeight
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
  if self.structureSystem then self.structureSystem:prune() end
end

-- Player.update has already calculated the desired position. Resolve the path
-- against default pillars, keeping streamed collision geometry available.
function MapSystem:resolveMovement(actor, oldX, oldY)
  if not self.structureSystem or not actor.shape then return end
  self.structureSystem:resolveMovement(actor, oldX, oldY, function(x, y)
    self:update(x, y, self.viewWidth, self.viewHeight)
  end)
end

---@param origin HumpVector
---@param destination HumpVector
---@param radius number
---@return HumpVector position
---@return boolean collided
function MapSystem:resolveKnockback(origin, destination, radius)
  if not self.structureSystem then return destination, false end
  -- Query with an unregistered shape: monsters never enter the pickup or pillar
  -- spatial hashes, and death/restart requires no additional collider cleanup.
  local shapes = require("lib.HC.shapes")
  local actor = {
    x = destination.x, y = destination.y,
    shape = shapes.newCircleShape(origin.x, origin.y, radius),
  }
  local collided = self.structureSystem:resolveMovement(actor, origin.x, origin.y, function(x, y)
    -- Load only geometry intersected by the probe. Do not recenter the camera,
    -- replace visible chunks, or evict the healer's surroundings. Normal map
    -- updates reclaim any extra chunks after the kick moves out of range.
    for cy = math.floor((y - radius) / self.chunkSize), math.floor((y + radius) / self.chunkSize) do
      for cx = math.floor((x - radius) / self.chunkSize), math.floor((x + radius) / self.chunkSize) do
        local id = key(cx, cy)
        if not self.chunks[id] then self.chunks[id] = self:createChunk(cx, cy) end
      end
    end
  end, true)
  return require("lib.hump.vector")(actor.x, actor.y), collided
end

---@param origin HumpVector
---@param destination HumpVector
---@param radius number
---@return number? fraction Earliest pillar impact, or nil for a clear path.
function MapSystem:traceProjectile(origin, destination, radius)
  if not self.structureSystem then return nil end
  -- Stream the swept bounds without changing the camera's visible chunk list.
  local left = math.floor((math.min(origin.x, destination.x) - radius) / self.chunkSize)
  local right = math.floor((math.max(origin.x, destination.x) + radius) / self.chunkSize)
  local top = math.floor((math.min(origin.y, destination.y) - radius) / self.chunkSize)
  local bottom = math.floor((math.max(origin.y, destination.y) + radius) / self.chunkSize)
  for cy = top, bottom do
    for cx = left, right do
      local id = key(cx, cy)
      if not self.chunks[id] then self.chunks[id] = self:createChunk(cx, cy) end
    end
  end
  return self.structureSystem:traceProjectile(origin, destination, radius)
end

-- Caller applies the world/camera transform. No generation occurs during draw.
-- With splitY, draw only structures behind that anchor; drawForeground draws
-- the rest after the player, allowing tall pillars to occlude the player.
function MapSystem:draw(splitY)
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
    for _, structure in ipairs(chunk.structures) do
      if not splitY or structure.y <= splitY then structure:draw() end
    end
  end
  love.graphics.pop()
end

function MapSystem:drawForeground(splitY)
  love.graphics.push("all")
  for _, chunk in ipairs(self.visible) do
    for _, structure in ipairs(chunk.structures) do
      if structure.y > splitY then structure:draw() end
    end
  end
  love.graphics.pop()
end

---@return MapStructure[]
function MapSystem:getVisibleStructures()
  local structures = {}
  for _, chunk in ipairs(self.visible) do
    for _, structure in ipairs(chunk.structures) do structures[#structures + 1] = structure end
  end
  return structures
end

function MapSystem:destroy()
  for _, chunk in pairs(self.chunks) do releaseChunk(chunk) end
  self.chunks = {}
  self.visible = {}
  if self.structureSystem then self.structureSystem:prune() end
end

return MapSystem
