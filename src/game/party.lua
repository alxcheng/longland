-- party.lua
-- The player's roster: every recruited unit, which subset is deployed (capped),
-- and the shared item bag. Deploy/undeploy is a toggle; going over the cap simply
-- fails (the PARTY screen relies on this — "if over limit, nothing will happen").

local class = require("src.lib.class")

local Party = class()

local DEFAULT_CAP = 4

function Party:init(opts)
    opts = opts or {}
    self.roster = {}       -- all units
    self.deployed = {}     -- subset, in deploy order
    self.inventory = {}    -- shared items
    self.cap = opts.cap or DEFAULT_CAP
end

function Party:add(unit)
    self.roster[#self.roster + 1] = unit
    return unit
end

function Party:addItem(item)
    self.inventory[#self.inventory + 1] = item
    return item
end

function Party:removeItem(item)
    for i, it in ipairs(self.inventory) do
        if it == item then
            table.remove(self.inventory, i)
            return true
        end
    end
    return false
end

-- Inventory items of a given equipment slot ("weapon", "book", "consumable"...).
function Party:itemsOfSlot(slot)
    local list = {}
    for _, it in ipairs(self.inventory) do
        if it.slot == slot then list[#list + 1] = it end
    end
    return list
end

function Party:isDeployed(unit)
    for _, u in ipairs(self.deployed) do
        if u == unit then return true end
    end
    return false
end

function Party:deployedCount()
    return #self.deployed
end

-- Toggle deployment. Returns true if the state changed. Deploying past the cap
-- is a no-op (returns false).
function Party:toggleDeploy(unit)
    for i, u in ipairs(self.deployed) do
        if u == unit then
            table.remove(self.deployed, i)
            return true
        end
    end
    if #self.deployed >= self.cap then return false end
    self.deployed[#self.deployed + 1] = unit
    return true
end

return Party
