local Skin = {}
local fonts, image, slices = {}, nil, nil

function Skin.font(size)
  if not fonts[size] then
    fonts[size] = love.graphics.newFont("assets/fonts/monogram/monogram.ttf", size)
    fonts[size]:setFilter("nearest", "nearest")
  end
  return fonts[size]
end

-- Nine-slice the pack's 32px stone frame, keeping its corners at 2x scale.
function Skin.panel(x, y, width, height, glow)
  if not image then
    image = love.graphics.newImage("assets/images/ui/cryo-mini-gui.png")
    image:setFilter("nearest", "nearest")
    slices = {}
    local offsets, sizes = {0, 8, 24}, {8, 16, 8}
    for row = 1, 3 do
      for col = 1, 3 do
        slices[#slices + 1] = love.graphics.newQuad(offsets[col], 56 + offsets[row],
          sizes[col], sizes[row], image:getWidth(), image:getHeight())
      end
    end
  end
  love.graphics.setColor(0.055, 0.065, 0.09, 0.96)
  love.graphics.rectangle("fill", x + 4, y + 4, width - 8, height - 8)
  local xs, ys = {x, x+16, x+width-16}, {y, y+16, y+height-16}
  local widths, heights = {16, width-32, 16}, {16, height-32, 16}
  local sizes = {8, 16, 8}
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
