-- party_screen.lua
-- Roster list. Enter toggles deployment (a check mark appears); deploying past the
-- cap is a no-op. q describes; escape backs out.

local screen  = require("src.core.screen")
local input   = require("src.core.input")
local fonts   = require("src.core.fonts")
local panel   = require("src.ui.panel")
local Menu    = require("src.ui.menu")
local Textbox = require("src.ui.textbox")
local state   = require("src.game.state")

local PartyScreen = {}
PartyScreen.__index = PartyScreen

function PartyScreen.new()
    local self = setmetatable({}, PartyScreen)
    self.party = state.party
    self.textbox = Textbox.new()

    local items = {}
    for i, u in ipairs(self.party.roster) do
        items[i] = { text = u.name, unit = u, checked = self.party:isDeployed(u) }
    end
    self.menu = Menu.new{
        x = 40, y = 70, fontSize = 18, linePad = 10, items = items,
        onConfirm = function(item)
            self.party:toggleDeploy(item.unit)          -- no-op if over cap
            item.checked = self.party:isDeployed(item.unit)
        end,
        onDescribe = function(item) self.textbox:show(item.unit.desc or "No description.") end,
    }
    return self
end

function PartyScreen:update(dt)
    self.textbox:update(dt)
    if self.textbox:isActive() then return end
    self.menu:update(dt)
    if input.pressed("cancel") then screen.pop() end
end

function PartyScreen:draw()
    love.graphics.clear(0, 0, 0, 1)
    panel.titled(16, 16, 768, 418, "PARTY")

    love.graphics.setFont(fonts.get(13))
    love.graphics.setColor(0.8, 0.8, 0.8, 1)
    love.graphics.printf(string.format("Deployed %d / %d", self.party:deployedCount(), self.party.cap),
        16, 24, 768 - 20, "right")
    love.graphics.setColor(1, 1, 1, 1)

    self.menu:draw()

    love.graphics.setFont(fonts.get(11))
    love.graphics.setColor(0.6, 0.6, 0.6, 1)
    love.graphics.print("enter: deploy/recall    q: describe    esc: back", 30, 406)
    love.graphics.setColor(1, 1, 1, 1)

    self.textbox:draw()
end

return PartyScreen
