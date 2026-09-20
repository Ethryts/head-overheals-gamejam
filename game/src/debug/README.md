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
- **Esc** returns to the test menu; Esc again exits debug.

The regular game is frozen while debug is open. Each selected test starts
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
