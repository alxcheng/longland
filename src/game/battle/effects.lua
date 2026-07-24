-- battle/effects.lua
-- Effects live in the encounter's effect list (battle.effects), NOT on the acting
-- unit. Every emitted event is offered to every effect via effect:on(event, battle)
-- so no interaction is missed; an effect reacts only to the events it cares about.
-- An effect sets self.dead = true to be reaped after the current dispatch.
--
-- `owner` is the unit an effect is visually attached to (for a future status
-- display); it does not gate which events the effect sees.

local effects = {}

effects.defs = {}

-- Aflame: on the burning unit's turnStart, deal half the Fire Ball's damage (50%
-- crit), then expire. Firing before the turn means a crit can stun into the turn.
effects.defs.aflame = function(battle, ctx)
    battle:log(ctx.owner.name .. " was set on fire!")
    return {
        id = "aflame", name = "Aflame", owner = ctx.owner,
        source = ctx.source, ability = ctx.ability,
        stored = math.max(1, math.floor((ctx.amount or 2) / 2)),
        on = function(self, ev, b)
            if self.dead then return end
            if ev.type == "turnStart" and ev.unit == self.owner then
                b:log(self.owner.name .. " is burning!")
                local crit = love.math.random() < 0.5
                local dmg = crit and self.stored * 2 or self.stored
                if crit then b:log("It was critical!") end
                b:dealDamage(self.source, self.owner, dmg, "hp", crit, self.ability)
                if crit then b:applyStun(self.owner, 1, 1.0, self.source) end
                self.dead = true
            end
        end,
    }
end

-- Raised Shield: 50% damage reduction + big block bonus until the owner's next
-- turn. The damage reduction and block bonus are read off owner.shieldRaised in
-- the resolver; this effect just clears the flag when the owner's turn begins.
effects.defs.raised_shield = function(battle, ctx)
    ctx.owner.shieldRaised = true
    return {
        id = "raised_shield", name = "Raised Shield", owner = ctx.owner,
        on = function(self, ev, b)
            if self.dead then return end
            if ev.type == "turnStart" and ev.unit == self.owner then
                self.owner.shieldRaised = false
                self.dead = true
            end
        end,
    }
end

-- Instantiate an effect by id and add it to the battle.
function effects.apply(battle, id, ctx)
    local factory = effects.defs[id]
    if not factory then return end
    local eff = factory(battle, ctx)
    if eff then battle.effects[#battle.effects + 1] = eff end
    return eff
end

return effects
