-- panel.lua
-- Shared bordered-panel drawing so every screen has the same white-outline /
-- black-fill look as the textbox.

local fonts = require("src.core.fonts")

local panel = {}

function panel.frame(x, y, w, h, alpha)
    love.graphics.setColor(0, 0, 0, alpha or 0.85)
    love.graphics.rectangle("fill", x, y, w, h)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, y, w, h)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

-- Panel with a title strip along the top; returns the y where content can start.
function panel.titled(x, y, w, h, title)
    panel.frame(x, y, w, h)
    love.graphics.setFont(fonts.get(14))
    love.graphics.setColor(0.88, 0.88, 0.66, 1)
    love.graphics.print(title, x + 10, y + 7)
    love.graphics.setColor(1, 1, 1, 0.4)
    love.graphics.line(x + 8, y + 28, x + w - 8, y + 28)
    love.graphics.setColor(1, 1, 1, 1)
    return y + 36
end

return panel
