-- dungeon.lua
-- The dungeon hub ("Map"): Wizardry-style first-person grid traversal plus the
-- command menu. Two input modes:
--   MOVE  (default): arrows/wasd -> forward / back / turn; Enter opens the menu.
--   MENU:            the command list (EQUIP/ITEM/PARTY/STATS/DESCEND) is active;
--                    Esc returns to MOVE.
-- Safe rooms restore the party's MP; ordinary steps may trigger a random
-- encounter.

local screen  = require("src.core.screen")
local input   = require("src.core.input")
local fonts   = require("src.core.fonts")
local panel   = require("src.ui.panel")
local Menu    = require("src.ui.menu")
local Textbox = require("src.ui.textbox")
local state   = require("src.game.state")
local Map     = require("src.dungeon.map")
local view    = require("src.dungeon.view")

local StatsScreen = require("src.screens.stats_screen")
local PartyScreen = require("src.screens.party_screen")
local EquipScreen = require("src.screens.equip_screen")
local ItemScreen  = require("src.screens.item_screen")
local Encounter   = require("src.screens.encounter")

local Dungeon = {}
Dungeon.__index = Dungeon

local ENCOUNTER_RATE = 0.12
local ENEMY_GROUPS = {
    { "skeleton" },
    { "goblin", "goblin" },
    { "skeleton", "goblin" },
    { "skeleton", "goblin", "witch" },
}

function Dungeon.new()
    local self = setmetatable({}, Dungeon)
    self.map = Map.sample()
    self.px, self.py, self.dir = self.map.start.x, self.map.start.y, self.map.start.dir
    self.visited = {}
    self.mode = "move"
    self.encounterRate = ENCOUNTER_RATE
    self.textbox = Textbox.new()

    self.menu = Menu.new{
        x = 40, y = 348, fontSize = 16, linePad = 6,
        items = {
            { text = "EQUIP",   go = function() screen.push(EquipScreen.new()) end },
            { text = "ITEM",    go = function() screen.push(ItemScreen.new()) end },
            { text = "PARTY",   go = function() screen.push(PartyScreen.new()) end },
            { text = "STATS",   go = function() screen.push(StatsScreen.new()) end },
            { text = "DESCEND", go = function() self:startEncounter() end },
        },
        onConfirm = function(item) item.go() end,
    }

    self:visit()
    self:enterCell(true)
    return self
end

----------------------------------------------------------------- movement
function Dungeon:visit()
    self.visited[self.py * self.map.w + self.px] = true
end

function Dungeon:step(d)
    local nx, ny = self.px + d[1], self.py + d[2]
    if self.map:isWalkable(nx, ny) then
        self.px, self.py = nx, ny
        self:visit()
        self:enterCell(false)
        self:maybeEncounter()
    end
end

function Dungeon:forward() self:step(Map.DIRS[self.dir]) end
function Dungeon:back()    self:step(Map.DIRS[Map.BACK[self.dir]]) end
function Dungeon:turnLeft()  self.dir = Map.LEFT[self.dir] end
function Dungeon:turnRight() self.dir = Map.RIGHT[self.dir] end

-- Safe rooms top the party's MP back up ("unlimited MP while inside").
function Dungeon:enterCell(initial)
    local safe = self.map:isSafe(self.px, self.py)
    if safe and (initial or not self.wasSafe) then
        for _, u in ipairs(state.party.deployed) do
            if not u.mindless then u.mp = u:maxMP() end
        end
        self.textbox:show("A safe room. Your minds settle and your magic is restored.")
    end
    self.wasSafe = safe
end

function Dungeon:maybeEncounter()
    if self.map:isSafe(self.px, self.py) then return end
    if love.math.random() < self.encounterRate then
        self:startEncounter()
    end
end

