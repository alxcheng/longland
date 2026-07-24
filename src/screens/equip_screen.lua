-- equip_screen.lua
-- Two steps: pick a party member, then equip/unequip items. A check mark marks
-- equipped items and they sort to the top. Enter on an unchecked item equips it
-- (a single slot swaps out its previous occupant, which returns to the bag; books
-- fill up to 8 and simply do nothing past the cap). Enter on a checked item
-- removes it. q describes; escape steps back / out.

local screen  = require("src.core.screen")
local input   = require("src.core.input")
local fonts   = require("src.core.fonts")
local panel   = require("src.ui.panel")
local Menu    = require("src.ui.menu")
local Textbox = require("src.ui.textbox")
local state   = require("src.game.state")
local Unit    = require("src.game.unit")

local EquipScreen = {}
EquipScreen.__index = EquipScreen

function EquipScreen.new()
    local self = setmetatable({}, EquipScreen)
    self.party = state.party
    self.textbox = Textbox.new()
    self.mode = "member"
    self.member = nil

    local roster = {}
    for i, u in ipairs(self.party.roster) do roster[i] = { text = u.name, unit = u } end
    self.memberMenu = Menu.new{
        x = 40, y = 70, fontSize = 18, linePad = 10, items = roster,
        onConfirm = function(item) self:openMember(item.unit) end,
        onDescribe = function(item) self.textbox:show(item.unit.desc or "No description.") end,
    }

    self.itemMenu = Menu.new{
        x = 34, y = 60, fontSize = 15, linePad = 6, items = {},
        onConfirm = function(item) self:toggle(item.item) end,
        onDescribe = function(item) self.textbox:show(item.item.desc or "No description.") end,
    }
    return self
end

function EquipScreen:openMember(u)
    self.member = u
    self.mode = "items"
    self:rebuild()
end

-- Build the item list: equipped items first (checked), then equippable bag items.
function EquipScreen:rebuild()
    local list = {}
    for _, it in ipairs(self.member:equippedItems()) do
        list[#list + 1] = { text = self:label(it), item = it, checked = true }
    end
    for _, it in ipairs(self.party.inventory) do
        if it.slot ~= "consumable" then
            list[#list + 1] = { text = self:label(it), item = it, checked = false }
        end
    end
    self.itemMenu:setItems(list)
end

function EquipScreen:label(it)
    return string.format("%-18s [%s]", it.name, it.slot)
end

function EquipScreen:toggle(item)
    if self.member:isEquipped(item) then
        self.member:unequip(item)
        self.party:addItem(item)
    else
        if item.slot == "book" then
            if self.member:equip(item) then self.party:removeItem(item) end
            -- past the 8-book cap equip() returns false -> nothing happens
        else
            local ok, prev = self.member:equip(item)
            if ok then
                self.party:removeItem(item)
                if prev then self.party:addItem(prev) end
            end
        end
    end
    self:rebuild()
end

function EquipScreen:update(dt)
    self.textbox:update(dt)
    if self.textbox:isActive() then return end
    if self.mode == "member" then
        self.memberMenu:update(dt)
        if input.pressed("cancel") then screen.pop() end
    else
        self.itemMenu:update(dt)
        if input.pressed("cancel") then self.mode = "member" end
    end
end

function EquipScreen:draw()
    love.graphics.clear(0, 0, 0, 1)

    if self.mode == "member" then
        panel.titled(16, 16, 768, 418, "EQUIP  -  Select Member")
        self.memberMenu:draw()
    else
        panel.titled(16, 16, 470, 418, "EQUIP  -  " .. self.member.name)
        self.itemMenu:draw()
        self:drawLoadout(502, 16, 282, 418)
    end

    love.graphics.setFont(fonts.get(11))
    love.graphics.setColor(0.6, 0.6, 0.6, 1)
    love.graphics.print("enter: equip/remove    q: describe    esc: back", 30, 442 - 24)
    love.graphics.setColor(1, 1, 1, 1)

    self.textbox:draw()
end

function EquipScreen:drawLoadout(x, y, w, h)
    local cy = panel.titled(x, y, w, h, "LOADOUT")
    love.graphics.setFont(fonts.get(13))
    local function row(slot, item)
        love.graphics.setColor(0.7, 0.75, 0.7, 1)
        love.graphics.print(slot, x + 14, cy)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print(item and item.name or "-", x + 96, cy)
        cy = cy + 22
    end
    local eq = self.member.equipment
    row("Weapon", eq.weapon)
    row("Shield", eq.shield)
    row("Armor", eq.armor)
    row("Necklace", eq.necklace)
    row("Ring", eq.ring)
    cy = cy + 6
    love.graphics.setColor(0.7, 0.75, 0.7, 1)
    love.graphics.print(string.format("Books  %d/%d", self.member:bookCount(), Unit.maxBooks()), x + 14, cy)
    love.graphics.setColor(1, 1, 1, 1)
    cy = cy + 20
    for _, b in ipairs(eq.books) do
        love.graphics.print("- " .. b.name, x + 24, cy)
        cy = cy + 18
    end
end

return EquipScreen
