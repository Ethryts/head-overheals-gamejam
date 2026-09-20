# Pixel FX

Each game owns `FxSystem.new()`. Effects never change gameplay, use a separate
random generator, and stop updating while the game is paused.

```lua
fx:emit("sparks", hitX, hitY, {angle = hitDirection}) -- radians
fx:emit("dust", feetX, feetY)
fx:emit("pickup", itemX, itemY, {color = {1, 0.75, 0.15}})
local fire = fx:start("embers", brazierX, brazierY)
fire:setPosition(x, y, feetY) -- optional, for moving sources
fire:stop() -- existing particles finish naturally
fx:update(dt)
```

Presets in `presets.lua` define count/rate, lifetime, speed, direction/spread,
acceleration, drag, spawn spread, shape, and stepped opaque colors. Available
IDs are `sparks`, `dust`, `embers`, `healing`, and `pickup`. The 40x8 shared texture
in `assets/images/fx/particles.png` contains original white pixel masks: dot,
line, cluster, diamond, and sparkle. No external artwork is required.

`emit` creates a burst; `start` creates a persistent emitter. Both copy options.
`depth` defaults to the source y-coordinate and stays fixed as particles rise;
pass a character's feet y-coordinate when emitting around their body. `color`
tints pickup flecks, preserving bright highlights. `destroy()` stops emitters
and removes all particles on leaving a game or debug test.

The game draws floors, ground dust, pickups, then a stable foot-depth queue of
pillars, actors, projectiles, and airborne FX. Effects and world share a 480x270
nearest-filtered canvas, scaled into the existing 960x540 logical viewport.
UI and debug text render afterward at window resolution. `main.lua`, input
coordinates, camera movement, and fullscreen resize handling stay unchanged.

For standalone scenes, use `fx:draw("ground")` and `fx:draw("air")`, or `fx:draw()`.
The game instead queues individual airborne particles with `drawParticle` so
pillars and actors can occlude them. Draw calls do not advance simulation.

Gameplay hooks emit sparks on attacks/impacts and kicked projectiles, dust on
hero footsteps/kicks, motes while the knight receives beam healing, and
item-colored bursts on collection. Embers are available for future braziers.
Use **F3 → Particle FX** to preview all presets and toggle persistent emitters.

Default limits are 1,024 particles and 64 emitters. Extra emissions are dropped;
an over-budget `start` returns an inactive handle. Long frames skip births that
would already have expired and bound spawning work to available capacity.
Configure limits and the local RNG seed with `FxSystem.new({maxParticles = ...,
maxEmitters = ..., seed = ...})`.

Run `luajit tools/test_fx.lua` for timing, lifecycle, gameplay hooks, and depth
ordering checks. Native rendering also requires a visual LÖVE check.
