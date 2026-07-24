-- sprite.lua
-- A horizontal strip animation. Frames are laid out left-to-right in a single row
-- (the LuizMelo-style packs these dummy assets come from). The draw origin is the
-- bottom-center of a frame, so a unit is placed by its feet on a ground line and
-- mirrors cleanly by flipping the x scale.

local class = require("src.lib.class")

local Anim = class()

function Anim:init(image, frameW, frameH, count, fps)
    self.image = image
    self.fw, self.fh = frameW, frameH
    self.count = math.max(1, count or 1)
    self.fps = fps or 8
    self.quads = {}
    local iw, ih = image:getDimensions()
    for i = 0, self.count - 1 do
        self.quads[i + 1] = love.graphics.newQuad(i * frameW, 0, frameW, frameH, iw, ih)
    end
    self.t = 0
    self.frame = 1
    -- Draw origin, defaults to frame bottom-centre. setContentBox refines this to
    -- the actual sprite so mixed-padding packs line up by their feet.
    self.originX = frameW / 2
    self.originY = frameH
    self.contentW = frameW
    self.contentH = frameH
end

-- Tighten the origin to the opaque content: originX/originY become the bottom
-- centre of the visible body, and contentW/H its size (used to scale by visible
-- height rather than by the padded frame).
function Anim:setContentBox(minX, minY, maxX, maxY)
    self.originX = (minX + maxX) / 2
    self.originY = maxY + 1
    self.contentW = maxX - minX + 1
    self.contentH = maxY - minY + 1
end

function Anim:update(dt)
    if self.count <= 1 then return end
    local spf = 1 / self.fps
    self.t = self.t + dt
    while self.t >= spf do
        self.t = self.t - spf
        self.frame = self.frame % self.count + 1
    end
end

-- Draw with the content's bottom-centre at (x, y). scale multiplies size; flip
-- mirrors horizontally.
function Anim:draw(x, y, scale, flip)
    scale = scale or 1
    local sx = flip and -scale or scale
    love.graphics.draw(self.image, self.quads[self.frame], x, y, 0, sx, scale, self.originX, self.originY)
end

function Anim:size() return self.fw, self.fh end

return Anim
