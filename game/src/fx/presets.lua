---@class FxPreset
---@field count integer Burst count.
---@field rate number Particles per second for persistent emitters.
---@field lifetime number[] Minimum and maximum seconds.
---@field speed number[] Initial speed range, in world pixels per second.
---@field angle number Default direction in radians.
---@field spread number Angular fan width in radians.
---@field acceleration number[] Constant x/y acceleration.
---@field drag number Exponential velocity damping per second.
---@field spreadX number Spawn half-width.
---@field spreadY number Spawn half-height.
---@field layer "ground"|"air"
---@field shapes string[] Weighted by repetition.
---@field colors number[][] Discrete RGB stages, all opaque.
---@field shrink? boolean Shrink to a dot near the end.
---@field flicker? boolean Occasional deterministic bright frames.
---@field drift? number Sideways oscillation in world pixels.
---@field tint? boolean Allow options.color to tint the palette.

---@type table<string, FxPreset>
return {
  impact = {
    count = 22, rate = 12, lifetime = {0.22, 0.45}, speed = {160, 270},
    angle = math.pi, spread = 2.2, acceleration = {0, 130}, drag = 5,
    spreadX = 2, spreadY = 2, layer = "air", shapes = {"line", "line", "cluster", "sparkle", "dot"},
    colors = {{1, 1, 0.92}, {1, 0.8, 0.4}, {0.62, 0.37, 0.15}}, shrink = true,
  },
  swing = {
    count = 1, rate = 3, lifetime = {0.2, 0.2}, speed = {0, 0},
    angle = 0, spread = 0, acceleration = {0, 0}, drag = 0,
    spreadX = 0, spreadY = 0, layer = "air", shapes = {"slash"},
    colors = {{1, 1, 0.95}, {0.8, 0.92, 1}, {0.45, 0.65, 0.8}},
  },
  sparks = {
    count = 12, rate = 24, lifetime = {0.18, 0.34}, speed = {140, 210},
    angle = 0, spread = 1.1, acceleration = {0, 55}, drag = 8,
    spreadX = 2, spreadY = 2, layer = "air", shapes = {"line", "line", "dot"},
    colors = {{1, 1, 0.85}, {1, 0.75, 0.18}, {0.65, 0.25, 0.04}}, shrink = true,
  },
  dust = {
    count = 5, rate = 12, lifetime = {0.25, 0.45}, speed = {14, 30},
    angle = -math.pi / 2, spread = math.pi * 2, acceleration = {0, 22}, drag = 5,
    spreadX = 7, spreadY = 2, layer = "ground", shapes = {"cluster", "cluster", "dot"},
    colors = {{0.48, 0.46, 0.40}, {0.36, 0.35, 0.32}, {0.24, 0.25, 0.24}}, shrink = true,
  },
  embers = {
    count = 6, rate = 9, lifetime = {0.8, 1.4}, speed = {10, 19},
    angle = -math.pi / 2, spread = 0.5, acceleration = {0, -5}, drag = 0.8,
    spreadX = 8, spreadY = 2, layer = "air", shapes = {"dot"},
    colors = {{1, 0.55, 0.1}, {0.9, 0.28, 0.06}, {0.5, 0.12, 0.03}}, flicker = true, drift = 3,
  },
  healing = {
    count = 8, rate = 14, lifetime = {0.55, 0.95}, speed = {14, 24},
    angle = -math.pi / 2, spread = 0.45, acceleration = {0, -3}, drag = 0.5,
    spreadX = 20, spreadY = 12, layer = "air", shapes = {"dot", "dot", "dot", "diamond", "sparkle"},
    colors = {{0.7, 1, 0.82}, {0.25, 0.9, 0.65}, {0.1, 0.55, 0.45}}, shrink = true, drift = 2,
  },
  pickup = {
    count = 14, rate = 20, lifetime = {0.25, 0.5}, speed = {60, 100},
    angle = 0, spread = math.pi * 2, acceleration = {0, 12}, drag = 7,
    spreadX = 2, spreadY = 2, layer = "air", shapes = {"dot", "dot", "line", "sparkle"},
    colors = {{1, 1, 0.9}, {1, 0.8, 0.2}, {0.6, 0.35, 0.08}}, shrink = true, tint = true,
  },
}
