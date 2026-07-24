-- battle/scheduler.lua
-- Action-value turn order. Each unit's AV starts at a rolled 1000/speed; the
-- lowest AV acts next (ties broken randomly). After an actor's turn, everyone's
-- AV drops by the actor's AV (so the actor hits 0) and the actor re-rolls a fresh
-- 1000/speed. Dead units are skipped by the caller-supplied liveness of u.alive.

local roll = require("src.game.roll")

local Scheduler = {}
Scheduler.__index = Scheduler

function Scheduler.new(units)
    local self = setmetatable({}, Scheduler)
    self.units = units
    for _, u in ipairs(units) do
        u.av = roll.actionValue(u:stat("speed"))
    end
    return self
end

-- The living unit with the lowest AV (random among ties), or nil.
function Scheduler:next()
    local best, tied = math.huge, {}
    for _, u in ipairs(self.units) do
        if u.alive then
            if u.av < best - 1e-9 then
                best, tied = u.av, { u }
            elseif math.abs(u.av - best) <= 1e-9 then
                tied[#tied + 1] = u
            end
        end
    end
    if #tied == 0 then return nil end
    return tied[love.math.random(#tied)]
end

-- Advance time by the actor's AV, then re-roll the actor's AV (if still alive).
function Scheduler:advance(actor)
    local actorAV = actor.av
    for _, u in ipairs(self.units) do
        if u.alive then u.av = u.av - actorAV end
    end
    if actor.alive then
        actor.av = roll.actionValue(actor:stat("speed"))
    end
end

-- Give a (re)joined unit a fresh AV, e.g. after a revive.
function Scheduler:reroll(unit)
    unit.av = roll.actionValue(unit:stat("speed"))
end

return Scheduler
