-- datatest.lua
-- Headless verification of the data model: builds the starting party and an enemy
-- group, prints every stat sheet, and asserts the doc's concrete numbers. Run with
-- `love . datatest`; results go to datatest.log in the LOVE save dir (and stdout).

local db     = require("src.game.db")
local report = require("src.game.report")

local M = {}

function M.run()
    local out = {}
    local function line(s) out[#out + 1] = s or "" end

    line("=== HEROES ===")
    local party = db.startingParty()
    for _, u in ipairs(party.roster) do
        line(report.unitSheet(u))
        line()
    end

    line("=== ENEMIES ===")
    for _, u in ipairs(db.makeGroup({ "skeleton", "goblin", "witch" })) do
        line(report.unitSheet(u))
        line()
    end

    -- Assertions against the spec's concrete content.
    line("=== CHECKS ===")
    local checks = {}
    local function check(name, cond)
        checks[#checks + 1] = (cond and "  ok   " or "  FAIL ") .. name
        return cond
    end

    local heroes = {}
    for _, u in ipairs(party.roster) do heroes[u.name] = u end
    local raul, victor, lya, furgol = heroes.Raul, heroes.Victor, heroes.Lya, heroes.Furgol

    check("Raul physical = 20 (Rusty Sword)", raul:stat("physical") == 20)
    check("Raul has Swing + Raise Shield", #raul:abilities() == 2)
    check("Victor speed = 40 (Mace -10)", victor:stat("speed") == 40)
    check("Victor physical = 30", victor:stat("physical") == 30)
    check("Lya ranged = 15 (Flimsy Bow)", lya:stat("ranged") == 15)
    check("Lya has Shoot + Aimed Shot", #lya:abilities() == 2)
    check("Furgol magic = 20, MP 100/100", furgol:stat("magic") == 20 and furgol:maxMP() == 100)
    check("Party deployed count = 4", party:deployedCount() == 4)

    local skel = db.makeUnit("skeleton")
    check("Skeleton mindless, MP 0/0", skel.mindless and skel:maxMP() == 0 and skel.mp == 0)
    check("Skeleton physical = 20 (innate)", skel:stat("physical") == 20)
    check("Skeleton can use innate Swing w/o weapon", skel:canUseAbility("swing"))
    check("Raul can't use Fire Ball (no magic weapon)", not raul:canUseAbility("fire_ball"))

    local witch = db.makeUnit("witch")
    check("Witch magic = 30, MP 150/150", witch:stat("magic") == 30 and witch:maxMP() == 150)
    check("Witch has 3 abilities", #witch:abilities() == 3)

    -- Deploy cap: a 5th deploy must be refused.
    local extra = party:add(db.makeUnit("raul"))
    check("Deploy past cap is refused", party:toggleDeploy(extra) == false)

    for _, c in ipairs(checks) do line(c) end

    local anyFail = false
    for _, c in ipairs(checks) do if c:find("FAIL") then anyFail = true end end
    line()
    line(anyFail and "RESULT: FAIL" or "RESULT: ALL CHECKS PASSED")

    local text = table.concat(out, "\n")
    print(text)
    love.filesystem.write("datatest.log", text)
end

return M
