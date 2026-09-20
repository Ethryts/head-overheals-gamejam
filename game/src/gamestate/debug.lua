local Gamestate = require("gamestate.deps").Gamestate
local UI = require("gamestate.ui")
local hud = require("debug.hud")
local tests = require("debug.tests")
---@class DebugTest
---@field update fun(self: DebugTest, dt: number)
---@field draw fun(self: DebugTest)
---@field mousepressed? fun(self: DebugTest, x: number, y: number, button: integer)
---@field footer? string
---@field destroy? fun(self: DebugTest) Releases resources when leaving the test.

---@class DebugTestDefinition
---@field label string
---@field new fun(game?: GameContext): DebugTest

---@class DebugState
---@field game? GameContext Active game context, or an empty context when opened from a menu.
---@field activeTest? DebugTest
---@field menuOpen boolean
---@field debugLabel string
local debugState = {}

---@param previous? GameContext|PauseState
function debugState:enter(previous)
  self.game = previous and (previous.game or previous)
  self.ui = UI.new()
  self.activeTest = nil
  self.menuOpen = true
  self.debugLabel = "Test menu"
end

---@param definition DebugTestDefinition
function debugState:selectTest(definition)
  if self.activeTest and self.activeTest.destroy then self.activeTest:destroy() end
  self.activeTest = definition.new(self.game)
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
    UI.navigationFooter("Exit debug")
  else
    self.activeTest:draw()
    UI.footer(self.activeTest.footer or
      "Left click: run test     Esc: test menu     F3: exit debug     F4: HUD")
  end
end

function debugState:keypressed(key, scancode, isrepeat)
  if isrepeat then return end
  if key == "escape" then
    if self.menuOpen then return Gamestate.pop() end
    if self.activeTest.destroy then self.activeTest:destroy() end
    self.activeTest = nil
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
  if self.activeTest and self.activeTest.destroy then self.activeTest:destroy() end
  self.game = nil
  self.activeTest = nil
  self.ui = nil
end

function debugState:gamepadpressed(joystick, button)
  if button == "b" then return self:keypressed("escape") end
  if button == "start" then return Gamestate.pop() end
  local instance = self.menuOpen and self.ui or self.activeTest.ui
  if instance then UI.gamepadpressed(instance, button) end
end

function debugState:gamepadaxis(joystick, axis, value)
  local instance = self.menuOpen and self.ui or self.activeTest.ui
  if instance then UI.gamepadaxis(instance, axis, value) end
end

return debugState
