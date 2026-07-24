-- battle/battle.lua
-- The encounter controller. Owns the units, the action-value scheduler, the
-- effect list + event bus, the message log, and all resolution rules.
--
-- Turn flow (driven by the encounter screen, one step per "message queue empty"):
--   beginTurn() -> "input" | "enemy" | "resolved" | "over"
--       fires turnStart (Aflame etc.), clears the actor's guard, handles stun /
--       insanity / a charged Aimed Shot. "input" = wait for player command;
--       "enemy" = call aiTurn(); "resolved" = the turn already resolved or was
--       skipped; "over" = no actor / battle ended.
--   performAction(actor, ability, target)  -- player or AI chosen action
--   endTurn(actor)                         -- turnEnd + advance scheduler + check over
--
-- The event bus (emit) drains in staggered passes so effects that react by
-- emitting further events can't recurse forever.

local Scheduler = require("src.game.battle.scheduler")
local effects   = require("src.game.battle.effects")
local ai        = require("src.game.battle.ai")
local roll      = require("src.game.roll")
local stats     = require("src.game.stats")

local Battle = {}
Battle.__index = Battle

local MAX_PASSES = 12

local HIT_KEY = { melee = "meleeHit", ranged = "rangedHit", magic = "magicHit" }

local function fmt(s, caster, target)
    s = s:gsub("{caster}", caster and caster.name or "")
    s = s:gsub("{target}", target and target.name or "")
    return s
end

