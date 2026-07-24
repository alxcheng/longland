-- item_screen.lua
-- Browse the shared bag by category (Armor / Weapon / Necklace / Ring / Books /
-- Consumable). Consumables prompt for a target ally and are then used (and
-- consumed). Everything else is browse + q-describe for now. Escape steps back.

local screen  = require("src.core.screen")
local input   = require("src.core.input")
local fonts   = require("src.core.fonts")
local panel   = require("src.ui.panel")
local Menu    = require("src.ui.menu")
local Textbox = require("src.ui.textbox")
local state   = require("src.game.state")

local ItemScreen = {}
ItemScreen.__index = ItemScreen

local CATEGORIES = {
    { text = "Armor",      slot = "armor" },
    { text = "Weapon",     slot = "weapon" },
    { text = "Necklace",   slot = "necklace" },
    { text = "Ring",       slot = "ring" },
    { text = "Books",      slot = "book" },
    { text = "Consumable", slot = "consumable" },
}

function ItemScreen.new()
    local self = setmetatable({}, ItemScreen)
    self.party = state.party
    self.textbox = Textbox.new()
    self.mode = "category"

    self.catMenu = Menu.new{
        x = 40, y = 70, fontSize = 18, linePad = 10, items = CATEGORIES,
        onConfirm = function(item) self:openCategory(item) end,
    }
    self.itemMenu = Menu.new{
        x = 40, y = 70, fontSize = 16, linePad = 8, items = {},
        onConfirm = function(item) self:useItem(item.item) end,
        onDescribe = function(item) self.textbox:show(item.item.desc or "No description.") end,
    }
    self.targetMenu = Menu.new{
        x = 40, y = 70, fontSize = 18, linePad = 10, items = {},
        onConfirm = function(item) self:applyTo(item.unit) end,
    }
    return self
end

function ItemScreen:openCategory(cat)
    self.category = cat
    self.mode = "items"
    local list = {}
    for _, it in ipairs(self.party:itemsOfSlot(cat.slot)) do
        list[#list + 1] = { text = it.name, item = it }
    end
    self.itemMenu:setItems(list)
end

function ItemScreen:useItem(item)
    if item.slot ~= "consumable" then return end -- only consumables act for now
    self.pending = item
    self.mode = "target"
    local roster = {}
    for i, u in ipairs(self.party.roster) do roster[i] = { text = u.name, unit = u } end
    self.targetMenu:setItems(roster)
end

function ItemScreen:applyTo(unit)
    local item = self.pending
    if item.use and item.use.resource == "hp" then
        unit:healHP(item.use.amount)
    elseif item.use and item.use.resource == "mp" then
        unit:healMP(item.use.amount)
    end
    self.party:removeItem(item)
    self.textbox:show(string.format("%s uses %s. (+%d %s)", unit.name, item.name,
        item.use.amount, string.upper(item.use.resource)))
    -- Refresh the category list and go back to it.
    self:openCategory(self.category)
end

function ItemScreen:update(dt)
    self.textbox:update(dt)
    if self.textbox:isActive() then return end
    if self.mode == "category" then
        self.catMenu:update(dt)
        if input.pressed("cancel") then screen.pop() end
    elseif self.mode == "items" then
        self.itemMenu:update(dt)
        if input.pressed("cancel") then self.mode = "category" end
    else
        self.targetMenu:update(dt)
        if input.pressed("cancel") then self.mode = "items" end
    end
end

function ItemScreen:draw()
    love.graphics.clear(0, 0, 0, 1)
    local title, menu, hint
    if self.mode == "category" then
        title, menu = "ITEM", self.catMenu
        hint = "enter: open    esc: back"
    elseif self.mode == "items" then
        title, menu = "ITEM  -  " .. self.category.text, self.itemMenu
        hint = "enter: use (consumables)    q: describe    esc: back"
    else
        title, menu = "ITEM  -  " .. self.pending.name .. "  ->  target", self.targetMenu
        hint = "enter: use on target    esc: back"
    end

    panel.titled(16, 16, 768, 418, title)
    if self.mode == "items" and #menu.items == 0 then
        love.graphics.setFont(fonts.get(15))
        love.graphics.setColor(0.6, 0.6, 0.6, 1)
        love.graphics.print("(none)", 40, 70)
        love.graphics.setColor(1, 1, 1, 1)
    else
        menu:draw()
    end

    love.graphics.setFont(fonts.get(11))
    love.graphics.setColor(0.6, 0.6, 0.6, 1)
    love.graphics.print(hint, 30, 418)
    love.graphics.setColor(1, 1, 1, 1)

    self.textbox:draw()
end

return ItemScreen
