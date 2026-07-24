-- db.lua
-- Central access to content plus factory helpers for turning templates into live
-- instances (units, the starting party).

local Unit  = require("src.game.unit")
local Party = require("src.game.party")

local db = {}

db.abilities = require("src.game.content.abilities")
db.items     = require("src.game.content.items")
db.units     = require("src.game.content.units")

-- Instantiate a unit by template id (e.g. "raul", "skeleton").
function db.makeUnit(id)
    local t = db.units[id]
    assert(t, "unknown unit template: " .. tostring(id))
    return Unit.fromTemplate(t)
end

-- Build the initial hero party (the four starters, first four deployed) with a
-- little starting loot so the EQUIP / ITEM screens aren't empty.
function db.startingParty()
    local party = Party.new()
    for _, id in ipairs({ "raul", "victor", "lya", "furgol" }) do
        local u = party:add(db.makeUnit(id))
        party:toggleDeploy(u)
    end
    for _, id in ipairs({ "iron_ring", "bone_charm", "tome_of_embers",
                          "health_potion", "health_potion", "buckler" }) do
        party:addItem(db.items[id])
    end
    return party
end

-- Build a group of enemies by template id.
function db.makeGroup(ids)
    local group = {}
    for _, id in ipairs(ids) do group[#group + 1] = db.makeUnit(id) end
    return group
end

return db
