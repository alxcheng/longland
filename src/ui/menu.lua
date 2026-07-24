-- menu.lua
-- A vertical list selector. An arrow sits behind the current selection and pushes
-- that line's text outward; the arrow eases toward the selected line as you move.
-- Navigable with up/down (wasd or arrows). confirm activates; describe (q) fires a
-- separate callback (used to pop a description textbox). Items may carry a check
-- mark (EQUIP / PARTY style), a disabled flag, and arbitrary `data`.
--
-- opts = {
--   x, y, width,
--   items = { "Label", {text="Label", checked=false, disabled=false, data=..., desc=...}, ... },
--   fontSize, linePad,
--   wrap = true/false,            -- wrap selection past the ends (default true)
--   onConfirm  = function(item, index) end,
--   onDescribe = function(item, index) end,
--   onChange   = function(item, index) end,
-- }

local class = require("src.lib.class")
local fonts = require("src.core.fonts")
local input = require("src.core.input")

local Menu = class()

local ARROW_W   = 12
local ARROW_H   = 12
local TEXT_GAP  = 8    -- gap between arrow tip and pushed text
local PUSH      = 6    -- extra shove the arrow gives the selected line
local CHECK_GUT = 16   -- left gutter reserved for check marks
local FONT_SIZE = 18
local LINE_PAD  = 8

function Menu:init(opts)
    self.x = opts.x or 0
    self.y = opts.y or 0
    self.width = opts.width
    self.wrap = opts.wrap
    if self.wrap == nil then self.wrap = true end

    self.items = {}
    for i, it in ipairs(opts.items or {}) do
        if type(it) == "string" then it = { text = it } end
        self.items[i] = it
    end

    self.onConfirm  = opts.onConfirm
    self.onDescribe = opts.onDescribe
    self.onChange   = opts.onChange

    self.font = fonts.get(opts.fontSize or FONT_SIZE)
    self.lineHeight = self.font:getHeight() + (opts.linePad or LINE_PAD)
    self.index = 1
    self.enabled = true

    self.arrowY = self:_lineY(1) -- animated, eases toward the selected line
end

function Menu:_lineY(i)
    return self.y + (i - 1) * self.lineHeight
end

-- Replace the item list in place (keeps the selection index in range). Used by
-- screens that rebuild their list after a state change (e.g. EQUIP).
function Menu:setItems(items)
    self.items = {}
    for i, it in ipairs(items) do
        if type(it) == "string" then it = { text = it } end
        self.items[i] = it
    end
    self.index = math.max(1, math.min(self.index, #self.items))
end

function Menu:selected()
    return self.items[self.index], self.index
end

function Menu:setChecked(i, checked)
    if self.items[i] then self.items[i].checked = checked end
end

function Menu:move(delta)
    local n = #self.items
    if n == 0 then return end
    local idx = self.index + delta
    if self.wrap then
        idx = ((idx - 1) % n) + 1
    else
        idx = math.max(1, math.min(n, idx))
    end
    if idx ~= self.index then
        self.index = idx
        if self.onChange then self.onChange(self.items[self.index], self.index) end
    end
end

function Menu:update(dt)
    if self.enabled and #self.items > 0 then
        if input.pressed("down") then self:move(1) end
        if input.pressed("up")   then self:move(-1) end
        if input.pressed("confirm") and self.onConfirm then
            self.onConfirm(self.items[self.index], self.index)
        end
        if input.pressed("describe") and self.onDescribe then
            self.onDescribe(self.items[self.index], self.index)
        end
    end
    -- Ease the arrow toward the current line (frame-rate independent).
    local targetY = self:_lineY(self.index)
    local t = 1 - math.exp(-18 * dt)
    self.arrowY = self.arrowY + (targetY - self.arrowY) * t
end

function Menu:draw()
    love.graphics.setFont(self.font)
    local fh = self.font:getHeight()
    local textBaseX = self.x + CHECK_GUT

    for i, it in ipairs(self.items) do
        local ly = self:_lineY(i)
        local selected = (i == self.index)
        local tx = textBaseX + ARROW_W + TEXT_GAP
        if selected then tx = tx + PUSH end

        if it.checked then
            love.graphics.setColor(1, 1, 1, 1)
            self:_drawCheck(self.x, ly + fh / 2)
        end

        if it.disabled then
            love.graphics.setColor(0.45, 0.45, 0.45, 1)
        else
            love.graphics.setColor(1, 1, 1, 1)
        end
        love.graphics.print(it.text, tx, ly)
    end

    -- The single arrow, eased to the selected line.
    if #self.items > 0 then
        local ay = self.arrowY + fh / 2
        local ax = textBaseX + PUSH
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.polygon("fill",
            ax, ay - ARROW_H / 2,
            ax, ay + ARROW_H / 2,
            ax + ARROW_W, ay)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

-- Small stroked check mark centered vertically at (x, cy).
function Menu:_drawCheck(x, cy)
    love.graphics.setLineWidth(2)
    love.graphics.line(x + 1, cy, x + 4, cy + 4, x + 10, cy - 5)
    love.graphics.setLineWidth(1)
end

return Menu
