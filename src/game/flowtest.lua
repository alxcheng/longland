-- flowtest.lua
-- Headless exercise of the interactive screen handlers (equip/unequip swaps,
-- book grants, consumable use) that a static screenshot can't cover. Drives the
-- real screen objects and asserts the resulting party/unit state.
-- Run with `love . flowtest`; results go to flowtest.log in the LOVE save dir.

local M = {}

function M.run()
    local state = require("src.game.state")
    local db    = require("src.game.db")
    local EquipScreen = require("src.screens.equip_screen")
    local ItemScreen  = require("src.screens.item_screen")

    local out, fails = {}, 0
    local function line(s) out[#out + 1] = s or "" end
    local function check(name, cond)
        if not cond then fails = fails + 1 end
        line((cond and "  ok   " or "  FAIL ") .. name)
    end
    local function invHas(party, item)
        for _, it in ipairs(party.inventory) do if it == item then return true end end
        return false
    end

    state.newGame()
    local party = state.party
    local raul = party.roster[1]

    -- Give Raul a spare weapon in the bag so we can test a single-slot swap.
    local spareSword = db.makeUnit("raul").equipment.weapon -- a fresh Rusty Sword instance
    party:addItem(spareSword)
    local oldSword = raul.equipment.weapon

    local eq = EquipScreen.new()
    eq:openMember(raul)

    -- Weapon swap: equipping the spare should displace the old one back to the bag.
    eq:toggle(spareSword)
    check("weapon swap equips spare", raul.equipment.weapon == spareSword)
    check("weapon swap returns old weapon to bag", invHas(party, oldSword))
    check("spare weapon left the bag", not invHas(party, spareSword))
    check("Raul physical still 20 after swap", raul:stat("physical") == 20)

    -- Ring into an empty slot.
    local ring
    for _, it in ipairs(party.inventory) do if it.slot == "ring" then ring = it end end
    eq:toggle(ring)
    check("ring equips into empty slot", raul.equipment.ring == ring)
    check("ring left the bag", not invHas(party, ring))
    check("Iron Ring gives +5 physDef", raul:stat("physDef") == 5)

    -- Skill book grants its ability while equipped.
    local tome
    for _, it in ipairs(party.inventory) do if it.slot == "book" then tome = it end end
    eq:toggle(tome)
    check("book equips (bookCount 1)", raul:bookCount() == 1)
    local hasFireball = false
    for _, a in ipairs(raul:abilities()) do if a.id == "fire_ball" then hasFireball = true end end
    check("book grants Fire Ball to ability list", hasFireball)
    check("but Raul still can't cast it (no magic weapon)", not raul:canUseAbility("fire_ball"))

    -- Unequip the ring; it returns to the bag and the bonus drops.
    eq:toggle(ring)
    check("ring unequips back to bag", invHas(party, ring) and raul.equipment.ring == nil)
    check("physDef back to 0", raul:stat("physDef") == 0)

    -- Consumable: use a Health Potion on a wounded Raul.
    raul:damageHP(30)
    check("Raul at 70 HP after damage", raul.hp == 70)
    local potion
    for _, it in ipairs(party.inventory) do if it.slot == "consumable" then potion = it end end
    local potionsBefore = #party:itemsOfSlot("consumable")

    local item = ItemScreen.new()
    item:openCategory({ text = "Consumable", slot = "consumable" })
    item:useItem(potion)
    item:applyTo(raul)
    check("potion healed Raul to 100", raul.hp == 100)
    check("one potion consumed", #party:itemsOfSlot("consumable") == potionsBefore - 1)

    line()
    line(fails == 0 and "RESULT: ALL CHECKS PASSED" or ("RESULT: " .. fails .. " FAILED"))

    local text = table.concat(out, "\n")
    print(text)
    love.filesystem.write("flowtest.log", text)
end

return M
