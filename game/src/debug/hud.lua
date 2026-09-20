local viewport = require("src.viewport")

local hud = { visible = false }
local font

-- Add another function here to display a live value. Return nil to hide a row.
hud.rows = {
  function(state) return "Debug: " .. (state.debugLabel or "off") end,
  function(state)
    local player = state.player or (state.game and state.game.player)
    if player then
      return string.format("Player world: %.1f, %.1f", player.x, player.y)
    end
  end,
  function()
    local x, y, inside = viewport.toGame(love.mouse.getPosition())
    return string.format("Mouse: %.0f, %.0f%s", x, y, inside and "" or " (outside)")
  end,
}

function hud.toggle()
  hud.visible = not hud.visible
end

function hud.draw(state)
  if not hud.visible then return end
  font = font or love.graphics.newFont(14)
  local lines = {}
  for _, row in ipairs(hud.rows) do
    local text = row(state)
    if text then lines[#lines + 1] = text end
  end
  local width = 0
  for _, line in ipairs(lines) do width = math.max(width, font:getWidth(line)) end
  local lineHeight = font:getHeight() + 4
  love.graphics.push("all")
  love.graphics.setFont(font)
  love.graphics.setColor(0, 0, 0, 0.8)
  love.graphics.rectangle("fill", 8, 8, width + 16, #lines * lineHeight + 12)
  love.graphics.setColor(1, 1, 1, 1)
  for i, line in ipairs(lines) do
    love.graphics.print(line, 16, 14 + (i - 1) * lineHeight)
  end
  love.graphics.pop()
end

return hud
