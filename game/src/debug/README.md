# Debug tools

- **F3** enters a separate debug state from any screen, or returns to that screen.
- **F4** toggles the top-left debug HUD independently, including outside debug.
- Select **Spawn creature on click** to enable the HUD and click-to-spawn test.
- Use the top-right **Creature** dropdown to select **Death Slime** (default),
  **Bloodshot Eye**, or **Ochre Jelly**.
- **Left click** in the game viewport spawns the selected creature chasing the
  centered knight marker. Dropdown clicks, right clicks, and clicks in
  letterbox bars do not spawn. Clicking outside an open dropdown dismisses it;
  click again to spawn.
- **Particle FX** previews sparks, dust, embers, healing motes, and pickup bursts.
  Click in the scene for a burst; use **Toggle emitter** to start/stop emission.
- **Esc** returns to the test menu; Esc again exits debug.

## Demo recording

Choose **Demo staging** from F3. From a menu, **Start demo game** creates a
fresh run; during a game it edits that run. The scene stays paused while staging.

- **Stats** adjusts knight health/max health/speed, healer speed/healing rate,
  and charge regeneration. Refill charge or restore safe knight health instantly.
- **Spawn** selects any creature and a count (1–20). Click the unobscured world
  to place one creature or a group around that point, relative to the camera.
- **Scene** places the knight/healer, clears creatures and projectiles, toggles
  automatic spawning (off initially), and hides the game HUD for clean shots.
- **Play demo** resumes the game and hides diagnostic text. Press F3 and choose
  Demo staging again to adjust the next shot. Settings persist for this run only.

Staging edits affect the real game, including health, deaths and creature AI.
Moving the healer also moves the camera; placing the knight resets his patrol anchor.
Automatic spawning resumes its difficulty clock when enabled again.

The regular game is frozen while debug is open. Other selected tests start
fresh; debug creatures never enter the regular game's CreatureSystem.
The knight stub has a position and a visible health counter. Bloodshot Eyes
stop at firing range and shoot at it; other creatures use melee attacks. This
test owns a separate projectile system and has no pillars. No character handlers
are required, and the active game's knight is unaffected.

To add tests, add a module to `debug/tests.lua`. Provide `label`, `new()`, and
instance methods `update(dt)`, `draw()`, plus optional `mousepressed(...)`.
Mouse coordinates have already been converted to game coordinates.
Add functions to `hud.rows` for additional live text; each receives the current
game state and returns a string, or nil to omit the row. Draw code must not
advance gameplay or animation.
