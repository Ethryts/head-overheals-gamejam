local HealthBar = {}
HealthBar.__index = HealthBar

local DEFAULT_STYLE = {
    width = 40,
    height = 6,
    offsetY = -30, -- drawn this far above the anchor point
    background = { 0.15, 0.15, 0.15, 0.8 },
    border = { 0, 0, 0, 1 },
    fill = { 0.3, 0.9, 0.3, 1 },
}

---@param style? table Override any of DEFAULT_STYLE's fields.
function HealthBar.new(style)
    local self = setmetatable({}, HealthBar)
    self.style = setmetatable(style or {}, { __index = DEFAULT_STYLE })
    return self
end

---@param worldX number Anchor X (bar is centered on this).
---@param worldY number Anchor Y (bar is drawn offsetY above this).
---@param ratio number 0..1 fill amount.
---@param fillColorOverride? table {r,g,b,a} to override the style's fill color for this draw.
function HealthBar:draw(worldX, worldY, ratio, fillColorOverride)
    local s = self.style
    local x = worldX - s.width / 2
    local y = worldY + s.offsetY
    ratio = math.max(0, math.min(1, ratio))

    -- TODO(assets): once real art exists, replace these three rectangle calls
    -- with e.g. love.graphics.draw(s.backgroundImage, x, y) / a cropped quad
    -- for the fill / love.graphics.draw(s.borderImage, x, y). Callers never
    -- need to change — they only ever call :draw(worldX, worldY, ratio).
    love.graphics.setColor(s.background)
    love.graphics.rectangle("fill", x, y, s.width, s.height)

    love.graphics.setColor(fillColorOverride or s.fill)
    love.graphics.rectangle("fill", x, y, s.width * ratio, s.height)

    love.graphics.setColor(s.border)
    love.graphics.rectangle("line", x, y, s.width, s.height)
end

return HealthBar