function Dungeon:startEncounter()
    local group = ENEMY_GROUPS[love.math.random(#ENEMY_GROUPS)]
    screen.push(Encounter.new(group))
end

----------------------------------------------------------------- update
function Dungeon:update(dt)
    self.textbox:update(dt)
    if self.textbox:isActive() then return end

    if self.mode == "move" then
        if input.pressed("up")    then self:forward() end
        if input.pressed("down")  then self:back() end
        if input.pressed("left")  then self:turnLeft() end
        if input.pressed("right") then self:turnRight() end
        if input.pressed("confirm") then self.mode = "menu"; self.menu.index = 1 end
    else
        self.menu:update(dt)
        if input.pressed("cancel") then self.mode = "move" end
    end
end

----------------------------------------------------------------- drawing
local function drawUnitRow(u, x, y, w)
    love.graphics.setFont(fonts.get(13))
    love.graphics.setColor(1, 1, 1, u.alive and 1 or 0.4)
    love.graphics.print(u.name, x, y)

    local barX, barW, barH = x + 90, w - 150, 7
    local function bar(by, frac, r, g, b)
        love.graphics.setColor(0.15, 0.15, 0.15, 1)
        love.graphics.rectangle("fill", barX, by, barW, barH)
        love.graphics.setColor(r, g, b, 1)
        love.graphics.rectangle("fill", barX, by, barW * math.max(0, frac), barH)
        love.graphics.setColor(1, 1, 1, 0.5)
        love.graphics.rectangle("line", barX, by, barW, barH)
    end
    bar(y + 1, u:hpPercent(), 0.7, 0.2, 0.2)
    bar(y + 10, u.mindless and 0 or u:mpPercent(), 0.25, 0.35, 0.75)

    love.graphics.setFont(fonts.get(11))
    love.graphics.setColor(0.8, 0.8, 0.8, 1)
    love.graphics.printf(u:hpString(), barX + barW + 6, y - 1, 56, "left")
    love.graphics.printf(u:mpString(), barX + barW + 6, y + 9, 56, "left")
    love.graphics.setColor(1, 1, 1, 1)
end

-- Fog-revealed minimap in the top-right of the view.
function Dungeon:drawMinimap()
    local cs = 6
    local mw, mh = self.map.w * cs, self.map.h * cs
    local ox, oy = 800 - mw - 12, 12
    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.rectangle("fill", ox - 3, oy - 3, mw + 6, mh + 6)
    for y = 1, self.map.h do
        for x = 1, self.map.w do
            if self.visited[y * self.map.w + x] then
                local c = self.map:cell(x, y)
                if c == "S" then love.graphics.setColor(0.3, 0.5, 0.85, 1)
                else love.graphics.setColor(0.3, 0.55, 0.4, 1) end
                love.graphics.rectangle("fill", ox + (x - 1) * cs, oy + (y - 1) * cs, cs - 1, cs - 1)
            end
        end
    end
    -- Player marker: a little triangle pointing the facing way.
    local d = Map.DIRS[self.dir]
    local pcx = ox + (self.px - 0.5) * cs
    local pcy = oy + (self.py - 0.5) * cs
    love.graphics.setColor(0.95, 0.85, 0.4, 1)
    love.graphics.polygon("fill",
        pcx + d[1] * 3, pcy + d[2] * 3,
        pcx - d[1] * 3 - d[2] * 3, pcy - d[2] * 3 - d[1] * 3,
        pcx - d[1] * 3 + d[2] * 3, pcy - d[2] * 3 + d[1] * 3)
    love.graphics.setColor(1, 1, 1, 1)
end

function Dungeon:draw()
    view.draw(self.map, self.px, self.py, self.dir)

    love.graphics.setFont(fonts.get(12))
    love.graphics.setColor(0.6, 0.7, 0.6, 1)
    love.graphics.print("LONGLAND  -  B1F", 12, 10)
    love.graphics.print(string.format("Facing %s   (%d,%d)", Map.LABEL[self.dir], self.px, self.py), 12, 26)
    love.graphics.setColor(1, 1, 1, 1)

    self:drawMinimap()

    -- Command panel: active list in MENU mode, dim hint in MOVE mode.
    if self.mode == "menu" then
        panel.titled(16, 312, 200, 126, "COMMAND")
        self.menu:draw()
    else
        panel.titled(16, 312, 200, 126, "MOVE")
        love.graphics.setFont(fonts.get(13))
        love.graphics.setColor(0.6, 0.6, 0.6, 1)
        love.graphics.print("wasd / arrows to move", 30, 350)
        love.graphics.print("Enter: open command menu", 30, 370)
        love.graphics.setColor(1, 1, 1, 1)
    end

    -- Roster panel.
    local ry = panel.titled(232, 312, 552, 126, "PARTY")
    if state.party then
        local col = 0
        for _, u in ipairs(state.party.deployed) do
            local x = 246 + (col % 2) * 268
            local y = ry + math.floor(col / 2) * 40
            drawUnitRow(u, x, y, 260)
            col = col + 1
        end
    end

    self.textbox:draw()
    love.graphics.setColor(1, 1, 1, 1)
end

return Dungeon
