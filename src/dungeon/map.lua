-- dungeon/map.lua
-- A Wizardry-style grid floor, parsed from ASCII. Carved-cell model: a cell is
-- either solid rock ('#') or open floor; a "wall" between two cells exists when
-- the neighbour is solid. Coordinates are 1-based (x, y) with y increasing
-- downward, so north = y-1.
--
-- Legend:  #=wall  .=floor  S=safe room  @=start (becomes floor)

local Map = {}
Map.__index = Map

-- Direction unit vectors and turn tables.
Map.DIRS  = { n = { 0, -1 }, e = { 1, 0 }, s = { 0, 1 }, w = { -1, 0 } }
Map.LEFT  = { n = "w", w = "s", s = "e", e = "n" }
Map.RIGHT = { n = "e", e = "s", s = "w", w = "n" }
Map.BACK  = { n = "s", s = "n", e = "w", w = "e" }
Map.LABEL = { n = "N", e = "E", s = "S", w = "W" }

function Map.fromAscii(rows, startDir)
    local self = setmetatable({}, Map)
    self.h = #rows
    self.w = #rows[1]
    self.grid = {}
    self.start = { x = 1, y = 1, dir = startDir or "n" }
    for y = 1, self.h do
        self.grid[y] = {}
        for x = 1, self.w do
            local c = rows[y]:sub(x, x)
            if c == "@" then
                self.start.x, self.start.y = x, y
                c = "."
            end
            self.grid[y][x] = c
        end
    end
    return self
end

function Map:cell(x, y)
    if x < 1 or y < 1 or x > self.w or y > self.h then return "#" end
    return self.grid[y][x]
end

function Map:isSolid(x, y)    return self:cell(x, y) == "#" end
function Map:isWalkable(x, y) return not self:isSolid(x, y) end
function Map:isSafe(x, y)     return self:cell(x, y) == "S" end

-- The starter floor: an outer ring with an inner room reached from the bottom,
-- and a safe room (S) tucked in the middle.
function Map.sample()
    return Map.fromAscii({
        "############",
        "#@.........#",
        "#.########.#",
        "#.#......#.#",
        "#.#.####.#.#",
        "#.#.#SS#.#.#",
        "#.#.#..#.#.#",
        "#..........#",
        "############",
    }, "e")
end

return Map
