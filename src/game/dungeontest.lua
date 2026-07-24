-- dungeontest.lua
-- Verifies the map/movement layer: turning, wall-blocked movement, out-of-bounds,
-- safe-room MP restore, and that a walk through the real Dungeon screen (with
-- encounters disabled) plus the first-person renderer run without error.
-- Run with `love . dungeontest`.

local M = {}

function M.run()
    local Map     = require("src.dungeon.map")
    local view    = require("src.dungeon.view")
    local state   = require("src.game.state")
    local Dungeon = require("src.screens.dungeon")

    local out, fails = {}, 0
    local function line(s) out[#out + 1] = s or "" end
    local function check(name, cond)
        if not cond then fails = fails + 1 end
        line((cond and "  ok   " or "  FAIL ") .. name)
    end

    -- Map basics.
    local m = Map.sample()
    check("out-of-bounds reads as solid", m:isSolid(0, 0) and m:isSolid(m.w + 1, 1))
    check("start cell is walkable", m:isWalkable(m.start.x, m.start.y))
    check("start faces east", m.start.dir == "e")

    -- Turn tables round-trip.
    check("turn left 4x returns to start", Map.LEFT[Map.LEFT[Map.LEFT[Map.LEFT.e]]] == "e")
    check("left then right is identity", Map.RIGHT[Map.LEFT.n] == "n")

    -- Drive the real screen.
    love.math.setRandomSeed(3)
    state.newGame()
    local d = Dungeon.new()
    d.encounterRate = 0 -- keep the test from pushing battles

    -- Facing east at the start, forward should increase x; a turn shouldn't move.
    local sx, sy = d.px, d.py
    d:forward()
    check("forward moves east into the corridor", d.px == sx + 1 and d.py == sy)
    d:turnLeft()
    check("turning does not change position", d.px == sx + 1 and d.py == sy)
    check("turn left from east faces north", d.dir == "n")

    -- Walk into a wall: face north from the top corridor (a wall is directly N).
    local bx, by = d.px, d.py
    d:forward() -- north is the border wall here
    check("walking into a wall is blocked", d.px == bx and d.py == by)

    -- Long random walk: never lands on a solid cell, never errors.
    local ok = true
    for _ = 1, 500 do
        local r = love.math.random(4)
        if r == 1 then d:forward()
        elseif r == 2 then d:back()
        elseif r == 3 then d:turnLeft()
        else d:turnRight() end
        if m:isSolid(d.px, d.py) then ok = false end
    end
    check("500-step walk never enters solid rock", ok)

    -- Safe-room restore: drain MP, drop the party onto the safe tile, re-enter.
    local sxx, syy
    for y = 1, m.h do for x = 1, m.w do if m:isSafe(x, y) then sxx, syy = x, y end end end
    check("map has a safe room", sxx ~= nil)
    local u = state.party.deployed[1]
    u.mp = 0
    d.px, d.py, d.wasSafe = sxx, syy, false
    d:enterCell(false)
    check("safe room restores MP to full", u.mp == u:maxMP())

    -- Renderer runs without error for every facing.
    local rendered = true
    for _, dir in ipairs({ "n", "e", "s", "w" }) do
        local okr = pcall(view.draw, m, m.start.x, m.start.y, dir)
        if not okr then rendered = false end
    end
    check("first-person renderer runs for all facings", rendered)

    line("")
    line(fails == 0 and "RESULT: ALL CHECKS PASSED" or ("RESULT: " .. fails .. " FAILED"))
    local text = table.concat(out, "\n")
    print(text)
    love.filesystem.write("dungeontest.log", text)
end

return M
