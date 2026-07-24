-- sprites.lua
-- Registry of dummy character/enemy sprites and a factory for idle Animations.
-- Frames are square (= image height) unless overridden (Champion is 128x111).
-- Each unit gets its own Anim instance so their idle loops drift out of phase.

local Anim = require("src.core.sprite")

local sprites = {}

local defs = {
    -- heroes
    knight   = { file = "assets/sprites/heroes/Knight/Idle.png",    fps = 8 },
    champion = { file = "assets/sprites/heroes/Champion/Idle.png",  fw = 128, fh = 111, count = 10, fps = 8 },
    nomad    = { file = "assets/sprites/heroes/Nomad/Idle.png",     fps = 8 },
    brigand  = { file = "assets/sprites/heroes/Brigand/Idle.png",   fps = 8 },
    -- enemies
    skeleton = { file = "assets/sprites/enemies/Skeleton/Idle.png", fps = 6 },
    imp      = { file = "assets/sprites/enemies/Imp/Idle.png",      fps = 6 },
    mushroom = { file = "assets/sprites/enemies/Mushroom/Idle.png", fps = 6 },
}

local imageCache, dataCache = {}, {}
local function loadImage(path)
    if not imageCache[path] then
        local img = love.graphics.newImage(path)
        img:setFilter("nearest", "nearest")
        imageCache[path] = img
    end
    return imageCache[path]
end
local function loadData(path)
    if not dataCache[path] then
        dataCache[path] = love.image.newImageData(path)
    end
    return dataCache[path]
end

-- Opaque bounding box of a frame region, for aligning by visible content.
local function contentBox(data, fw, fh)
    local minx, miny, maxx, maxy = fw, fh, 0, 0
    local found = false
    for y = 0, fh - 1 do
        for x = 0, fw - 1 do
            local _, _, _, a = data:getPixel(x, y)
            if a > 0.3 then
                found = true
                if x < minx then minx = x end
                if x > maxx then maxx = x end
                if y < miny then miny = y end
                if y > maxy then maxy = y end
            end
        end
    end
    if not found then return 0, 0, fw - 1, fh - 1 end
    return minx, miny, maxx, maxy
end

function sprites.has(id) return defs[id] ~= nil end

-- A fresh idle Animation for a sprite id, or nil if unknown. The content box of
-- frame 1 is computed once per def and cached.
function sprites.idle(id)
    local d = defs[id]
    if not d then return nil end
    -- Sprite art is not bundled in this repo; run without sprites if missing.
    local ok, img = pcall(loadImage, d.file)
    if not ok then return nil end
    local iw, ih = img:getDimensions()
    local fh = d.fh or ih
    local fw = d.fw or fh
    local count = d.count or math.floor(iw / fw)
    local anim = Anim.new(img, fw, fh, count, d.fps)

    if not d._box then
        d._box = { contentBox(loadData(d.file), fw, fh) }
    end
    anim:setContentBox(d._box[1], d._box[2], d._box[3], d._box[4])
    return anim
end

return sprites
