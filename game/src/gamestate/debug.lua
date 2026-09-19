local Gamestate = require("gamestate.deps").Gamestate
local UI = require("gamestate.ui")
local hud = require("debug.hud")
local tests = require("debug.tests")
local debugState = {}

function debugState:enter()
  self.ui = UI.new()
  self.activeTest = nil
  self.menuOpen = true
  self.debugLabel = "Test menu"
end

function debugState:selectTest(definition)
  self.activeTest = definition.new()
  self.menuOpen = false
  self.debugLabel = definition.label
  self.ui = UI.new()
  hud.visible = true
end

function debugState:update(dt)
  if not self.menuOpen then
    return self.activeTest:update(dt)
  end
  UI.begin(self.ui)
  for i, definition in ipairs(tests) do
    if self.ui:Button(definition.label, (UI.width - 360) / 2,
        UI.height * 0.5 + (i - 1) * 56, 360, 44).hit then
      return self:selectTest(definition)
    end
  end
end

function debugState:draw()
  UI.background()
  if self.menuOpen then
    UI.heading("Debug tests", "Select a test")
    UI.draw(self.ui)
    UI.footer("F3 / Esc: exit debug     F4: toggle HUD")
  else
    self.activeTest:draw()
    UI.footer("Left click: run test     Esc: test menu     F3: exit debug     F4: HUD")
  end
end

function debugState:keypressed(key, scancode, isrepeat)
  if isrepeat then return end
  if key == "escape" then
    if self.menuOpen then return Gamestate.pop() end
    self.menuOpen = true
    self.debugLabel = "Test menu"
    self.ui = UI.new()
  end
end

function debugState:mousepressed(...)
  if not self.menuOpen and self.activeTest.mousepressed then
    self.activeTest:mousepressed(...)
  end
end

function debugState:leave()
  self.activeTest = nil
  self.ui = nil
end

return debugState
