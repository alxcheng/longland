-- battle/ai.lua
-- Enemy decision tree (also used to auto-drive heroes in the headless battle test):
--   * If a support skill is available AND an ally needs healing, 50/50 between
--     supporting and attacking.
--   * Support: pick mass vs single at random (when both exist); single targets the
--     lowest-HP ally.
--   * Attack: target chosen by threat weight, with back-row units at 25% threat.
-- Returns (abilityDef, targetUnit) or nil to pass.

local ai = {}

local function affordableUsable(battle, actor)
    local list = {}
    for _, a in ipairs(actor:abilities()) do
        if actor:canUseAbility(a.id) and battle:canAfford(actor, a.def) then
            list[#list + 1] = a.def
        end
    end
    return list
end

function ai.chooseTarget(battle, actor)
    local foes = battle:livingEnemiesOf(actor)
    if #foes == 0 then return nil end
    local weights, total = {}, 0
    for i, f in ipairs(foes) do
        local w = f:stat("threat")
        if battle:effectiveRow(f) == "back" then w = w * 0.25 end
        weights[i], total = w, total + w
    end
    if total <= 0 then return foes[love.math.random(#foes)] end
    local r = love.math.random() * total
    for i, f in ipairs(foes) do
        r = r - weights[i]
        if r <= 0 then return f end
    end
    return foes[#foes]
end

function ai.chooseAction(battle, actor)
    local usable = affordableUsable(battle, actor)
    local offense, support = {}, {}
    for _, def in ipairs(usable) do
        if def.heal then support[#support + 1] = def
        elseif def.power then offense[#offense + 1] = def end
    end

    local allies = battle:livingAllies(actor)
    local needHeal, lowest = false, nil
    for _, al in ipairs(allies) do
        if al.hp < al:maxHP() then needHeal = true end
        if not lowest or al.hp < lowest.hp then lowest = al end
    end

    if #support > 0 and needHeal and love.math.random() < 0.5 then
        local mass, single = {}, {}
        for _, def in ipairs(support) do
            if def.target == "allAllies" then mass[#mass + 1] = def else single[#single + 1] = def end
        end
        local pick
        if #mass > 0 and #single > 0 then
            pick = (love.math.random() < 0.5) and mass[love.math.random(#mass)] or single[love.math.random(#single)]
        elseif #mass > 0 then pick = mass[love.math.random(#mass)]
        else pick = single[love.math.random(#single)] end

        if pick.target == "allAllies" then return pick, nil end
        return pick, lowest
    end

    if #offense > 0 then
        return offense[love.math.random(#offense)], ai.chooseTarget(battle, actor)
    end
    return nil, nil
end

return ai
