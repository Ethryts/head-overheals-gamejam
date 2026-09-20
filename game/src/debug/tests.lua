-- Add a test module here to expose it in the debug menu.
-- Each module provides label and new(game); instances implement update, draw,
-- and optionally mousepressed.
return {
  (require("debug.spawn_creature")),
  (require("debug.knight_health")),
  (require("debug.fx")),
  (require("debug.demo")),
}
