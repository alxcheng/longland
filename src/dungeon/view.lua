-- dungeon/view.lua
-- First-person wireframe renderer for a grid map, in the Wizardry PC-98 spirit:
-- green lines on black. Walks forward from the player up to a depth limit,
-- drawing each cell's left/right walls as receding trapezoids and closing the
-- corridor with a front face when the way ahead is solid.
--
-- Geometry: each depth boundary is a rectangle centred on the view, shrinking
-- toward the vanishing point. Cell i occupies the space between boundary i (near)
-- and boundary i+1 (far).

local Map = require("src.dungeon.map")

local view = {}

-- View frame (game space): fills the area above the bottom panels.
local CX, CY, HW, HH = 400, 150, 400, 150
-- Scale of each depth boundary rectangle (index = depth + 1).
local DEPTH = { 1.0, 0.50, 0.26, 0.135, 0.07, 0.04 }
local MAX_DEPTH = 4
local COLOR = { 0.36, 0.78, 0.55 }

local function rectAt(i)
    local s = DEPTH[i + 1] or DEPTH[#DEPTH]
    return {
        l = CX - HW * s, r = CX + HW * s,
        t = CY - HH * s, b = CY + HH * s,
    }
end

-- A side-wall trapezoid outline between near edge x and far edge x.
local function wallPanel(nearX, farX, near, far)
    love.graphics.line(nearX, near.t, farX, far.t)
    love.graphics.line(farX, far.t, farX, far.b)
    love.graphics.line(farX, far.b, nearX, near.b)
    love.graphics.line(nearX, near.b, nearX, near.t)
end

function view.draw(map, px, py, dir)
    love.graphics.setColor(COLOR[1], COLOR[2], COLOR[3], 1)
    love.graphics.setLineWidth(1)

    local fwd = Map.DIRS[dir]
    local lv = Map.DIRS[Map.LEFT[dir]]
    local rv = Map.DIRS[Map.RIGHT[dir]]

    for i = 0, MAX_DEPTH do
        local cx, cy = px + fwd[1] * i, py + fwd[2] * i
        if map:isSolid(cx, cy) then break end

        local near, far = rectAt(i), rectAt(i + 1)
        local leftSolid  = map:isSolid(cx + lv[1], cy + lv[2])
        local rightSolid = map:isSolid(cx + rv[1], cy + rv[2])
        local frontSolid = map:isSolid(cx + fwd[1], cy + fwd[2])

        if leftSolid then
            wallPanel(near.l, far.l, near, far)
        else
            love.graphics.line(near.l, near.t, far.l, far.t) -- ceiling edge (opening)
            love.graphics.line(near.l, near.b, far.l, far.b) -- floor edge
        end

        if rightSolid then
            wallPanel(near.r, far.r, near, far)
        else
            love.graphics.line(near.r, near.t, far.r, far.t)
            love.graphics.line(near.r, near.b, far.r, far.b)
        end

        if frontSolid then
            love.graphics.rectangle("line", far.l, far.t, far.r - far.l, far.b - far.t)
            break
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
end

return view
