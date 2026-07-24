-- textbox.lua
-- The workhorse dialogue box.
--   * White text, white outline, black fill.
--   * Occupies the bottom quarter of the screen with side/bottom spacing.
--   * Opens by expanding horizontally from the middle; closes the same way.
--   * Types characters out one at a time (visual-novel style).
--   * confirm (enter / space / click) finishes the current typing instantly;
--     confirm again advances to the next queued blurb, or closes if none remain.
--   * Auto-shrinks the font (before typing) so a long blurb fits the box.
--
-- Usage:
--   local tb = Textbox.new()
--   tb:show("A single line.")
--   tb:show({ "First blurb.", "Second blurb." })   -- queues several
--   in update: if tb:isActive() then tb:update(dt) end
--   in draw:   tb:draw()

local class = require("src.lib.class")
local fonts = require("src.core.fonts")
local input = require("src.core.input")
local video = require("src.core.video")

local Textbox = class()

-- Layout (game space, 800x450).
local SIDE_MARGIN   = 24
local BOTTOM_MARGIN = 16
local BOX_HEIGHT    = 104   -- roughly the bottom quarter
local PAD_X         = 16
local PAD_Y         = 12
local BASE_FONT     = 18
local MIN_FONT      = 10
local TYPE_CPS      = 45    -- characters per second
local ANIM_SPEED    = 6.0   -- open/close speed (fraction per second)

function Textbox:init()
    self.state = "closed"   -- closed | opening | typing | idle | closing
    self.queue = {}
    self.openAmt = 0        -- 0 closed .. 1 fully expanded
    self.font = fonts.get(BASE_FONT)
    self.fullText = ""
    self.charTimer = 0
    self.visible = 0

    self.w = video.GAME_W - SIDE_MARGIN * 2
    self.h = BOX_HEIGHT
    self.x = SIDE_MARGIN
    self.y = video.GAME_H - BOTTOM_MARGIN - BOX_HEIGHT
end

function Textbox:isActive()
    return self.state ~= "closed"
end

-- Queue one blurb or a list of blurbs. Opens the box if it was closed.
function Textbox:show(text)
    if type(text) == "table" then
        for _, t in ipairs(text) do self.queue[#self.queue + 1] = t end
    else
        self.queue[#self.queue + 1] = text
    end
    if self.state == "closed" then
        self:_begin(table.remove(self.queue, 1))
        self.state = "opening"
        self.openAmt = 0
    end
end

-- Prepare a blurb: pick the largest font that fits, wrap it, reset the typewriter.
function Textbox:_begin(text)
    local innerW = self.w - PAD_X * 2
    local innerH = self.h - PAD_Y * 2

    local chosen, lines
    for size = BASE_FONT, MIN_FONT, -1 do
        local f = fonts.get(size)
        local _, wrapped = f:getWrap(text, innerW)
        if #wrapped * f:getHeight() <= innerH then
            chosen, lines = f, wrapped
            break
        end
    end
    if not chosen then
        chosen = fonts.get(MIN_FONT)
        local _, wrapped = chosen:getWrap(text, innerW)
        lines = wrapped
    end

    self.font = chosen
    self.fullText = table.concat(lines, "\n")
    self.charTimer = 0
    self.visible = 0
end

function Textbox:_advance()
    if #self.queue > 0 then
        self:_begin(table.remove(self.queue, 1))
        self.state = "typing"
    else
        self.state = "closing"
    end
end

function Textbox:update(dt)
    if self.state == "opening" then
        self.openAmt = math.min(1, self.openAmt + ANIM_SPEED * dt)
        if self.openAmt >= 1 then self.state = "typing" end

    elseif self.state == "typing" then
        self.charTimer = self.charTimer + dt
        self.visible = math.min(#self.fullText, math.floor(self.charTimer * TYPE_CPS))
        if input.pressed("confirm") then
            self.visible = #self.fullText   -- skip to fully typed
        end
        if self.visible >= #self.fullText then
            self.state = "idle"
        end

    elseif self.state == "idle" then
        if input.pressed("confirm") then
            self:_advance()
        end

    elseif self.state == "closing" then
        self.openAmt = math.max(0, self.openAmt - ANIM_SPEED * dt)
        if self.openAmt <= 0 then self.state = "closed" end
    end
end

function Textbox:draw()
    if self.state == "closed" then return end

    local cx = self.x + self.w / 2
    local curW = self.w * self.openAmt

    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.rectangle("fill", cx - curW / 2, self.y, curW, self.h)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", cx - curW / 2, self.y, curW, self.h)

    if self.openAmt >= 0.999 and (self.state == "typing" or self.state == "idle") then
        love.graphics.setFont(self.font)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print(self.fullText:sub(1, self.visible), self.x + PAD_X, self.y + PAD_Y)
    end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(1)
end

return Textbox
