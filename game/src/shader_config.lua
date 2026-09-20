return {
  enabled = true,
  includeUI = false,
  includeMenus = false,
  -- Applied in list order; each effect receives the previous effect's output.
  effects = {
    {name = "diffuse", path = "assets/shaders/diffuse.glsl"},
  },
}
