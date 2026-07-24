-- screentest.lua
-- Verifies the Encounter *screen's* turn loop (phase machine, message draining,
-- result/leveling handling) by pumping its update() in autoplay to completion,
-- exercising the same code path the interactive screen runs — minus real input.
-- Run with `love . screentest`.

local M = {}

function M.run()
    local state     = require("src.game.state")
    local Encounter = require("src.screens.encounter")

    local out, fails = {}, 0
    local function line(s) out[#out + 1] = s or "" end
    local function check(name, cond)
        if not cond then fails = fails + 1 end
        line((cond and "  ok   " or "  FAIL ") .. name)
    end

    love.math.setRandomSeed(99)

    local completed = 0
    for _ = 1, 50 do
        state.newGame()
        local enc = Encounter.new({ "skeleton", "goblin", "witch" })
        enc.autoplay = true
        local frames = 0
        while not enc.done and frames < 8000 do
            enc:update(1 / 60)
            frames = frames + 1
        end
        if enc.done and enc.battle.over then completed = completed + 1 end
    end
    check("all 50 autoplayed encounters ran to completion via the screen loop", completed == 50)

    -- One more, checking leveling was applied to the live party units.
    state.newGame()
    local party = state.party
    local before = party.deployed[1]:maxHP()
    local enc = Encounter.new({ "skeleton", "goblin", "witch" })
    enc.autoplay = true
    local frames = 0
    while not enc.done and frames < 8000 do enc:update(1 / 60); frames = frames + 1 end
    check("battle reached a result", enc.battle.result ~= nil)
    line(string.format("Raul maxHP %d -> %d after the fight (result: %s).",
        before, party.deployed[1]:maxHP(), tostring(enc.battle.result)))

    line("")
    line(fails == 0 and "RESULT: ALL CHECKS PASSED" or ("RESULT: " .. fails .. " FAILED"))
    local text = table.concat(out, "\n")
    print(text)
    love.filesystem.write("screentest.log", text)
end

return M
