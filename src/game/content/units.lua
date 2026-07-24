-- content/units.lua
-- Unit templates as pure data. `base` overrides stat defaults (see stats.lua);
-- anything omitted uses the default. `equipment` and `innate` reference item and
-- ability ids. Heroes derive their ratings from equipped weapons; enemies have no
-- equipment, so their ATK is baked straight into a base rating.

return {
    ---------------------------------------------------------------- heroes
    raul = {
        name = "Raul", side = "hero", row = "front", sprite = "knight",
        base = { maxHP = 100, maxMP = 100, speed = 50 },
        equipment = { weapon = "rusty_sword", shield = "buckler", armor = "tattered_clothes" },
        desc = "A steady swordsman who leads from the front.",
    },
    victor = {
        name = "Victor", side = "hero", row = "front", sprite = "champion",
        base = { maxHP = 100, maxMP = 100, speed = 50 },
        equipment = { weapon = "rusty_mace", armor = "tattered_clothes" },
        desc = "Slow but crushing; his mace answers most questions.",
    },
    lya = {
        name = "Lya", side = "hero", row = "back", sprite = "nomad",
        base = { maxHP = 100, maxMP = 100, speed = 50 },
        equipment = { weapon = "flimsy_bow", armor = "tattered_clothes" },
        desc = "A patient archer. Deadliest when she takes her time.",
    },
    furgol = {
        name = "Furgol", side = "hero", row = "back", sprite = "brigand",
        base = { maxHP = 100, maxMP = 100, speed = 50 },
        equipment = { weapon = "crooked_wand", armor = "tattered_clothes" },
        desc = "A hedge-mage with a temperamental wand.",
    },

    ---------------------------------------------------------------- enemies
    skeleton = {
        name = "Skeleton", side = "enemy", row = "front", sprite = "skeleton",
        base = { maxHP = 100, maxMP = 0, speed = 30, physical = 20 },
        mindless = true,
        innate = { "swing" },
        desc = "Clattering bones with no mind to break.",
    },
    goblin = {
        name = "Goblin", side = "enemy", row = "front", sprite = "imp",
        base = { maxHP = 50, maxMP = 30, speed = 70, physical = 10 },
        innate = { "swing" },
        desc = "Quick and cowardly, but quick.",
    },
    witch = {
        name = "Witch", side = "enemy", row = "back", sprite = "mushroom",
        base = { maxHP = 60, maxMP = 150, speed = 50, magic = 30 },
        innate = { "heal", "greater_heal", "fire_ball" },
        desc = "Hangs back and mends her wounded, or burns yours.",
    },
}
