-- unit.lua
-- A live unit instance. Effective stats are resolved on demand from:
--   base stat   +  equipment `mods`  +  equipped weapon's ATK (into its rating)
-- so equipping/unequipping just works with no recomputation bookkeeping. Tracks
-- current HP/MP and the dead / insane conditions.

local class  = require("src.lib.class")
local stats  = require("src.game.stats")
local ABILITIES = require("src.game.content.abilities")
local ITEMS  = require("src.game.content.items")

local Unit = class()

local EQUIP_SLOTS = { "weapon", "shield", "armor", "necklace", "ring" }
local MAX_BOOKS = 8

-- Shallow copy so each unit owns a distinct item instance (equip/unequip moves
-- items by identity, and starting templates like Tattered Clothes are shared).
local function cloneItem(t)
    local c = {}
    for k, v in pairs(t) do c[k] = v end
    return c
end

-- Build a unit from a content template (see content/units.lua).
function Unit.fromTemplate(t)
    local u = Unit.new()
    u.name = t.name or "Unit"
    u.side = t.side or "hero"        -- "hero" | "enemy"
    u.row  = t.row  or "front"       -- "front" | "back"
    u.sprite = t.sprite              -- sprite id (see game/sprites.lua)
    u.mindless = t.mindless or false
    u.unstoppable = t.unstoppable or false
    u.innate = {}
    for i, id in ipairs(t.innate or {}) do u.innate[i] = id end

    -- Base stats: defaults overlaid with the template's overrides.
    u.base = {}
    for key, def in pairs(stats.default) do u.base[key] = def end
    for key, val in pairs(t.base or {}) do u.base[key] = val end
    if u.mindless then u.base.maxMP = 0 end

    -- Equipment.
    u.equipment = { books = {} }
    for _, slot in ipairs(EQUIP_SLOTS) do
        local id = t.equipment and t.equipment[slot]
        if id then u.equipment[slot] = cloneItem(ITEMS[id]) end
    end
    for _, id in ipairs((t.equipment and t.equipment.books) or {}) do
        u.equipment.books[#u.equipment.books + 1] = cloneItem(ITEMS[id])
    end

    -- Fill resources.
    u.hp = u:maxHP()
    u.mp = u:maxMP()
    u.alive = true
    u.insane = false
    u.av = 0                          -- action value, driven by the battle scheduler
    return u
end

-- All currently-equipped items (slots + books), as a flat list.
function Unit:equippedItems()
    local list = {}
    for _, slot in ipairs(EQUIP_SLOTS) do
        if self.equipment[slot] then list[#list + 1] = self.equipment[slot] end
    end
    for _, book in ipairs(self.equipment.books) do list[#list + 1] = book end
    return list
end

-- Effective value of a stat: base + equipment mods + weapon ATK into its rating.
function Unit:stat(key)
    local v = self.base[key] or 0
    for _, item in ipairs(self:equippedItems()) do
        if item.mods and item.mods[key] then v = v + item.mods[key] end
    end
    local w = self.equipment.weapon
    if w and w.atk and w.weaponType and stats.weaponRating[w.weaponType] == key then
        v = v + w.atk
    end
    return v
end

function Unit:maxHP() return self:stat("maxHP") end
function Unit:maxMP() return self:stat("maxMP") end

function Unit:hasShield()
    return self.equipment.shield ~= nil
end

function Unit:hasWeaponType(weaponType)
    local w = self.equipment.weapon
    return w ~= nil and w.weaponType == weaponType
end

-- The abilities this unit can currently use: innate + granted by equipment.
-- Returns a list of { id, def } preserving order and de-duplicated.
function Unit:abilities()
    local list, seen = {}, {}
    local function add(id)
        if id and ABILITIES[id] and not seen[id] then
            seen[id] = true
            list[#list + 1] = { id = id, def = ABILITIES[id] }
        end
    end
    for _, id in ipairs(self.innate) do add(id) end
    for _, item in ipairs(self:equippedItems()) do
        for _, id in ipairs(item.grants or {}) do add(id) end
    end
    return list
end

-- Can this unit meet an ability's weapon requirement? Innate abilities (enemies
-- with no weapon) always qualify.
function Unit:canUseAbility(id)
    local def = ABILITIES[id]
    if not def then return false end
    for _, innateId in ipairs(self.innate) do
        if innateId == id then return true end
    end
    if def.requiresShield and not self:hasShield() then return false end
    if def.weapon and not self:hasWeaponType(def.weapon) then return false end
    return true
end

----------------------------------------------------------------- equipment
function Unit:isEquipped(item)
    for _, it in ipairs(self:equippedItems()) do
        if it == item then return true end
    end
    return false
end

-- Equip an item into its slot. Books fill the next of MAX_BOOKS slots. For the
-- single slots, returns (true, previousItem) so the caller can return the
-- displaced item to the bag. Returns false if it can't be equipped (e.g. book
-- limit reached, or a consumable).
function Unit:equip(item)
    local slot = item.slot
    if slot == "book" then
        if #self.equipment.books >= MAX_BOOKS then return false end
        self.equipment.books[#self.equipment.books + 1] = item
        return true, nil
    end
    for _, s in ipairs(EQUIP_SLOTS) do
        if s == slot then
            local prev = self.equipment[slot]
            self.equipment[slot] = item
            return true, prev
        end
    end
    return false
end

function Unit:unequip(item)
    for _, slot in ipairs(EQUIP_SLOTS) do
        if self.equipment[slot] == item then
            self.equipment[slot] = nil
            return true
        end
    end
    for i, book in ipairs(self.equipment.books) do
        if book == item then
            table.remove(self.equipment.books, i)
            return true
        end
    end
    return false
end

function Unit:bookCount() return #self.equipment.books end
function Unit.maxBooks() return MAX_BOOKS end

----------------------------------------------------------------- resources
-- Clamp helpers keep current HP/MP inside [0, max] and flip the state flags.
function Unit:damageHP(amount)
    self.hp = math.max(0, math.min(self:maxHP(), self.hp - amount))
    if self.hp <= 0 then self.alive = false end
    return self.hp
end

function Unit:damageMP(amount)
    if self.mindless then return self.mp end
    self.mp = math.max(0, math.min(self:maxMP(), self.mp - amount))
    if self.mp <= 0 then self.insane = true end
    return self.mp
end

function Unit:healHP(amount) return self:damageHP(-amount) end
function Unit:healMP(amount) return self:damageMP(-amount) end

function Unit:hpPercent()
    local m = self:maxHP()
    return m > 0 and self.hp / m or 0
end

function Unit:mpPercent()
    local m = self:maxMP()
    return m > 0 and self.mp / m or 0
end

-- "0/0" for mindless units per the doc.
function Unit:hpString() return string.format("%d/%d", self.hp, self:maxHP()) end
function Unit:mpString() return string.format("%d/%d", self.mp, self:maxMP()) end

return Unit
