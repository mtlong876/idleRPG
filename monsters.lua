local monsters = {
    ["goblin"] = {
        name = "Goblin",
        description = "A small, green creature known for its mischief.",
        health = 5,
        attack = 1,
        defense = 1,
        strength = 1,
        speed = 3,
        experience = 10,
        loot = {
            items = {
                ["wood"] = { quantity = 2, weight = 95},
            },
            lootTable = {}
        },
    },
    ["orc"] = {
        name = "Orc",
        description = "A brutish creature with great strength.",
        health = 15,
        attack = 3,
        defense = 2,
        strength = 4,
        speed = 2,
        experience = 25,
        loot = {
            items = {
                ["stone"] = { quantity = 3, weight = 85},
                ["iron"] = { quantity = 1, weight = 15},
            },
            lootTable = {}
        },
    },
    ["troll"] = {
        name = "Troll",
        description = "A large and powerful creature that dwells in caves.",
        health = 30,
        attack = 5,
        defense = 4,
        strength = 6,
        speed = 1,
        experience = 50,
        loot = {
            items = {
                ["stone"] = { quantity = 5, weight = 70},
                ["iron"] = { quantity = 2, weight = 25},
                ["wood"] = { quantity = 3, weight = 5},
            },
            lootTable = {}
        },
    },
    ["dragon"] = {
        name = "Dragon",
        description = "A fearsome dragon that breathes fire and hoards treasure.",
        health = 100,
        attack = 15,
        defense = 10,
        strength = 20,
        speed = 5,
        experience = 200,
        loot = {
            items = {
                ["iron"] = { quantity = 5, weight = 50},
                ["wood"] = { quantity = 10, weight = 30},
                ["stone"] = { quantity = 8, weight = 20},
            },
            lootTable = {}
        },
    },
    ["slime"] = {
        name = "Slime",
        description = "A weak but numerous creature that oozes around.",
        health = 3,
        attack = 1,
        defense = 0,
        strength = 1,
        speed = 4,
        experience = 5,
        loot = {
            items = {
                ["wood"] = { quantity = 1, weight = 80},
                ["stone"] = { quantity = 1, weight = 20},
            },
            lootTable = {}
        },
    },
    ["skeleton"] = {
        name = "Skeleton",
        description = "An undead warrior risen from the grave.",
        health = 10,
        attack = 2,
        defense = 1,
        strength = 3,
        speed = 2,
        experience = 15,
        loot = {
            items = {
                ["stone"] = { quantity = 2, weight = 90},
                ["iron"] = { quantity = 1, weight = 10},
            },
            lootTable = {}
        },
    },
}

local function buildLootTables()
    for monsterName, monster in pairs(monsters) do
        if monster.loot and monster.loot.items then
            monster.loot.lootTable = {}
            local currentIndex = 1

            for itemName, itemData in pairs(monster.loot.items) do
                for i = 1, itemData.weight do
                    monster.loot.lootTable[currentIndex] = {
                        item = itemName,
                        quantity = itemData.quantity
                    }
                    currentIndex = currentIndex + 1
                end
            end
            

            for i = currentIndex, 100 do
                monster.loot.lootTable[i] = nil
            end
        end
    end
end

buildLootTables()

return monsters