----------------------------------------------------------------- construction
function Battle.new(heroes, enemies)
    local self = setmetatable({}, Battle)
    self.heroes, self.enemies = heroes, enemies
    self.units = {}
    for _, u in ipairs(heroes) do u.side = "hero"; self.units[#self.units + 1] = u end
    for _, u in ipairs(enemies) do u.side = "enemy"; self.units[#self.units + 1] = u end

    for _, u in ipairs(self.units) do
        u.guarding = false
        u.shieldRaised = false
        u.stun = 0
        u.charge = nil
        u.deathProcessed = not u.alive
        u.insaneProcessed = u.insane or false
        u.growth = { maxHP = 0, maxMP = 0, dodge = 0, block = 0,
                     meleeHit = 0, rangedHit = 0, magicHit = 0 }
    end

    self.effects = {}
    self.pending = {}          -- event queue
    self.draining = false
    self.logq = {}             -- message strings awaiting display
    self.over = false
    self.result = nil          -- "victory" | "defeat" | "draw"
    self.noProgress = 0        -- turns since the last HP damage (stalemate guard)
    self.frontDissolved = { hero = false, enemy = false }
    self.current = nil
    self.scheduler = Scheduler.new(self.units)
    return self
end

----------------------------------------------------------------- side helpers
function Battle:sideUnits(side) return side == "hero" and self.heroes or self.enemies end
function Battle:opposite(side) return side == "hero" and "enemy" or "hero" end

function Battle:livingAllies(u)
    local out = {}
    for _, a in ipairs(self:sideUnits(u.side)) do if a.alive then out[#out + 1] = a end end
    return out
end

function Battle:livingEnemiesOf(u)
    local out = {}
    for _, a in ipairs(self:sideUnits(self:opposite(u.side))) do if a.alive then out[#out + 1] = a end end
    return out
end

----------------------------------------------------------------- messages / log
function Battle:log(msg) self.logq[#self.logq + 1] = msg end
function Battle:hasMessages() return #self.logq > 0 end
function Battle:takeMessages()
    local q = self.logq
    self.logq = {}
    return q
end

----------------------------------------------------------------- event bus
function Battle:emit(type, data)
    data = data or {}
    data.type = type
    self.pending[#self.pending + 1] = data
    if self.draining then return end

    self.draining = true
    local passes = 0
    while #self.pending > 0 and passes < MAX_PASSES do
        local batch = self.pending
        self.pending = {}
        for _, ev in ipairs(batch) do
            for _, eff in ipairs(self.effects) do
                if eff.on then eff:on(ev, self) end
            end
        end
        passes = passes + 1
    end
    self.draining = false

    -- Reap expired effects.
    local kept = {}
    for _, eff in ipairs(self.effects) do
        if not eff.dead then kept[#kept + 1] = eff end
    end
    self.effects = kept
end

----------------------------------------------------------------- formation
function Battle:hasLivingFront(side)
    for _, u in ipairs(self:sideUnits(side)) do
        if u.alive and u.row == "front" then return true end
    end
    return false
end

-- A back-row unit only counts as "back" while its side still has a living front.
function Battle:effectiveRow(u)
    if u.row == "back" and self:hasLivingFront(u.side) then return "back" end
    return "front"
end

-- Melee hit multiplier: halved per line of separation; ranged/magic ignore it.
function Battle:meleePenalty(attacker, target, ability)
    if ability.weapon ~= "melee" then return 1 end
    local dist = 0
    if self:effectiveRow(attacker) == "back" then dist = dist + 1 end
    if self:effectiveRow(target) == "back" then dist = dist + 1 end
    return 0.5 ^ dist
end

----------------------------------------------------------------- resolution: hit
-- Returns outcome ("hit"|"miss"|"dodge"|"block") and the hit probability.
function Battle:resolveHit(attacker, target, ability)
    if ability.target == "ally" or ability.target == "allAllies" or ability.target == "self" then
        return "hit", 1
    end
    local hitKey = HIT_KEY[ability.weapon]
    local hitRating = hitKey and attacker:stat(hitKey) or 0
    hitRating = hitRating + (ability.hitBonus and ability.hitBonus * 100 or 0)

    local penalty = self:meleePenalty(attacker, target, ability)
    local hitW = math.max(0, (70 + hitRating) * penalty)
    local missW = 30
    local dodgeW = target:stat("dodge")
    local blockW = 0
    if target:hasShield() then blockW = target:stat("block") end
    if target.shieldRaised then blockW = blockW + 45 end -- +30 raise, +15 passive

    local total = hitW + missW + dodgeW + blockW
    local r = love.math.random() * total
    local outcome
    if r < hitW then outcome = "hit"
    elseif r < hitW + missW then outcome = "miss"
    elseif r < hitW + missW + dodgeW then outcome = "dodge"
    else outcome = "block" end
    return outcome, (total > 0 and hitW / total or 0)
end

function Battle:rollCrit(attacker, ability)
    local chance
    if ability.critChance then
        chance = ability.critChance
    else
        chance = attacker:stat("crit") / 100 + (ability.critBonus or 0)
    end
    return love.math.random() < chance
end

function Battle:computeDamage(attacker, target, ability, crit)
    local base = attacker:stat(ability.power.rating) * (ability.power.scale or 1)
    local raw = roll.around(base)
    local defKey = (ability.damages == "mp") and "mentalDef" or "physDef"
    local dmg = raw - target:stat(defKey)
    if dmg < 1 then dmg = 1 end
    if crit then dmg = dmg * 2 end
    if target.guarding then dmg = dmg * 0.5 end
    if target.shieldRaised then dmg = dmg * 0.5 end
    dmg = math.floor(dmg + 0.5)
    return math.max(1, dmg)
end

----------------------------------------------------------------- resource change
function Battle:trackLoss(u, resource, lost, pctAfter)
    if u.side ~= "hero" or lost <= 0 then return end
    local key = (resource == "mp") and "maxMP" or "maxHP"
    u.growth[key] = u.growth[key] + (lost / 5) * (1 - pctAfter)
end

function Battle:loseHP(u, amount, opts)
    opts = opts or {}
    amount = math.floor(amount + 0.5)
    if amount <= 0 then return 0 end
    local maxv = u:maxHP()
    local before = u.hp
    u:damageHP(amount)
    local lost = before - u.hp
    if lost > 0 then self.noProgress = 0 end -- any HP loss counts as progress
    self:trackLoss(u, "hp", lost, maxv > 0 and u.hp / maxv or 0)
    if not opts.silent then self:log(u.name .. " took " .. lost .. " damage!") end
    self:emit("hpLoss", { unit = u, amount = lost, source = opts.source, cost = opts.cost })
    if not u.alive then self:onDeath(u) end
    return lost
end

function Battle:loseMP(u, amount, opts)
    opts = opts or {}
    if u.mindless then return 0 end
    amount = math.floor(amount + 0.5)
    if amount <= 0 then return 0 end
    local maxv = u:maxMP()
    local before = u.mp
    u:damageMP(amount)
    local lost = before - u.mp
    self:trackLoss(u, "mp", lost, maxv > 0 and u.mp / maxv or 0)
    self:emit("mpLoss", { unit = u, amount = lost, source = opts.source, cost = opts.cost })
    if u.insane then self:onInsane(u) end
    return lost
end

function Battle:dealDamage(source, target, amount, damageType, crit, ability)
    if not target.alive then return 0 end
    local lost
    if damageType == "mp" then
        lost = self:loseMP(target, amount, { source = source })
    else
        lost = self:loseHP(target, amount, { source = source })
    end
    self:emit("damage", { source = source, target = target, amount = lost,
                          damageType = damageType, crit = crit, ability = ability })
    return lost
end

----------------------------------------------------------------- death / insanity
function Battle:onDeath(u)
    if u.deathProcessed then return end
    u.deathProcessed = true
    self:log(u.name .. " is slain!")
    self:emit("died", { unit = u })
    self:allyResourceDrain(u)
    self:checkFrontlineDissolve(u.side)
end

function Battle:onInsane(u)
    if u.insaneProcessed then return end
    u.insaneProcessed = true
    self:log(u.name .. " goes insane!")
    self:emit("insane", { unit = u })
    self:allyResourceDrain(u)
end

-- "If an ally dies or goes insane, their allies lose half of their MP."
function Battle:allyResourceDrain(u)
    for _, a in ipairs(self:sideUnits(u.side)) do
        if a ~= u and a.alive and not a.mindless and a.mp > 0 then
            local half = math.floor(a.mp / 2)
            if half > 0 then
                self:log(a.name .. " loses " .. half .. " MP!")
                self:loseMP(a, half, { silent = true })
            end
        end
    end
end

function Battle:checkFrontlineDissolve(side)
    if self:hasLivingFront(side) or self.frontDissolved[side] then return end
    local anyBack = false
    for _, u in ipairs(self:sideUnits(side)) do
        if u.alive and u.row == "back" then anyBack = true end
    end
    if anyBack then
        self.frontDissolved[side] = true
        self:log("The " .. (side == "hero" and "ally" or "enemy") .. " frontline has dissolved!")
    end
end

----------------------------------------------------------------- stun
function Battle:applyStun(u, level, chance, source)
    if u.unstoppable or not u.alive then return end
    local p = chance - u:stat("stunResist") / 100
    if love.math.random() < p then
        if level > (u.stun or 0) then u.stun = level end -- superseded only by higher
        self:log(u.name .. " is stunned!")
        self:emit("stun", { unit = u, level = level, source = source })
    end
end

----------------------------------------------------------------- growth tracking
function Battle:trackHitGrowth(attacker, ability, outcome)
    if attacker.side ~= "hero" then return end
    local key = HIT_KEY[ability.weapon]
    if not key then return end
    if outcome == "hit" then attacker.growth[key] = attacker.growth[key] + 1
    elseif outcome == "miss" then attacker.growth[key] = attacker.growth[key] + 2 end
end

function Battle:trackDefendGrowth(target, outcome)
    if target.side ~= "hero" then return end
    if outcome == "hit" then target.growth.dodge = target.growth.dodge + 1
    elseif outcome == "dodge" then target.growth.dodge = target.growth.dodge + 2
    elseif outcome == "block" and target:hasShield() then target.growth.block = target.growth.block + 2 end
end

----------------------------------------------------------------- affordability
function Battle:canAfford(u, def)
    local c = def.cost or {}
    if c.hp and u.hp <= c.hp then return false end
    if c.mp and u.mp < c.mp then return false end
    if c.mpPercent and u.mp <= 0 then return false end
    return true
end

-- Reason string for a failed affordability check ("Not enough HP" / "...MP").
function Battle:affordError(u, def)
    local c = def.cost or {}
    if c.hp and u.hp <= c.hp then return "Not enough HP" end
    if (c.mp and u.mp < c.mp) or (c.mpPercent and u.mp <= 0) then return "Not enough MP" end
    return nil
end

function Battle:spendCost(u, def)
    local c = def.cost or {}
    if c.hp then self:loseHP(u, c.hp, { silent = true, cost = true }) end
    if c.mp then self:loseMP(u, c.mp, { silent = true, cost = true }) end
    if c.mpPercent then self:loseMP(u, math.floor(u.mp * c.mpPercent), { silent = true, cost = true }) end
end

----------------------------------------------------------------- actions
-- Player/AI entry point. `target` is a single unit (offensive/heal-single) or nil
-- (self / mass abilities).
function Battle:performAction(actor, ability, target)
    self:spendCost(actor, ability)

    if ability.charge then
        actor.charge = { ability = ability, target = target }
        if ability.msgCharge then self:log(fmt(ability.msgCharge, actor, target)) end
        return
    end

    if ability.msg then self:log(fmt(ability.msg, actor, target)) end

    if ability.heal then
        self:resolveHeal(actor, ability, target)
    elseif ability.revive then
        self:resolveRevive(actor, ability, target)
    elseif ability.power then
        self:resolveAttack(actor, ability, target)
    elseif ability.effects then
        self:applyAbilityEffects(actor, actor, ability, 1, 0)
    end

    self:emit("action", { unit = actor, ability = ability, target = target })
end

function Battle:resolveAttack(actor, ability, target)
    if not target or not target.alive then return end
    local outcome, hitP = self:resolveHit(actor, target, ability)
    self:trackHitGrowth(actor, ability, outcome)
    self:trackDefendGrowth(target, outcome)

    if outcome == "miss" then
        self:log(actor.name .. " misses!")
        return
    elseif outcome == "dodge" then
        self:log(target.name .. " dodged the attack!")
        return
    elseif outcome == "block" then
        self:log(target.name .. " blocked the attack!")
        return
    end

    local crit = self:rollCrit(actor, ability)
    local dmg = self:computeDamage(actor, target, ability, crit)
    if crit then self:log("It was critical!") end
    local dealt = self:dealDamage(actor, target, dmg, ability.damages or "hp", crit, ability)
    if crit then self:applyStun(target, 1, 1.0, actor) end
    if ability.effects and target.alive then
        self:applyAbilityEffects(actor, target, ability, hitP, dealt)
    end
end

function Battle:applyAbilityEffects(source, target, ability, hitRate, amount)
    for _, e in ipairs(ability.effects) do
        local chance = (e.chance == "hitRate") and hitRate or (e.chance or 1)
        if love.math.random() < chance then
            effects.apply(self, e.id, { owner = target, source = source, ability = ability, amount = amount })
        end
    end
end

function Battle:resolveHeal(actor, ability, target)
    local amount, res = ability.heal.amount, ability.heal.resource
    local targets
    if ability.target == "allAllies" then
        targets = self:livingAllies(actor)
    else
        targets = { target }
    end
    for _, t in ipairs(targets) do
        if t and t.alive then
            if res == "mp" then t:healMP(amount) else t:healHP(amount) end
            self:log(string.format("%s recovers %d %s.", t.name, amount, string.upper(res)))
            self:emit("heal", { source = actor, target = t, amount = amount, resource = res })
        end
    end
end

function Battle:resolveRevive(actor, ability, target)
    if not target or target.alive then return end
    target.alive = true
    target.deathProcessed = false
    target.insane = false
    target.insaneProcessed = false
    target.hp = math.max(1, math.floor(target:maxHP() * ability.revive.hp))
    target.mp = math.floor(target:maxMP() * ability.revive.mp)
    self.scheduler:reroll(target)
    self:emit("revived", { unit = target, source = actor })
    -- (Random debuff-on-revive is applied at rest; kept out of battle for now.)
end

----------------------------------------------------------------- turn stepping
function Battle:beginTurn()
    if self.over then return "over" end
    local actor = self.scheduler:next()
    self.current = actor
    if not actor then self.over = true; return "over" end

    -- turnStart: Aflame and other pre-turn effects fire here.
    self:emit("turnStart", { unit = actor })
    if not actor.alive then return "resolved" end

    actor.guarding = false -- guard lasted until the start of this, the actor's turn

    if actor.stun and actor.stun > 0 then
        actor.stun = actor.stun - 1
        actor.charge = nil
        self:log(actor.name .. " cannot act!")
        return "resolved"
    end

    if actor.insane then
        actor.charge = nil
        self:log(actor.name .. " is lost to madness!")
        return "resolved"
    end

    if actor.charge then
        local ch = actor.charge
        actor.charge = nil
        local tgt = ch.target
        if not (tgt and tgt.alive) then tgt = self:livingEnemiesOf(actor)[1] end
        if tgt then
            if ch.ability.msg then self:log(fmt(ch.ability.msg, actor, tgt)) end
            self:resolveAttack(actor, ch.ability, tgt)
        end
        return "resolved"
    end

    return actor.side == "hero" and "input" or "enemy"
end

function Battle:aiTurn(actor)
    local def, target = ai.chooseAction(self, actor)
    if def then
        self:performAction(actor, def, target)
    else
        self:log(actor.name .. " hesitates.")
    end
end

-- GUARD command.
function Battle:guard(actor)
    actor.guarding = true
    self:log(actor.name .. " guards!")
end

-- MOVE command (does not end the turn).
function Battle:move(actor)
    actor.row = (actor.row == "front") and "back" or "front"
    self:log(actor.name .. " moves to the " .. actor.row .. "!")
end

-- If neither side can damage the other (all resource-starved / insane), the
-- fight can't resolve; break the stalemate after this many damage-free turns.
local STALL_LIMIT = 40

function Battle:endTurn(actor)
    self:emit("turnEnd", { unit = actor })
    self.scheduler:advance(actor)
    self.noProgress = self.noProgress + 1
    self:checkOver()
end

function Battle:checkOver()
    local heroesAlive, enemiesAlive = false, false
    for _, u in ipairs(self.heroes) do if u.alive then heroesAlive = true end end
    for _, u in ipairs(self.enemies) do if u.alive then enemiesAlive = true end end
    if not enemiesAlive then
        self.over, self.result = true, "victory"
    elseif not heroesAlive then
        self.over, self.result = true, "defeat"
    elseif self.noProgress >= STALL_LIMIT then
        self.over, self.result = true, "draw"
    end
end

----------------------------------------------------------------- leveling
-- Apply accrued growth to the heroes' base stats. Returns a list of report lines.
function Battle:applyLeveling()
    local reports = {}
    local order = {
        { "maxHP", "Max HP" }, { "maxMP", "Max MP" }, { "dodge", "Dodge" },
        { "block", "Block" }, { "meleeHit", "Melee Hit" },
        { "rangedHit", "Ranged Hit" }, { "magicHit", "Magic Hit" },
    }
    for _, u in ipairs(self.heroes) do
        local gains = {}
        for _, pair in ipairs(order) do
            local key, label = pair[1], pair[2]
            local amount = math.floor(u.growth[key] or 0)
            if amount > 0 then
                u.base[key] = (u.base[key] or 0) + amount
                gains[#gains + 1] = string.format("+%d %s", amount, label)
            end
        end
        if #gains > 0 then
            reports[#reports + 1] = u.name .. " gains " .. table.concat(gains, ", ") .. "!"
        end
    end
    return reports
end

return Battle
