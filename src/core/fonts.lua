-- fonts.lua
-- Cached fonts by pixel size. Uses LOVE's built-in TrueType for now; swap the
-- FONT_PATH to a bundled .ttf later and everything picks it up.
local fonts = {}

local FONT_PATH = nil -- e.g. "assets/fonts/yourfont.ttf"
local cache = {}

function fonts.get(size)
    size = math.floor(size + 0.5)
    local key = size
    if not cache[key] then
        if FONT_PATH then
            cache[key] = love.graphics.newFont(FONT_PATH, size)
        else
            cache[key] = love.graphics.newFont(size)
        end
    end
    return cache[key]
end

return fonts
