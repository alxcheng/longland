-- report.lua
-- Formats a unit into a human-readable stat sheet. Used by the headless data test
-- now, and intended for reuse by the STATS screen later.

local stats = require("src.game.stats")

local report = {}

function report.unitSheet(u)
    local lines = {}
    local function add(s) lines[#lines + 1] = s end

    add(string.format("%s  [%s / %s]", u.name, u.side, u.row))
    add(string.format("  HP %s   MP %s%s", u:hpString(), u:mpString(),
        u.mindless and "  (Mindless)" or ""))

    -- Ratings block (skip the two resources already shown above).
    local parts = {}
    for _, s in ipairs(stats.list) do
        if s.key ~= "maxHP" and s.key ~= "maxMP" then
            parts[#parts + 1] = string.format("%s %d", s.label, u:stat(s.key))
        end
    end
    add("  " .. table.concat(parts, "   "))

    local abil = {}
    for _, a in ipairs(u:abilities()) do abil[#abil + 1] = a.def.name end
    add("  Abilities: " .. (next(abil) and table.concat(abil, ", ") or "(none)"))

    return table.concat(lines, "\n")
end

-- A flat list of "Label  value" strings for every stat, for a detailed screen.
function report.statLines(u)
    local lines = {}
    for _, s in ipairs(stats.list) do
        if s.key == "maxHP" then
            lines[#lines + 1] = string.format("HP        %s", u:hpString())
        elseif s.key == "maxMP" then
            lines[#lines + 1] = string.format("MP        %s", u:mpString())
        else
            lines[#lines + 1] = string.format("%-11s %d", s.label, u:stat(s.key))
        end
    end
    return lines
end

-- Names of currently-usable abilities.
function report.abilityNames(u)
    local names = {}
    for _, a in ipairs(u:abilities()) do names[#names + 1] = a.def.name end
    return names
end

return report
