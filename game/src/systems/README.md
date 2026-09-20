# ShaderSystem

Fullscreen effects are configured in `game/src/shader_config.lua`. The default
applies diffuse to gameplay, leaving the HUD sharp and menus unaffected.
Set `includeUI = true` to process the scene and UI together; set
`includeMenus = true` to also process menu, pause, end, and debug screens.
These switches apply to the entire chain. With UI excluded, menu backgrounds
are processed but headings, buttons, pause dimming, and the debug HUD are drawn
afterward. World-space health bars and debug test drawings are scene content.

Add entries to `effects` in the order they should run:

```lua
effects = {
  {name = "diffuse", path = "assets/shaders/diffuse.glsl"},
  {name = "grade", path = "assets/shaders/grade.glsl", uniforms = {strength = 0.5}},
}
```

The second path is an example: supply your own shader file. Each pass samples
the previous pass's output. `screenSize`, when declared by a shader, is sent
automatically in texture pixels; other uniform values come from `uniforms`.
Two canvases are reused and recreated when the window size or DPI changes.
An empty or disabled chain draws directly without allocating canvases.

Runtime controls are available through `require("gamestate.deps").Gamestate.shaderSystem`:

```lua
shaders.enabled = false                 -- bypass the whole chain
shaders.includeUI = true
shaders.includeMenus = true
shaders:get("diffuse").enabled = false  -- bypass one effect
shaders:add("grade", "assets/shaders/grade.glsl", {uniforms = {strength = 0.5}})
shaders:get("grade").uniforms.strength = 0.8
shaders:remove("grade")                 -- releases that shader
```

States implement `drawScene()` and `drawUI()` in logical viewport coordinates.
Set `isMenu = false` on gameplay states; other states default to menu behavior.
Keep excluded UI in `drawUI()`. `draw()` remains a convenience to draw both.
Run `luajit tools/test_shaders.lua` for pipeline checks.

# CreatureSystem

Create one system per run. Creating a creature registers it with that system
and returns its plain data table:

```lua
local CreatureSystem = require("systems.creature")
local behavior = require("behavior")
local creatures = CreatureSystem.new()
local slime = creatures:create("death_slime", 200, 150, {
  health = 10, speed = 40, scale = 4, frameDuration = 0.2,
  movementBehavior = behavior.chase,
})
creatures:create("red_cap", 300, 150, { scale = 4 })

-- In your game update and draw callbacks, respectively:
creatures:update(dt, { knight = knight, healer = healer })
creatures:draw()
```

Options are optional: health defaults to 1, speed to 0, scale to 1, and frame
duration to 0.2 seconds. These stats are placeholders, not balance values.
Positions are sprite-center coordinates in game pixels. Position and velocity are
HUMP vectors; each creature has its own vectors and anim8 playback instance.
Images are cached and shared. Use `slime.animations.idle:flipH()` or other
anim8 methods directly. Adding a creature never resets existing playback.

Each update runs the creature's behavior, applies `velocity * dt` to its
position, and advances its idle animation. Behavior defaults to
`behavior.idle`, which clears velocity. `behavior.chase` moves toward the
knight at the creature's speed, stopping at its position without overshooting.
Set a nonzero speed to enable chasing. Change behavior at runtime with
`slime.movementBehavior = behavior.idle` (or `behavior.chase`).

`CreatureSystemContext` contains optional `knight` and `healer` object
references. Both expose `position` as a HUMP vector in game coordinates.
Update characters before creatures so behaviors read their latest positions.
Chase reads the knight's current position every update, including a replaced
position vector; it never follows the healer. Without a knight, chase stops.
The game state passes `self.knight` and `self.healer`; these can remain absent
until character objects are created. Omitting context is also supported.

Movement and attack behaviors are shared, stateless modules selected independently
through `movementBehavior` and `attackBehavior`. Movement modules set velocity;
CreatureSystem applies movement for every creature before running any attacks.
`attacks.melee` and `attacks.projectile` own targeting, cooldown advancement, and
attacking. Cooldown remaining stays on each creature. Attack updates receive
`(creature, dt, context, canAttack)`; they must honor `canAttack` to prevent firing
during knockback while still advancing timers. Melee attacks damage the knight
in range.
Bloodshot Eyes default to ranged attacks and `behavior.ranged`, which stops at
firing range. `behavior.chase` always closes to the knight, independent of attack
type. Explicit `options.movementBehavior` overrides the default movement behavior.
Explicit `options.attack` overrides attack settings. `options.attackBehavior`
overrides the attack module; otherwise `attack.type` selects melee or projectile
at creation time. Changing movement behavior never changes the attack module. Knockback interrupts
movement and attacks. Ordinary chase does not pathfind around pillars.
Drawing preserves graphics state and never advances animation. During pause,
draw the same system without updating it; create a new system for a new run.

Available monster IDs:

- `blinded_grimlock`, `bloodshot_eye`, `brawny_ogre`
- `crimson_slaad`, `crushing_cyclops`, `death_slime`
- `fungal_myconid`, `humongous_ettin`, `murky_slaad`
- `ochre_jelly`, `ocular_watcher`, `red_cap`
- `shrieker_mushroom`, `stone_troll`, `swamp_troll`

The internal `monster_animations` module maps these IDs to existing four-frame
16×16 PNG sheets. Unknown IDs raise an error. Hero/healer parts are not included.

Run the headless behavior, animation, and lifecycle checks from the repository
root with `lua tools/test_creatures.lua`.

## Projectiles

The game owns `ProjectileSystem.new()`. Pass it as `context.projectiles` when
updating creatures. Ranged attacks spawn plain typed projectile tables; without
a projectile system, they do not fire or deal instant damage.

```lua
projectiles:spawn({
  position = origin, direction = targetPosition - origin,
  speed = 240, damage = 1, radius = 4, lifespan = 3,
  owner = creature,
})
projectiles:update(dt, {
  knight = knight,
  traceWorld = function(origin, destination, radius)
    return map:traceProjectile(origin, destination, radius)
  end,
})
```

Spawn copies position and fixes velocity from the normalized direction. Shots
continue after the shooter dies; they do not home. Zero-direction shots are
ignored. Bloodshot Eyes fire every 1.5 seconds within 300 world pixels. Override
`attack.projectile` to tune speed, radius, and lifespan independently of the
attack's damage, range, and cooldown.

Each update traces the traveled segment against the knight's 16-pixel-radius
circle and expanded pillar footprints. The earliest hit consumes the shot;
pillars win ties. Expansion uses rectangular bounds, so pillar corners block
conservatively. The healer and creatures do not block enemy shots. Traces load
needed map chunks without changing visible chunks; normal streaming reclaims
them. Lifespan limits travel even on long frames.

Update after creatures and check end-of-run health afterward. Draw inside the
world camera transform before foreground pillars; pause draws without updating.
Kicks destroy shots whose centers are within the kick's range and arc at
activation. Cooldown and direction match creature knockback; the kick animation
does not provide a persistent shield. `removeWhere(predicate)` removes matching
shots without applying impact damage. `destroy()` clears shots when leaving the run. Animation, homing, piercing,
friendly fire, and hero projectiles are not implemented.

Run `luajit tools/test_projectiles.lua` for projectile and integration checks.
