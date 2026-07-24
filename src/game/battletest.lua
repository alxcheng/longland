-- battletest.lua
-- Headless engine verification: runs full auto-battles (AI drives BOTH sides) to
-- completion. Runs many battles to surface crashes / non-termination across RNG,
-- then replays one verbose battle to eyeball the message flow. Also checks the
-- action-value ordering and leveling application.
-- Run with `love . battletest`; output goes to battletest.log in the save dir.

local db     = require("src.game.db")
local Battle = require("src.game.battle.battle")

local M = {}

local TURN_CAP = 500

-- Drive one battle to the end. `sink` (optional) receives each message string.
local function runBattle(sink)
    local party = db.startingParty()
    local heroes = {}
    for _, u in ipairs(party.deployed) do heroes[#heroes + 1] = u end
    local enemies = db.makeGroup({ "skeleton", "goblin", "witch" })

    local battle = Battle.new(heroes, enemies)
    local turns = 0
    while not battle.over and turns < TURN_CAP do
        turns = turns + 1
        local status = battle:beginTurn()
        if status == "over" then break end
        local actor = battle.current
        if status == "input" or status == "enemy" then
            battle:aiTurn(actor)
        end
        battle:endTurn(actor)
        if sink then
            for _, m in ipairs(battle:takeMessages()) do sink(m) end
        else
            battle:takeMessages()
        end
    end
    return battle, turns
end

function M.run()
    local out = {}
    local function line(s) out[#out + 1] = s or "" end
    local fails = 0
    local function check(name, cond)
        if not cond then fails = fails + 1 end
        line((cond and "  ok   " or "  FAIL ") .. name)
    end

    love.math.setRandomSeed(1234)

    -- Stress: many battles must all terminate cleanly with a valid result.
    local N = 300
    local wins, losses, draws, maxTurns, allValid, allBounded = 0, 0, 0, 0, true, true
    for _ = 1, N do
        local battle, turns = runBattle(nil)
        if turns >= TURN_CAP then allBounded = false end
        if battle.result == "victory" then wins = wins + 1
        elseif battle.result == "defeat" then losses = losses + 1
        elseif battle.result == "draw" then draws = draws + 1
        else allValid = false end
        if turns > maxTurns then maxTurns = turns end
    end
    line(string.format("Ran %d battles: %d wins, %d losses, %d draws, longest %d turns.",
        N, wins, losses, draws, maxTurns))
    check("all battles terminated within the turn cap", allBounded)
    check("all battles ended with a valid result", allValid)
    check("the party wins the majority vs starter enemies", wins > N / 2)

    -- Action-value ordering: on a fresh field the fastest unit (Goblin, spd 70)
    -- should tend to have the lowest AV. Check the very first actor over samples.
    local goblinFirst = 0
    for _ = 1, 200 do
        local party = db.startingParty()
        local heroes = {} for _, u in ipairs(party.deployed) do heroes[#heroes + 1] = u end
        local battle = Battle.new(heroes, db.makeGroup({ "skeleton", "goblin", "witch" }))
        local first = battle.scheduler:next()
        if first and first.name == "Goblin" then goblinFirst = goblinFirst + 1 end
    end
    line(string.format("Goblin (fastest) acted first in %d/200 fresh fields.", goblinFirst))
    check("fastest unit usually goes first (>40%)", goblinFirst > 80)

    -- Leveling: after a battle, applying growth must not error and should yield
    -- some HP growth for heroes who spent HP on abilities.
    local battle = runBattle(nil)
    local reports = battle:applyLeveling()
    line(string.format("Leveling produced %d hero report line(s).", #reports))
    check("applyLeveling returns a table", type(reports) == "table")

    -- Verbose replay of a single battle.
    line("")
    line("=== SAMPLE BATTLE ===")
    love.math.setRandomSeed(7)
    local sample = runBattle(function(m) line("  " .. m) end)
    line("--> " .. tostring(sample.result))

    line("")
    line(fails == 0 and "RESULT: ALL CHECKS PASSED" or ("RESULT: " .. fails .. " FAILED"))

    local text = table.concat(out, "\n")
    print(text)
    love.filesystem.write("battletest.log", text)
end

return M
