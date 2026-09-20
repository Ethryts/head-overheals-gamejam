local viewport = require("src.viewport")
local project = require("project")
local MouseControls = {}

---@class PlayerMouseControls
---@field x? number Last cursor position in game coordinates.
---@field y? number
---@field aiming boolean Mouse currently owns aim.
---@field left boolean Previous left button state.
---@field right boolean Previous right button state.
---@field healing boolean Left press started inside the game, outside UI.

function MouseControls.new()
  return {aiming = false, left = love.mouse.isDown(1), right = love.mouse.isDown(2), healing = false}
end

-- Aim from the healer's screen anchor, not its world position: the camera follows it.
function MouseControls.update(state, aimX, aimY, blocked)
  local x, y, inside = viewport.toGame(love.mouse.getPosition())
  local left, right = love.mouse.isDown(1), love.mouse.isDown(2)
  local valid = inside and not blocked
  local pressedLeft, pressedRight = left and not state.left, right and not state.right
  if aimX ~= 0 or aimY ~= 0 then state.aiming = false end
  if valid and ((state.x and (x ~= state.x or y ~= state.y)) or pressedLeft or pressedRight) then
    state.aiming = true
  end
  state.healing = left and valid and (state.healing or pressedLeft)
  local kick = valid and pressedRight
  local kickHeld = valid and right
  state.x, state.y, state.left, state.right = x, y, left, right
  if state.aiming and valid then
    aimX, aimY = x - project.width/2, y - project.height/2
  end
  return aimX, aimY, state.healing, kick, kickHeld
end

function MouseControls.resume(state)
  state.left, state.right = love.mouse.isDown(1), love.mouse.isDown(2)
  state.healing = false
end

return MouseControls
