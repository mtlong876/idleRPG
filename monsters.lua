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