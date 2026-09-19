# MapSystem

```lua
local MapSystem = require("systems.map")
local map = MapSystem.new({ seed = 1 })
map:update(player.x, player.y, 960, 540)
-- Inside your world/camera transform:
map:draw()
-- When leaving the run:
map:destroy()
```

The player starts at world `(0, 0)`. The game camera follows that position;
HUD and menus remain in screen coordinates. The visible world is the logical
960×540 viewport, regardless of native window size or browser scaling.

Ten floor PNGs are shared across maps. Defaults are 4× tile scale (64 world
pixels per tile) and 8×8-tile chunks. Each loaded chunk caches static SpriteBatches
grouped by tile image. Only visible chunks are drawn, and drawing never generates
tiles. There is no full-world tile array or permanent history of visited chunks.

`loadMargin = 0.5` loads half a screen width beyond the left/right edges and
half a screen height beyond the top/bottom edges. `unloadMargin = 1` retains
chunks until they are entirely beyond a full screen's margin. Bounds round
outward to whole chunks, so memory can extend by up to one extra chunk at an
edge. The wider retention area prevents repeated reloads near boundaries.
Eviction releases SpriteBatches; shared tile images stay loaded.

`seed` accepts an integer or string. Chunk coordinates (including negatives)
and the seed determine a private random stream. Generation does not consume
the game's global randomness. Returning to an unloaded chunk recreates its
tiles. Keep the seed and generation settings unchanged during a run; changing
the generation algorithm or tile pack can change layouts for existing seeds.

## Structure extension point

No structures are placed by default. Pass `createStructures(context)` to
return structures owned by each chunk. Context supplies its world `x`, `y`,
`size`, signed `chunkX`/`chunkY`, and a separately seeded `random` generator.
Use that generator for placement rather than global randomness.

`src.structure` is a minimal base with `draw()`, `collidesWith(shape)`, and
`destroy()`. A pillar or pot can supply its own drawing and HC shape. The map
draws structures after floors and calls `destroy()` when their chunk unloads
or the run ends, removing owned collision shapes. Keep structure bounds within
their owning chunk for correct visibility. Collision response, pillar artwork,
destructible-object persistence, and obstacle pathfinding are not implemented.
Unloaded structures are recreated from the seed, so mutations are not saved.

Run `lua tools/test_map.lua` for deterministic regeneration, negative-coordinate
coverage, cache reuse, load/unload hysteresis, bounded travel memory, and
structure cleanup checks.
