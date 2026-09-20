local Skin = {}
local fonts, image, frames = {}, nil, {}

function Skin.font(size)
  if not fonts[size] then
    fonts[size] = love.graphics.newFont("assets/fonts/monogram/monogram.ttf", size)
    fonts[size]:setFilter("nearest", "nearest")
  end
  return fonts[size]
end

-- Nine-slice the pack's 32px stone frame, keeping its corners at 2x scale.
function Skin.panel(x, y, width, height, glow, style)
  if not image then
    image = love.graphics.newImage("assets/images/ui/cryo-mini-gui.png")
    image:setFilter("nearest", "nearest")
  end
  style = style or "stone"
  local steel = style == "steel"
  local border, center = steel and 4 or 8, steel and 8 or 16
  local sourceX, sourceY = steel and 128 or 0, steel and 32 or 56
  local slices = frames[style]
  if not slices then
    slices = {}
    local offsets, sizes = {0, border, border+center}, {border, center, border}
    for row = 1, 3 do
      for col = 1, 3 do
        slices[#slices + 1] = love.graphics.newQuad(sourceX+offsets[col], sourceY+offsets[row],
          sizes[col], sizes[row], image:getWidth(), image:getHeight())
      end
    end
    frames[style] = slices
  end
  love.graphics.setColor(0.055, 0.065, 0.09, 0.96)
  love.graphics.rectangle("fill", x + 4, y + 4, width - 8, height - 8)
  local edge = border*2
  local xs, ys = {x, x+edge, x+width-edge}, {y, y+edge, y+height-edge}
  local widths, heights = {edge, width-edge*2, edge}, {edge, height-edge*2, edge}
  local sizes = {border, center, border}
  love.graphics.setColor(1, 1, 1)
  for row = 1, 3 do
    for col = 1, 3 do
      if row ~= 2 or col ~= 2 then
        love.graphics.draw(image, slices[(row-1)*3+col], xs[col], ys[row],
          0, widths[col]/sizes[col], heights[row]/sizes[row])
      end
    end
  end
  if glow and glow > 0 then
    love.graphics.setColor(0.2, 1, 0.5, glow * 0.2)
    love.graphics.rectangle("fill", x+8, y+8, width-16, height-16)
  end
end

return Skin
