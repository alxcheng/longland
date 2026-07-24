-- content/abilities.lua
-- Ability definitions as pure data. The battle resolver (later phase) reads these
-- fields to actually roll damage, check hit/crit, spend resources, and apply
-- effects. Message templates use {caster} and {target} placeholders.
--
-- Schema:
--   name       display name
--   target     "enemy" | "ally" | "self" | "allEnemies" | "allAllies"
--   weapon     required weapon type to use it ("melee"/"ranged"/"magic"), or nil.
--              Innate abilities on weaponless units (enemies) bypass this.
--   cost       { hp=n } | { mp=n } | { mpPercent=0..1 }
--   power      { rating="physical"/"ranged"/"magic", scale=1 }  -- damage base (rolled)
--   damages    "hp" (physical/body, reduced by physDef) | "mp" (mental, reduced by mentalDef)
--   heal       { resource="hp"/"mp", amount=n }
--   critBonus  additive crit chance for this ability
--   critChance flat crit chance override (Aimed Shot)
--   hitBonus   additive hit chance for this ability
--   effects    list of { id=..., chance="hitRate"|number } applied on hit
--   charge     true = spends this turn, fires next turn (Aimed Shot)
--   revive     revive descriptor
--   msg        cast message; msgCharge = wind-up message for charged abilities
--   desc       description text (shown by the q-describe popup)

return {
    swing = {
        name = "Swing", target = "enemy", weapon = "melee",
        cost = { hp = 5 },
        power = { rating = "physical", scale = 1 }, damages = "hp",
        msg = "{caster} swings at {target}!",
        desc = "A basic melee strike. Deals physical damage to one enemy. Costs 5 HP.",
    },

    crushing_blow = {
        name = "Crushing Blow", target = "enemy", weapon = "melee",
        cost = { hp = 8 },
        power = { rating = "physical", scale = 1 }, damages = "hp",
        critBonus = 0.30,
        msg = "{caster} delivers a crushing blow to {target}!",
        desc = "A heavy melee strike with +30% chance to crit. Costs 8 HP.",
    },

    shoot = {
        name = "Shoot", target = "enemy", weapon = "ranged",
        cost = { hp = 3 },
        power = { rating = "ranged", scale = 1 }, damages = "hp",
        msg = "{caster} shoots an arrow at {target}!",
        desc = "A ranged attack. Deals ranged physical damage to one enemy. Costs 3 HP.",
    },

    aimed_shot = {
        name = "Aimed Shot", target = "enemy", weapon = "ranged",
        cost = { hp = 3 },
        power = { rating = "ranged", scale = 1 }, damages = "hp",
        charge = true, critChance = 0.60, hitBonus = 0.30,
        msgCharge = "{caster} carefully aims!",
        msg = "{caster} fires an aimed shot at {target}!",
        desc = "Spends this turn aiming; the next turn fires automatically with " ..
               "60% crit and +30% hit. If the unit cannot act next turn, it is cancelled. Costs 3 HP.",
    },

    fire_ball = {
        name = "Fire Ball", target = "enemy", weapon = "magic",
        cost = { mp = 20 },
        power = { rating = "magic", scale = 1 }, damages = "hp",
        -- Applied with probability equal to this hit's success chance ("hitRate").
        effects = { { id = "aflame", chance = "hitRate" } },
        msg = "{caster} throws a fire ball at {target}!",
        desc = "A magic attack dealing damage to one enemy, with a chance to set it " ..
               "Aflame (burns before its turn for half the damage). Costs 20 MP.",
    },

    heal = {
        name = "Heal", target = "ally",
        cost = { mp = 10 },
        heal = { resource = "hp", amount = 20 },
        msg = "{caster} heals {target}.",
        desc = "Restore 20 HP to one ally. Costs 10 MP.",
    },

    greater_heal = {
        name = "Greater Heal", target = "allAllies",
        cost = { mp = 30 },
        heal = { resource = "hp", amount = 20 },
        msg = "{caster} calls down a greater heal!",
        desc = "Restore 20 HP to all allies. Costs 30 MP (three times Heal).",
    },

    revive = {
        name = "Revive", target = "ally",
        cost = { mpPercent = 0.90 },
        revive = { hp = 0.5, mp = 0.5, debuffFloor = 0.75 },
        msg = "{caster} revives {target}, but at what cost?",
        desc = "Revive a fallen ally at 50% HP/MP. Their stats are randomly debuffed " ..
               "(never below 75% of original). Costs 90% of current MP.",
    },

    raise_shield = {
        name = "Raise Shield", target = "self", requiresShield = true,
        cost = {},
        effects = { { id = "raised_shield" } }, -- block +30%, passive 15% block, 50% dmg reduction until next turn
        msg = "{caster} raises their shield!",
        desc = "Until your next turn: block rating +30%, a passive 15% block, and 50% " ..
               "damage reduction. Requires a shield.",
    },
}
