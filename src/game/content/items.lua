-- content/items.lua
-- Item / equipment definitions as pure data. Weapons carry an `atk` that is added
-- to the matching P/R/M rating (via stats.weaponRating) while equipped, and
-- `grants` the abilities they unlock. `mods` are flat stat modifiers.
--
-- slot: "weapon" | "shield" | "armor" | "necklace" | "ring" | "book" | "consumable"

return {
    tattered_clothes = {
        name = "Tattered Clothes", slot = "armor",
        mods = {}, grants = {},
        desc = "Threadbare rags. No effect.",
    },

    rusty_sword = {
        name = "Rusty Sword", slot = "weapon", weaponType = "melee", atk = 20,
        grants = { "swing" },
        desc = "A pitted, rust-eaten blade. Grants Swing. +20 Physical.",
    },

    rusty_mace = {
        name = "Rusty Mace", slot = "weapon", weaponType = "melee", atk = 30,
        mods = { speed = -10 },
        grants = { "crushing_blow" },
        desc = "A heavy, corroded mace. Grants Crushing Blow. +30 Physical, -10 Speed.",
    },

    flimsy_bow = {
        name = "Flimsy Bow", slot = "weapon", weaponType = "ranged", atk = 15,
        grants = { "shoot", "aimed_shot" },
        desc = "A warped, half-strung bow. Grants Shoot and Aimed Shot. +15 Ranged.",
    },

    crooked_wand = {
        name = "Crooked Wand", slot = "weapon", weaponType = "magic", atk = 20,
        grants = { "fire_ball", "heal" },
        desc = "A gnarled wand that barely holds a charge. Grants Fire Ball and Heal. +20 Magic.",
    },

    buckler = {
        name = "Buckler", slot = "shield",
        grants = { "raise_shield" },
        desc = "A small round shield. Grants Raise Shield and enables blocking.",
    },

    -- Extra loot so the EQUIP / ITEM screens have something to show.
    iron_ring = {
        name = "Iron Ring", slot = "ring",
        mods = { physDef = 5 },
        desc = "A plain iron band. +5 Physical Def.",
    },
    bone_charm = {
        name = "Bone Charm", slot = "necklace",
        mods = { maxHP = 20 },
        desc = "A charm strung on old bone. +20 Max HP.",
    },
    tome_of_embers = {
        name = "Tome of Embers", slot = "book",
        grants = { "fire_ball" },
        desc = "A scorched grimoire. Grants Fire Ball while equipped.",
    },
    health_potion = {
        name = "Health Potion", slot = "consumable",
        use = { resource = "hp", amount = 30 },
        desc = "A red draught. Restores 30 HP to one ally.",
    },
}
