# CreatureSystem

Create one system per run. Creating a creature registers it with that system
and returns its plain data table:

```lua
local CreatureSystem = require("systems.creature")
local creatures = CreatureSystem.new()
local slime = creatures:create("death_slime", 200, 150, {
  health = 10, speed = 40, scale = 4, frameDuration = 0.2,
})
creatures:create("red_cap", 300, 150, { scale = 4 })

-- In your game update and draw callbacks, respectively:
creatures:update(dt)
creatures:draw()
```

Options are optional: health defaults to 1, speed to 0, scale to 1, and frame
duration to 0.2 seconds. These stats are placeholders, not balance values.
Positions are top-left coordinates in game pixels. Position and velocity are
HUMP vectors; each creature has its own vectors and anim8 playback instance.
Images are cached and shared. Use `slime.animations.idle:flipH()` or other
anim8 methods directly. Adding a creature never resets existing playback.

The system updates idle animation only. Speed, velocity, and the optional
`Attack` type are ready for future gameplay; there is no movement or combat.
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
