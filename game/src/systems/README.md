# CreatureSystem

Create one system per run. Creating a creature registers it with that system
and returns its plain data table:

```lua
local CreatureSystem = require("systems.creature")
local behavior = require("behavior")
local creatures = CreatureSystem.new()
local slime = creatures:create("death_slime", 200, 150, {
  health = 10, speed = 40, scale = 4, frameDuration = 0.2,
  behavior = behavior.chase,
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
`slime.behavior = behavior.idle` (or `behavior.chase`).

`CreatureSystemContext` contains optional `knight` and `healer` object
references. Both expose `position` as a HUMP vector in game coordinates.
Update characters before creatures so behaviors read their latest positions.
Chase reads the knight's current position every update, including a replaced
position vector; it never follows the healer. Without a knight, chase stops.
The game state passes `self.knight` and `self.healer`; these can remain absent
until character objects are created. Omitting context is also supported.

Behavior modules are shared and stateless. They set velocity; CreatureSystem
owns movement. The optional `Attack` type remains a placeholder. There is no
combat, obstacle pathfinding, or collision resolution yet.
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
