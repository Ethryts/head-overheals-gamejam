-- Per-menu controller focus. Mouse input continues to use SUIT's hit testing.
local Navigation = {}

function Navigation.attach(instance)
  instance.navigation = {selected = 1, count = 0, index = 0, active = false, confirm = false, axes = {}}
  local button = instance.Button
  instance.Button = function(self, text, ...)
    local nav = self.navigation
    local opt, x, y, w, h = self.getOptionsAndSize(...)
    nav.index = nav.index + 1
    nav.count = math.max(nav.count, nav.index)
    opt.navFocused = nav.active and nav.selected == nav.index
    local result = button(self, text, opt, x, y, w, h)
    if result.hovered and not nav.active then nav.selected = nav.index end
    if opt.navFocused and nav.confirm then
      nav.confirm = false
      result.hit = true
    end
    return result
  end
end

function Navigation.begin(instance, x, y)
  local nav = instance.navigation
  if nav.mouseX and (x ~= nav.mouseX or y ~= nav.mouseY) then
    nav.active, nav.confirm = false, false
  end
  nav.mouseX, nav.mouseY = x, y
  if nav.index > 0 then nav.count = nav.index end
  nav.selected = math.min(nav.selected, math.max(1, nav.count))
  nav.index = 0
end

function Navigation.move(instance, step)
  local nav = instance.navigation
  nav.active = true
  nav.selected = (nav.selected - 1 + step) % math.max(1, nav.count) + 1
end

function Navigation.pressed(instance, button)
  if button == "dpup" or button == "dpleft" then
    Navigation.move(instance, -1)
  elseif button == "dpdown" or button == "dpright" then
    Navigation.move(instance, 1)
  elseif button == "a" then
    instance.navigation.active = true
    instance.navigation.confirm = true
  end
end

-- Hysteresis prevents stick noise from scrolling; return to center to move again.
function Navigation.axis(instance, axis, value)
  if axis ~= "lefty" and axis ~= "leftx" then return end
  local nav = instance.navigation
  if math.abs(value) < 0.3 then nav.axes[axis] = nil
  elseif math.abs(value) > 0.55 then
    local direction = value < 0 and -1 or 1
    if nav.axes[axis] ~= direction then
      nav.axes[axis] = direction
      Navigation.move(instance, direction)
    end
  end
end

return Navigation
