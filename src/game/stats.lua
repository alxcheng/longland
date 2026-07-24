-- stats.lua
-- The canonical unit stat block and defaults, straight from the design doc.
-- `physical/ranged/magic` are the P/R/M ratings (base value for that ability
-- family); a unit's equipped weapon adds its ATK to the matching rating.
-- Hit / dodge / block / crit / stun-resist are percentage-ish ratings; the
-- default 30% miss / 70% hit baseline lives in the (future) combat resolver, so
-- these all start at 0 and grow through play.

local stats = {}

-- Ordered so screens/reports can iterate in a sensible display order.
stats.list = {
    { key = "maxHP",      label = "Max HP",       default = 100, rolled = false },
    { key = "maxMP",      label = "Max MP",       default = 100, rolled = false },
    { key = "speed",      label = "Speed",        default = 50,  rolled = true  }, -- via 1000/speed AV
    { key = "physical",   label = "Physical",     default = 0,   rolled = true  },
    { key = "ranged",     label = "Ranged",       default = 0,   rolled = true  },
    { key = "magic",      label = "Magic",        default = 0,   rolled = true  },
    { key = "meleeHit",   label = "Melee Hit",    default = 0,   rolled = false },
    { key = "rangedHit",  label = "Ranged Hit",   default = 0,   rolled = false },
    { key = "magicHit",   label = "Magic Hit",    default = 0,   rolled = false },
    { key = "dodge",      label = "Dodge",        default = 0,   rolled = false },
    { key = "block",      label = "Block",        default = 0,   rolled = false },
    { key = "crit",       label = "Crit",         default = 0,   rolled = false },
    { key = "stunResist", label = "Stun Resist",  default = 0,   rolled = false },
    { key = "physDef",    label = "Physical Def", default = 0,   rolled = false },
    { key = "mentalDef",  label = "Mental Def",   default = 0,   rolled = false },
    { key = "threat",     label = "Threat",       default = 100, rolled = false },
}

stats.default = {}
stats.label = {}
for _, s in ipairs(stats.list) do
    stats.default[s.key] = s.default
    stats.label[s.key] = s.label
end

-- Which base rating a weapon's ATK feeds, by weapon type.
stats.weaponRating = {
    melee = "physical",
    ranged = "ranged",
    magic = "magic",
}

return stats
