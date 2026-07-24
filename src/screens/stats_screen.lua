-- stats_screen.lua
-- Roster on the left (check marks on deployed members); the highlighted member's
-- full stat sheet + abilities on the right. q describes; escape/backspace backs out.

local screen  = require("src.core.screen")
local input   = require("src.core.input")
local fonts   = require("src.core.fonts")
local panel   = require("src.ui.panel")
local Menu    = require("src.ui.menu")
local Textbox = require("src.ui.textbox")
local state   = require("src.game.state")
local report  = require("src.game.report")

local StatsScreen = {}
StatsScreen.__index = StatsScreen

function StatsScreen.new()
    local self = setmetatable({}, StatsScreen)
    self.party = state.party
    self.textbox = Textbox.new()

    local items = {}
    for i, u in ipairs(self.party.roster) do
        items[i] = { text = u.name, unit = u, checked = self.party:isDeployed(u) }
    end
    self.menu = Menu.new{
        x = 34, y = 60, fontSize = 16, linePad = 8, items = items,
        onDescribe = function(item) self.textbox:show(item.unit.desc or "No description.") end,
    }
    return self
end

function StatsScreen:selected() return self.menu:selected().unit end

function StatsScreen:update(dt)
    self.textbox:update(dt)
    if self.textbox:isActive() then return end
    self.menu:update(dt)
    if input.pressed("cancel") then screen.pop() end
end

function StatsScreen:draw()
    love.graphics.clear(0, 0, 0, 1)

    panel.titled(16, 16, 240, 418, "STATS")
    self.menu:draw()

    local cx = 272
    panel.titled(cx, 16, 512, 418, self:selected().name)
    local u = self:selected()

    love.graphics.setFont(fonts.get(13))
    love.graphics.setColor(1, 1, 1, 1)
    local lines = report.statLines(u)
    for i, line in ipairs(lines) do
        local col = (i - 1) >= 8 and 1 or 0
        local row = (i - 1) % 8
        love.graphics.print(line, cx + 20 + col * 240, 64 + row * 22)
    end

    love.graphics.setColor(0.88, 0.88, 0.66, 1)
    love.graphics.print("Abilities", cx + 20, 64 + 8 * 22 + 8)
    love.graphics.setColor(1, 1, 1, 1)
    local names = report.abilityNames(u)
    love.graphics.printf(#names > 0 and table.concat(names, ",  ") or "(none)",
        cx + 20, 64 + 9 * 22 + 8, 472, "left")

    love.graphics.setFont(fonts.get(11))
    love.graphics.setColor(0.6, 0.6, 0.6, 1)
    love.graphics.print("q: describe    esc: back", cx + 20, 406)
    love.graphics.setColor(1, 1, 1, 1)

    self.textbox:draw()
end

return StatsScreen
