--TODO
--Start moving functions to seperate files
--Fix chat messages

if arg[2] == "debug" then
    require("lldebugger").start()
end
--config files
local items = require("items")
local levelupTable = require("levelup")
local skilling = require("skilling")
local weapons = require("weapons")
local armour = require("armour")
local tools = require("tools")
local shops = require("shops")
local monsters = require("monsters")
local recipies = require("recipies")
--json save and load file
local json = require("json")
--global variables
local states = {}
local currentState = "menu"
local currentSkill = ""
local currentAction = ""
local currentTarget = nil
local timer = 0
local tickCount = 0
local monsterTickCount = 0
local notifications = {}
local notificationTimer = 0
local chatMessages = {}
local maxChatMessages = 50
local chatScroll = 0
local pages = {
    shop = {
        pages = {},
        perPage = 4
    },
    skill = {
        pages = {},
        perPage = 4
    },
    crafting = {
        pages = 1,
        perPage = 3
    },
    combat = {
        pages = 1,
        perPage = 4
    }
}

local player = {
    inventory = {
        coins = 0,
        backpack = {},
        tools = {
            axe = "",
            pickaxe = "",
        },
        equipment = {
            weapon = "",
            shield = "",
        }
    },
    skills = {
        woodcutting = 1,
        mining = 1,
        thieving = 1,
        defence = 1,
        attack = 1,
        strength = 1,
        life = 10,
    },
    experience = {
        woodcutting = 0,
        mining = 0,
        thieving = 0,
        attack = 0,
        strength = 0,
        defence = 0,
        life = 612,
    },
    life = {
        max = 100,
        current = 100,
    },
    defence = 1,
    attack = 1,
    strength = 1,
}

function tableCopy(table)
    local copy = {}
    for key,value in pairs(table) do
        if type(value) == "table" then
            copy[key] = tableCopy(value)
        else
            copy[key] = value
        end
    end
    return copy
end

function addChatMessage(message)
    table.insert(chatMessages, message)
    if #chatMessages > maxChatMessages then
        table.remove(chatMessages, 1)
    end
    chatScroll = 0
end

function woodcuttingActions(type)
    if tickCount < 3 then
        return
    end
    local data = skilling["woodcutting"][type]
    if not data then
        print("No woodcutting action defined for type: " .. type)
        return
    end
    if tickCount < data.requiredRoll then
        local baseStrength = math.floor((player.skills.woodcutting + tools[player.inventory.tools.axe].strength)/2)
        if baseStrength+tickCount < data.requiredRoll then
            local roll = math.random(baseStrength+ tickCount, data.requiredRoll)
            if roll ~= data.requiredRoll then
                return
            end
        end
    end
    addChatMessage("You start woodcutting " .. data.item .. "...")
    addItem(data.item, data.item_amount,true)
    addExperience("woodcutting", data.experience)
    tickCount = 0
end

function miningActions(type)
    if tickCount < 3 then
        return
    end
    local data = skilling["mining"][type]
    if not data then
        print("No mining action defined for type: " .. type)
        return
    end
    if tickCount < data.requiredRoll then
        local baseStrength = math.floor((player.skills.mining + tools[player.inventory.tools.pickaxe].strength)/2)
        if baseStrength+tickCount < data.requiredRoll then
            local roll = math.random(baseStrength+ tickCount, data.requiredRoll)
            if roll ~= data.requiredRoll then
                return
            end
        end
    end
    addChatMessage("You start mining " .. data.item .. "...")
    addItem(data.item, data.item_amount,true)
    addExperience("mining", data.experience)
    tickCount = 0
end

function thievingActions(type) 
    if tickCount < 3 then
        return
    end
    local data = skilling["thieving"][type]
    if not data then
        print("No thieving action defined for type: " .. type)
        return
    end
    if tickCount < data.requiredRoll then
        local baseStrength = math.floor(player.skills.thieving)
        local roll = math.random(baseStrength + tickCount, data.requiredRoll)
        if roll ~= data.requiredRoll then
            return
        end
    end
    addChatMessage("You start thieving " .. type .. "...")
    updateCoins(data.item_amount)
    addExperience("thieving", data.experience)
    tickCount = 0
end

function addItem(itemName, quantity,notification)
    local item = items[itemName]
    if not item then
        print("Item not found: " .. itemName)
        return
    end
    if player.inventory.backpack[itemName] then
        player.inventory.backpack[itemName].quantity = player.inventory.backpack[itemName].quantity + quantity
    else
        player.inventory.backpack[itemName] = { item = itemName, quantity = quantity }
    end
    if notification  then
        addNotification(itemName, quantity, "center")
    end
end

function removeItem(itemName, quantity)
    if player.inventory.backpack[itemName] and player.inventory.backpack[itemName].quantity >= quantity then
        player.inventory.backpack[itemName].quantity = player.inventory.backpack[itemName].quantity - quantity
        if player.inventory.backpack[itemName].quantity <= 0 then
            player.inventory.backpack[itemName] = nil
        end
    else
        print("Not enough items to remove: " .. itemName)
    end
end

function updateCoins(amount)
    player.inventory.coins = player.inventory.coins + amount
    if player.inventory.coins < 0 then
        player.inventory.coins = 0
    end
    if amount > 0 then
        addNotification("coins", amount,"left")
    else
        addNotification("coins", amount,"left")
    end
end

function addExperience(skill, amount)
    if player.experience[skill] then
        player.experience[skill] = player.experience[skill] + amount
        while player.experience[skill] >= levelupTable[player.skills[skill]] do
            player.skills[skill] = player.skills[skill] + 1
            if skill == "life" then
                player.life.max = player.life.max + 10
                player.life.current = player.life.max
            end
            print(skill .. " leveled up to " .. player.skills[skill])
            addChatMessage(skill .. " leveled up to " .. player.skills[skill])
            addLevelUpNotification(skill, player.skills[skill])
        end
        addNotification(skill .. " experience", amount, "right")
    else
        print("Skill not found: " .. skill)
    end
end

function calculateNotificationPosition(isLevelUp, location)
    local baseY, targetY, startY
    local notificationHeight = 40
    local spacing = 10
    
    if isLevelUp then
        baseY = love.graphics.getHeight() - 100
        startY = love.graphics.getHeight() + 100
        
        local levelUpCount = 0
        for _, notif in ipairs(notifications) do
            if notif.isLevelUp then
                levelUpCount = levelUpCount + 1
            end
        end
        
        targetY = baseY - (levelUpCount * (notificationHeight + spacing))
    else
        baseY = 50
        startY = -50
        
        local regularCount = 0
        for _, notif in ipairs(notifications) do
            if not notif.isLevelUp and notif.location == location then
                regularCount = regularCount + 1
            end
        end
        
        targetY = baseY + (regularCount * (notificationHeight + spacing))
    end
    
    return startY, targetY
end

function addNotification(itemName, quantity, location)
    local item = items[itemName]
    local displayName = item and item.name or itemName
    
    local startY, targetY = calculateNotificationPosition(false, location)
    
    local notification = {
        text = "+" .. quantity .. " " .. displayName,
        y = startY, 
        targetY = targetY, 
        alpha = 1.0,
        timer = 0,
        maxTime = 3.0,
        slideSpeed = 200,
        isSliding = true,
        isFading = false,
        location = location,
    }
    if quantity < 0 then
        notification.text = quantity .. " " .. displayName
    end
    table.insert(notifications, notification)
end

function addLevelUpNotification(skill, level)
    local skillName = string.upper(string.sub(skill, 1, 1)) .. string.sub(skill, 2)
    
    local startY, targetY = calculateNotificationPosition(true, "center")
    
    local notification = {
        text = "LEVEL UP! " .. skillName .. " is now level " .. level .. "!",
        y = startY,
        targetY = targetY,
        alpha = 1.0,
        timer = 0,
        maxTime = 4.0,
        slideSpeed = 300,
        isSliding = true,
        isFading = false,
        location = "center",
        isLevelUp = true,
        pulseTimer = 0,
    }
    
    table.insert(notifications, notification)
end

function repositionNotifications()
    local notificationHeight = 40
    local spacing = 10
    
    local locationCounts = {left = 0, center = 0, right = 0}
    
    for _, notif in ipairs(notifications) do
        if not notif.isLevelUp then
            local newTargetY = 50 + (locationCounts[notif.location] * (notificationHeight + spacing))
            
            if not notif.isSliding or notif.y > -30 then
                notif.targetY = newTargetY
                if not notif.isSliding then
                    notif.isSliding = true
                end
            end
            
            locationCounts[notif.location] = locationCounts[notif.location] + 1
        end
    end
    
    local levelUpCount = 0
    for _, notif in ipairs(notifications) do
        if notif.isLevelUp then
            local newTargetY = love.graphics.getHeight() - 100 - (levelUpCount * (notificationHeight + spacing))
            
            if not notif.isSliding or notif.y < love.graphics.getHeight() + 30 then
                notif.targetY = newTargetY
                if not notif.isSliding then
                    notif.isSliding = true
                end
            end
            
            levelUpCount = levelUpCount + 1
        end
    end
end

function updateNotifications(dt)
    for i = #notifications, 1, -1 do
        local notif = notifications[i]
        notif.timer = notif.timer + dt
        
        if notif.isSliding then
            if notif.isLevelUp then
                notif.y = notif.y - notif.slideSpeed * dt
                if notif.y <= notif.targetY then
                    notif.y = notif.targetY
                    notif.isSliding = false
                end
            else
                notif.y = notif.y + notif.slideSpeed * dt
                if notif.y >= notif.targetY then
                    notif.y = notif.targetY
                    notif.isSliding = false
                end
            end
        end
        
        if notif.isLevelUp then
            notif.pulseTimer = notif.pulseTimer + dt
        end
        
        if notif.timer >= notif.maxTime - 1.0 and not notif.isFading then
            notif.isFading = true
        end
        
        if notif.isFading then
            local fadeTime = notif.timer - (notif.maxTime - 1.0)
            notif.alpha = math.max(0, 1.0 - fadeTime)
        end
        
        if notif.timer >= notif.maxTime then
            table.remove(notifications, i)
            repositionNotifications()
        end
    end
end

function drawNotifications()
    for _, notif in ipairs(notifications) do
        if notif.isLevelUp then
            local textWidth = love.graphics.getFont():getWidth(notif.text)
            local textHeight = love.graphics.getFont():getHeight()
            local padding = 20
            
            local bgWidth = math.max(600, textWidth + padding * 4)
            local bgHeight = textHeight + padding * 2
            local bgX = (love.graphics.getWidth() - bgWidth) / 2
            local bgY = notif.y - padding
            
            local pulse = 1.0 + 0.1 * math.sin(notif.pulseTimer * 8)
            local currentAlpha = notif.alpha * pulse
            
            love.graphics.setColor(1, 0.8, 0, 0.9 * notif.alpha) -- Golden background
            love.graphics.rectangle("fill", bgX, bgY, bgWidth, bgHeight)
            
            love.graphics.setColor(1, 1, 0, currentAlpha) -- Bright gold border
            love.graphics.setLineWidth(3)
            love.graphics.rectangle("line", bgX, bgY, bgWidth, bgHeight)
            love.graphics.setLineWidth(1)
            
            love.graphics.setColor(1, 1, 1, 0.3 * notif.alpha)
            love.graphics.rectangle("fill", bgX + 2, bgY + 2, bgWidth - 4, bgHeight - 4)
            
            love.graphics.setColor(1, 1, 1, currentAlpha)
            love.graphics.printf(notif.text, 0, notif.y, love.graphics.getWidth(), "center")
            
        else
            local textWidth = love.graphics.getFont():getWidth(notif.text)
            local textHeight = love.graphics.getFont():getHeight()
            local padding = 10
            local bgWidth = textWidth + padding * 2
            local bgHeight = textHeight + padding * 2
            local bgX = (love.graphics.getWidth() - bgWidth) / 2
            
            if notif.location == "left" then
                bgX = bgX - 200
            elseif notif.location == "right" then
                bgX = bgX + 200
            end
            local bgY = notif.y - padding
            
            love.graphics.setColor(0, 0, 0, 0.7 * notif.alpha)
            love.graphics.rectangle("fill", bgX, bgY, bgWidth, bgHeight)
            
            love.graphics.setColor(1, 1, 1, notif.alpha)
            love.graphics.rectangle("line", bgX, bgY, bgWidth, bgHeight)
            
            love.graphics.setColor(1, 1, 1, notif.alpha)
            if notif.location == "center" then
                love.graphics.printf(notif.text, 0, notif.y, love.graphics.getWidth(), "center")
            else
                love.graphics.printf(notif.text, bgX + padding, notif.y, bgWidth - padding * 2, "center")
            end
        end
    end
    
    love.graphics.setColor(1, 1, 1, 1)
end

function savePlayerData()
    local playerJson = json.encode_pretty(player)
    love.filesystem.write("player_save.json", playerJson)
    print("Player data saved to JSON!")
    return playerJson
end

function loadPlayerData()
    if love.filesystem.getInfo("player_save.json") then
        local jsonString = love.filesystem.read("player_save.json")
        print("Loading player data from JSON...")
        
        local success, loadedData = pcall(json.decode, jsonString)
        if success and loadedData then
            if loadedData.inventory then
                player.inventory.coins = loadedData.inventory.coins or 0
                player.inventory.backpack = loadedData.inventory.backpack or {}
                player.inventory.tools = loadedData.inventory.tools or {
                    axe = "",
                    pickaxe = "",
                }
                player.inventory.equipment = loadedData.inventory.equipment or {
                    weapon = "",
                    shield = "",
                }
                player.defence = loadedData.defence or 1
                player.attack = loadedData.attack or 1
                player.strength = loadedData.strength or 1
                player.life = loadedData.life or {
                    max = 100,
                    current = 100,
                }
            end
            if loadedData.skills then
                for skill, level in pairs(loadedData.skills) do
                    player.skills[skill] = level
                end
            end
            if loadedData.experience then
                for skill, exp in pairs(loadedData.experience) do
                    player.experience[skill] = exp
                end
            end
            print("Player data loaded successfully!")
            print("Coins: " .. player.inventory.coins)
            return true
        else
            print("Error decoding JSON data: " .. (loadedData or "unknown error"))
            return false
        end
    else
        print("No save file found")
        return false
    end
end

function printPlayerAsJSON()
    local playerJson = json.encode_pretty(player)
    print("Player data as JSON:")
    print(playerJson)
    return playerJson
end

function purchaseItem(shopName,itemName, quantity)
    local shop = shops[shopName]
    if not shop or not shop.items[itemName] then
        print("Item not available in shop: " .. itemName)
        return
    end
    local cost = shop.items[itemName] * quantity
    if player.inventory.coins >= cost then
        updateCoins(-cost)
        addItem(itemName, quantity,true)
        print("Purchased " .. quantity .. " " .. itemName .. "(s) for " .. cost .. " coins.")
        addChatMessage("Purchased " .. quantity .. " " .. itemName .. "(s) for " .. cost .. " coins.")
    else
        print("Not enough coins to purchase " .. itemName)
    end
end

function sellItem(itemName, quantity)
    local item = items[itemName]
    if not item then
        print("Item not found: " .. itemName)
        return
    end
    
    if not player.inventory.backpack[itemName] or player.inventory.backpack[itemName].quantity < quantity then
        print("Not enough " .. itemName .. " to sell")
        return
    end
    
    local sellPrice = math.floor(item.price * 0.75) * quantity
    removeItem(itemName, quantity)
    updateCoins(sellPrice)
    print("Sold " .. quantity .. " " .. itemName .. "(s) for " .. sellPrice .. " coins.")
    addChatMessage("Sold " .. quantity .. " " .. itemName .. "(s) for " .. sellPrice .. " coins.")
end

function canCraft(recipeName)
    local recipe = recipies[recipeName]
    if not recipe then
        return false
    end
    
    for ingredientName, requiredAmount in pairs(recipe.ingredients) do
        if not player.inventory.backpack[ingredientName] or 
           player.inventory.backpack[ingredientName].quantity < requiredAmount then
            return false
        end
    end
    return true
end

function craftItem(recipeName)
    local recipe = recipies[recipeName]
    if not recipe then
        print("Recipe not found: " .. recipeName)
        return
    end
    
    if not canCraft(recipeName) then
        print("Not enough materials to craft " .. recipeName)
        return
    end
    
    for ingredientName, requiredAmount in pairs(recipe.ingredients) do
        removeItem(ingredientName, requiredAmount)
    end
    
    addItem(recipe.result, 1,true)
    print("Successfully crafted " .. recipe.result .. "!")
    addChatMessage("Successfully crafted " .. recipe.result .. "!")
    
    updateCraftingButtons()
end

function equipTool(toolName)
    local tool = tools[toolName]
    if not tool then
        print("Tool not found: " .. toolName)
        return
    end
    if not player.inventory.backpack[toolName] then
        print("You do not have a " .. toolName .. " in your backpack.")
        return
    end
    if player.inventory.tools[tool.slot] then
        print("Replacing " .. player.inventory.tools[tool.slot] .. " with " .. toolName)
        addItem(player.inventory.tools[tool.slot], 1,false)
    end
    player.inventory.tools[tool.slot] = toolName
    removeItem(toolName, 1)
    print("Equipped " .. toolName .. " in slot: " .. tool.slot)
    addChatMessage("Equipped " .. toolName .. " in slot: " .. tool.slot)
end

function equipWeapon(weaponName)
    if not weapons[weaponName] then
        print("Weapon not found: " .. weaponName)
        return false
    end
    if not player.inventory.backpack[weaponName] then
        print("You do not have a " .. weaponName .. " in your backpack.")
        return false
    end
    
    if player.inventory.equipment.weapon ~= "" then
        addItem(player.inventory.equipment.weapon, 1,false)
        updateStats(player.inventory.equipment.weapon, false)
        player.inventory.equipment.weapon = ""
        print("Unequipping " .. player.inventory.equipment.weapon)
    end
    removeItem(weaponName, 1)
    updateStats(weaponName, true)
    player.inventory.equipment.weapon = weaponName
    print("Equipped " .. weaponName .. " as weapon")
    addChatMessage("Equipped " .. weaponName .. " as weapon")
    return true
end

function equiparmour(armourName)
    print("Equipping armour: " .. armourName)
    if not armour[armourName] then
        print("armour not found: " .. armourName)
        return false
    end
    if not player.inventory.backpack[armourName] then
        print("You do not have a " .. armourName .. " in your backpack.")
        return false
    end
    
    local armourItem = armour[armourName]
    local slot = armourItem.slot or "shield"
    
    if player.inventory.equipment[slot] ~= "" then
        updateStats(player.inventory.equipment[slot], false)
        addItem(player.inventory.equipment[slot], 1,false)
        print("Unequipping " .. player.inventory.equipment[slot])
    end
    
    player.inventory.equipment[slot] = armourName
    updateStats(armourName, true)
    removeItem(armourName, 1)
    print("Equipped " .. armourName .. " in slot: " .. slot)
    return true
end

function unequipTool(slot)
    if player.inventory.tools[slot] ~= "" then
        local toolName = player.inventory.tools[slot]
        addItem(toolName, 1,false)
        player.inventory.tools[slot] = ""
        print("Unequipped " .. toolName)
        return true
    else
        print("No tool equipped in slot: " .. slot)
        return false
    end
end

function unequipWeapon()
    if player.inventory.equipment.weapon ~= "" then
        local weaponName = player.inventory.equipment.weapon
        addItem(weaponName, 1,false)
        updateStats(weaponName, false)
        player.inventory.equipment.weapon = ""
        print("Unequipped " .. weaponName)
        return true
    else
        print("No weapon equipped")
        return false
    end
end

function unequiparmour(slot)
    slot = slot or "shield"
    if player.inventory.equipment[slot] ~= "" then
        local armourName = player.inventory.equipment[slot]
        player.defence = player.defence - armour[player.inventory.equipment[slot]].defence
        addItem(player.inventory.equipment[slot], 1,false)
        player.inventory.equipment[slot] = ""
        print("Unequipped " .. armourName)
        return true
    else
        print("No armour equipped in slot: " .. slot)
        return false
    end
end

function updateStats(item, equip)
    if not items[item] then
        print("Item not found: " .. item)
        return
    end
    if equip then
        if weapons[item] then
            player.attack = player.attack + weapons[item].attack or 0
            player.strength = player.strength + weapons[item].strength or 0
        elseif armour[item] then
            player.defence = player.defence + armour[item].defence or 0
        end
    else
        if weapons[item] then
            player.attack = player.attack - weapons[item].attack or 0
            player.strength = player.strength - weapons[item].strength or 0
        elseif armour[item] then
            player.defence = player.defence - armour[item].defence or 0
        end
    end
end

function doSkill()
    if currentSkill == "woodcutting" then
        if not tools[player.inventory.tools.axe] then
            print("You need an axe to woodcut!")
            tickCount = 0
            currentSkill = ""
            return
        end
        woodcuttingActions(currentAction)
    elseif currentSkill == "thieving" then
        thievingActions(currentAction)
    elseif currentSkill == "mining" then
        if not tools[player.inventory.tools.pickaxe] then
            print("You need a pickaxe to mine!")
            tickCount = 0
            currentSkill = ""
            return
        end
        miningActions(currentAction)
    else
        return
    end
    tickCount = tickCount + 1
end

function doCombat()
    if not monsters[currentAction] then
        return
    end
    if not currentTarget then
        currentTarget = tableCopy(monsters[currentAction])
        currentTarget.currentHealth = currentTarget.health
        monsterTickCount = 0
    end
    tickCount = tickCount + 1
    monsterTickCount = monsterTickCount + 1
    local playerWeapon = weapons[player.inventory.equipment.weapon]
    if not playerWeapon or playerWeapon == "" then
        print("You need a weapon equipped to fight!")
        return
    end
    if tickCount >= playerWeapon.speed then
        local attackRoll = math.random(0, player.attack + player.skills.attack)
        local luckRoll = math.random(1, 10)
        if attackRoll > currentTarget.defense or luckRoll == 10 then
            local damageRoll = math.random(1, player.strength + math.floor(player.skills.strength/4))
            currentTarget.currentHealth = currentTarget.currentHealth - damageRoll
            addExperience("attack", damageRoll)
            print("You hit the " .. currentAction .. " for " .. damageRoll .. " damage!")
        else
            print("You missed the " .. currentAction .. "!")
        end
        tickCount = 0
    end
    if monsterTickCount >= currentTarget.speed then
        local monsterAttackRoll = math.random(0, currentTarget.attack)
        local monsterLuckRoll = math.random(1, 10)
        if monsterAttackRoll > player.defence or monsterLuckRoll == 10 then
            local monsterDamageRoll = math.random(1, currentTarget.strength + math.floor(currentTarget.attack/4))
            player.life.current = player.life.current - monsterDamageRoll
            addExperience("defence", monsterDamageRoll)
            print("The " .. currentAction .. " hits you for " .. monsterDamageRoll .. " damage!")
        else
            print("The " .. currentAction .. " missed you!")
        end
        monsterTickCount = 0
    end
    if currentTarget.currentHealth <= 0 then
        print("You defeated the " .. currentAction .. "!")
        if currentTarget.loot and currentTarget.loot.lootTable then
            local lootRoll = math.random(1, #currentTarget.loot.lootTable)
            local lootItem = currentTarget.loot.lootTable[lootRoll]
            if lootItem then
                addItem(lootItem.item, lootItem.quantity,true)
                print("You looted " .. lootItem.quantity .. " " .. lootItem.item .. "(s)!")
            else
                print("No loot dropped.")
            end
        end
        addExperience("strength", currentTarget.health)
        currentTarget = nil
        monsterTickCount = 0
        tickCount = 0
    end
end

local function updateEquipmentButtons()
    states.equipment.buttons = {
        {
            x = 100,
            y = 400,
            width = 120,
            height = 50,
            text = "Back to Game",
            action = function() currentState = "game" end
        }
    }
    
    local buttonY = 200
    local buttonX = 500
    for itemName, itemData in pairs(player.inventory.backpack) do
        local item = items[itemName]
        if item and itemData.quantity > 0 then
            if item.type == "weapon" then
                table.insert(states.equipment.buttons, {
                    x = buttonX,
                    y = buttonY,
                    width = 100,
                    height = 30,
                    text = "Equip " .. itemName,
                    action = function() 
                        equipWeapon(itemName)
                        updateEquipmentButtons()
                    end
                })
                buttonY = buttonY + 35
            elseif item.type == "armour" then
                table.insert(states.equipment.buttons, {
                    x = buttonX,
                    y = buttonY,
                    width = 100,
                    height = 30,
                    text = "Equip " .. itemName,
                    action = function() 
                        equiparmour(itemName)
                        updateEquipmentButtons()
                    end
                })
                buttonY = buttonY + 35
            elseif item.type == "tool" then
                table.insert(states.equipment.buttons, {
                    x = buttonX,
                    y = buttonY,
                    width = 100,
                    height = 30,
                    text = "Equip " .. itemName,
                    action = function() 
                        equipTool(itemName)
                        updateEquipmentButtons()
                    end
                })
                buttonY = buttonY + 35
            end
        end
    end
    
    buttonX = 200
    buttonY = 200
    
    for slot, toolName in pairs(player.inventory.tools) do
        if toolName ~= "" then
            table.insert(states.equipment.buttons, {
                x = buttonX,
                y = buttonY,
                width = 100,
                height = 30,
                text = "Unequip " .. slot,
                action = function() 
                    unequipTool(slot)
                    updateEquipmentButtons()
                end
            })
            buttonY = buttonY + 35
        end
    end
    
    for slot, equipName in pairs(player.inventory.equipment) do
        if equipName ~= "" then
            table.insert(states.equipment.buttons, {
                x = buttonX,
                y = buttonY,
                width = 100,
                height = 30,
                text = "Unequip " .. slot,
                action = function() 
                    if slot == "weapon" then
                        unequipWeapon()
                    else
                        unequiparmour(slot)
                    end
                    updateEquipmentButtons()
                end
            })
            buttonY = buttonY + 35
        end
    end
end

states.menu = {
    text = function ()
        love.graphics.setColor(1, 1, 1) -- White
        love.graphics.printf("Idle RPG - Main Menu", 0, 100, love.graphics.getWidth(), "center")
    end,
    buttons = {
        {
            x = 300,
            y = 200,
            width = 200,
            height = 60,
            text = "Start Game",
            action = function() currentState = "game" end
        },
        {
            x = 300,
            y = 280,
            width = 200,
            height = 60,
            text = "Settings",
            action = function() currentState = "settings" end
        },
        {
            x = 300,
            y = 360,
            width = 200,
            height = 60,
            text = "Quit",
            action = function() love.event.quit() end
        }
    }
}

states.game = {
    buttons = {
        {
            x = 100,
            y = 100,
            width = 100,
            height = 50,
            text = "Woodcutting",
            action = function() 
                currentState = "woodcutting"
                pages.skill.pages.woodcutting = 1
                updateSkillButtons("woodcutting")
            end
        },
        {
            x = 100,
            y = 200,
            width = 100,
            height = 50,
            text = "Thieving",
            action = function() 
                currentState = "thieving"
                pages.skill.pages.thieving = 1
                updateSkillButtons("thieving")
            end
        },
        {
            x = 100,
            y = 250,
            width = 100,
            height = 50,
            text = "Mining",
            action = function() 
                currentState = "mining"
                pages.skill.pages.mining = 1
                updateSkillButtons("mining")
            end
        },
        {
            x = 100,
            y = 150,
            width = 100,
            height = 50,
            text = "Combat",
            action = function() 
                currentState = "combat"
                pages.combat.pages = 1
                updateCombatButtons()
            end
        },
        {
            x = 100,
            y = 300,
            width = 100,
            height = 50,
            text = "Visit Shop",
            action = function() currentState = "shops" end
        },
        {
            x = 100,
            y = 350,
            width = 100,
            height = 50,
            text = "Crafting",
            action = function() 
                currentState = "crafting"
                pages.crafting.pages = 1
                updateCraftingButtons()
            end
        },
        {
            x = 100,
            y = 400,
            width = 100,
            height = 50,
            text = "Back to Menu",
            action = function() currentState = "menu" end
        },
        {
            x = 250,
            y = 100,
            width = 120,
            height = 50,
            text = "Save to JSON",
            action = function() savePlayerData() end
        },
        {
            x = 250,
            y = 200,
            width = 120,
            height = 50,
            text = "Print JSON",
            action = function() printPlayerAsJSON() end
        },
        {
            x = 250,
            y = 300,
            width = 120,
            height = 50,
            text = "Load from JSON",
            action = function() loadPlayerData() end
        },
        {
            x = 400,
            y = 100,
            width = 120,
            height = 50,
            text = "Equipment",
            action = function() 
                currentState = "equipment"
                updateEquipmentButtons()
            end
        }
    }
}

states.settings = {
    text = function ()
        love.graphics.setColor(1, 1, 1) -- White
        love.graphics.printf("Settings", 0, 100, love.graphics.getWidth(), "center")
    end,
    buttons = {
        {
            x = 300,
            y = 200,
            width = 200,
            height = 60,
            text = "Audio Settings",
            action = function() print("Audio settings clicked") end
        },
        {
            x = 300,
            y = 280,
            width = 200,
            height = 60,
            text = "Video Settings",
            action = function() print("Video settings clicked") end
        },
        {
            x = 300,
            y = 360,
            width = 200,
            height = 60,
            text = "Back to Menu",
            action = function() currentState = "menu" end
        }
    }
}

states.shops = {
    text = function ()
        love.graphics.setColor(1, 1, 1) -- White
        love.graphics.printf("shops", 0, 100, love.graphics.getWidth(), "center")
        
    end,
    buttons = {
        {
            x = 300,
            y = 200,
            width = 200,
            height = 60,
            text = "Basic Shop",
            action = function() 
                currentState = "basicShop"
                pages.shop.pages["basicShop"] = 1
                updateShopButtons("basicShop")
            end
        },
        {
            x = 300,
            y = 280,
            width = 200,
            height = 60,
            text = "Sell Items",
            action = function() 
                currentState = "sellShop"
                updateSellShopButtons()
            end
        },
        {
            x = 300,
            y = 360,
            width = 200,
            height = 60,
            text = "Back to Game",
            action = function() currentState = "game" end
        },
    }
}

for shopName,shop in pairs(shops) do
    pages.shop.pages[shopName] = 1
    
    states[shopName] = {
        text = function ()
            love.graphics.setColor(1, 1, 1) -- White
            love.graphics.printf(shop.name, 0, 100, love.graphics.getWidth(), "center")
            love.graphics.printf(shop.description, 0, 150, love.graphics.getWidth(), "center")
            
            -- Show page info
            local totalItems = 0
            for _ in pairs(shop.items) do totalItems = totalItems + 1 end
            local totalPages = math.ceil(totalItems / pages.shop.perPage)
            if totalPages > 1 then
                love.graphics.printf("Page " .. pages.shop.pages[shopName] .. " of " .. totalPages, 0, 180, love.graphics.getWidth(), "center")
            end
        end,
        buttons = {}
    }
end

function updateShopButtons(shopName)
    local shop = shops[shopName]
    if not shop then return end
    
    states[shopName].buttons = {
        {
            x = 300,
            y = 500,
            width = 200,
            height = 60,
            text = "Back to Shops",
            action = function() currentState = "shops" end
        }
    }
    
    local itemsArray = {}
    for itemName, price in pairs(shop.items) do
        table.insert(itemsArray, {name = itemName, price = price})
    end
    
    local totalItems = #itemsArray
    local totalPages = math.ceil(totalItems / pages.shop.perPage)
    local currentPage = pages.shop.pages[shopName]
    
    local startIndex = (currentPage - 1) * pages.shop.perPage + 1
    local endIndex = math.min(startIndex + pages.shop.perPage - 1, totalItems)
    
    local y = 200
    for i = startIndex, endIndex do
        local item = itemsArray[i]
        local newButton = {
            x = 300,
            y = y,
            width = 200,
            height = 40,
            text = item.name .. ": " .. item.price .. " coins",
            action = function()
                purchaseItem(shopName, item.name, 1)
            end
        }
        y = y + 50
        table.insert(states[shopName].buttons, newButton)
    end
    
    if totalPages > 1 then
        if currentPage > 1 then
            table.insert(states[shopName].buttons, {
                x = 100,
                y = 450,
                width = 80,
                height = 40,
                text = "Previous",
                action = function()
                    pages.shop.pages[shopName] = pages.shop.pages[shopName] - 1
                    updateShopButtons(shopName)
                end
            })
        end
        
        if currentPage < totalPages then
            table.insert(states[shopName].buttons, {
                x = 520,
                y = 450,
                width = 80,
                height = 40,
                text = "Next",
                action = function()
                    pages.shop.pages[shopName] = pages.shop.pages[shopName] + 1
                    updateShopButtons(shopName)
                end
            })
        end
    end
end

for shopName, _ in pairs(shops) do
    updateShopButtons(shopName)
end

states.sellShop = {
    text = function ()
        love.graphics.setColor(1, 1, 1) -- White
        love.graphics.printf("Sell Items", 0, 50, love.graphics.getWidth(), "center")
        love.graphics.printf("Your coins: " .. player.inventory.coins, 0, 80, love.graphics.getWidth(), "center")
        
        if next(player.inventory.backpack) == nil then
            love.graphics.printf("Your backpack is empty!", 0, 150, love.graphics.getWidth(), "center")
        else
            love.graphics.print("Click on items to sell them (75% of buy price):", 50, 120)
        end
    end,
    buttons = {
        {
            x = 300,
            y = 500,
            width = 200,
            height = 60,
            text = "Back to Shops",
            action = function() currentState = "shops" end
        }
    }
}

function updateSellShopButtons()
    states.sellShop.buttons = {
        {
            x = 300,
            y = 500,
            width = 200,
            height = 60,
            text = "Back to Shops",
            action = function() currentState = "shops" end
        }
    }
    
    local y = 160
    local x = 50
    local itemsPerRow = 3
    local itemCount = 0
    
    for itemName, itemData in pairs(player.inventory.backpack) do
        local item = items[itemName]
        if item and itemData.quantity > 0 then
            local sellPrice = math.floor(item.price * 0.75)
            local newButton = {
                x = x,
                y = y,
                width = 180,
                height = 50,
                text = itemName .. " (" .. itemData.quantity .. ")\nSell for " .. sellPrice .. " coins",
                action = function()
                    sellItem(itemName, 1)
                    updateSellShopButtons()
                end
            }
            
            table.insert(states.sellShop.buttons, newButton)
            
            itemCount = itemCount + 1
            x = x + 200
            
            if itemCount % itemsPerRow == 0 then
                x = 50
                y = y + 70
            end
        end
    end
end

function updateCraftingButtons()
    states.crafting.buttons = {
        {
            x = 400,
            y = 500,
            width = 120,
            height = 50,
            text = "Back to Game",
            action = function() currentState = "game" end
        }
    }
    
    local recipesArray = {}
    for recipeName, recipe in pairs(recipies) do
        table.insert(recipesArray, {name = recipeName, data = recipe})
    end
    
    local totalRecipes = #recipesArray
    local totalPages = math.ceil(totalRecipes / pages.crafting.perPage)
    
    local startIndex = (pages.crafting.pages - 1) * pages.crafting.perPage + 1
    local endIndex = math.min(startIndex + pages.crafting.perPage - 1, totalRecipes)
    
    local y = 170
    local x = 50
    
    for i = startIndex, endIndex do
        local recipe = recipesArray[i]
        local ingredientsText = ""
        for ingredientName, amount in pairs(recipe.data.ingredients) do
            if ingredientsText ~= "" then
                ingredientsText = ingredientsText .. "\n"
            end
            ingredientsText = ingredientsText .. ingredientName .. ": " .. amount
        end
        
        local newButton = {
            x = x,
            y = y,
            width = 250,
            height = 80,
            text = "Craft " .. recipe.data.result .. "\n" .. ingredientsText,
            action = function()
                craftItem(recipe.name)
            end,
            canCraft = canCraft(recipe.name)
        }
        
        table.insert(states.crafting.buttons, newButton)
        
        x = x + 270
        if (i - startIndex + 1) % 2 == 0 then
            x = 50
            y = y + 90
        end
    end
    
    if totalPages > 1 then
        if pages.crafting.pages > 1 then
            table.insert(states.crafting.buttons, {
                x = 100,
                y = 450,
                width = 80,
                height = 40,
                text = "Previous",
                action = function()
                    pages.crafting.pages = pages.crafting.pages - 1
                    updateCraftingButtons()
                end
            })
        end
        
        if pages.crafting.pages < totalPages then
            table.insert(states.crafting.buttons, {
                x = 300,
                y = 450,
                width = 80,
                height = 40,
                text = "Next",
                action = function()
                    pages.crafting.pages = pages.crafting.pages + 1
                    updateCraftingButtons()
                end
            })
        end
    end
end

function updateCombatButtons()
    states.combat.buttons = {
        {
            x = 400,
            y = 500,
            width = 120,
            height = 50,
            text = "Back to Game",
            action = function() 
                currentState = "game"
                currentAction = ""
                currentSkill = ""
            end
        }
    }
    
    local monstersArray = {}
    for monsterName, monsterData in pairs(monsters) do
        table.insert(monstersArray, {name = monsterName, data = monsterData})
    end
    
    local totalMonsters = #monstersArray
    local totalPages = math.ceil(totalMonsters / pages.combat.perPage)
    
    local startIndex = (pages.combat.pages - 1) * pages.combat.perPage + 1
    local endIndex = math.min(startIndex + pages.combat.perPage - 1, totalMonsters)
    
    local buttonY = 260
    for i = startIndex, endIndex do
        local monster = monstersArray[i]
        table.insert(states.combat.buttons, {
            x = 100,
            y = buttonY,
            width = 200,
            height = 40,
            text = "Fight " .. monster.data.name,
            action = function()
                currentSkill = "combat"
                currentAction = monster.name
            end
        })
        buttonY = buttonY + 50
    end
    
    if totalPages > 1 then
        if pages.combat.pages > 1 then
            table.insert(states.combat.buttons, {
                x = 100,
                y = 450,
                width = 80,
                height = 40,
                text = "Previous",
                action = function()
                    pages.combat.pages = pages.combat.pages - 1
                    updateCombatButtons()
                end
            })
        end
        
        if pages.combat.pages < totalPages then
            table.insert(states.combat.buttons, {
                x = 300,
                y = 450,
                width = 80,
                height = 40,
                text = "Next",
                action = function()
                    pages.combat.pages = pages.combat.pages + 1
                    updateCombatButtons()
                end
            })
        end
    end
end

states.equipment = {
    text = function ()
        love.graphics.setColor(1, 1, 1) -- White
        love.graphics.printf("Equipment", 0, 50, love.graphics.getWidth(), "center")
        
        local y = 100
        
        love.graphics.print("Tools:", 50, y)
        y = y + 25
        for slot, toolName in pairs(player.inventory.tools) do
            local displayText = slot .. ": " .. (toolName ~= "" and toolName or "None")
            love.graphics.print(displayText, 70, y)
            y = y + 20
        end
        
        y = y + 10
        love.graphics.print("Combat Gear:", 50, y)
        y = y + 25
        for slot, equipName in pairs(player.inventory.equipment) do
            local displayText = slot .. ": " .. (equipName ~= "" and equipName or "None")
            love.graphics.print(displayText, 70, y)
            y = y + 20
        end
        
        y = y + 20
        love.graphics.print("Defence: " .. player.defence, 50, y)
        y = y + 20
        love.graphics.print("Attack: " .. player.attack, 50, y)
        y = y + 20
        love.graphics.print("Strength: " .. player.strength, 50, y)
        love.graphics.print("Available Items:", 400, 100)
        local itemY = 125
        for itemName, itemData in pairs(player.inventory.backpack) do
            local item = items[itemName]
            if item then
                love.graphics.print(itemName .. " (" .. itemData.quantity .. ")", 420, itemY)
                itemY = itemY + 20
            end
        end
    end,
    buttons = {}
}

states.woodcutting = {
    text = function ()
        love.graphics.setColor(1, 1, 1) -- White
        love.graphics.printf("Woodcutting", 0, 50, love.graphics.getWidth(), "center")
        love.graphics.print("Choose a tree to cut:", 50, 100)
        love.graphics.print("Your woodcutting level: " .. player.skills.woodcutting, 50, 120)
        
        if currentSkill == "woodcutting" and currentAction ~= "" then
            love.graphics.print("Currently cutting: " .. currentAction, 50, 140)
        end

        local totalActions = 0
        for _ in pairs(skilling.woodcutting) do totalActions = totalActions + 1 end
        local totalPages = math.ceil(totalActions / pages.skill.perPage)
        if totalPages > 1 then
            love.graphics.printf("Page " .. (pages.skill.pages.woodcutting or 1) .. " of " .. totalPages, 0, 170, love.graphics.getWidth(), "center")
        end
    end,
    buttons = {}
}

states.thieving = {
    text = function ()
        love.graphics.setColor(1, 1, 1) -- White
        love.graphics.printf("Thieving", 0, 50, love.graphics.getWidth(), "center")
        love.graphics.print("Choose a target to pickpocket:", 50, 100)
        love.graphics.print("Your thieving level: " .. player.skills.thieving, 50, 120)
        
        if currentSkill == "thieving" and currentAction ~= "" then
            love.graphics.print("Currently pickpocketing: " .. currentAction, 50, 140)
        end

        local totalActions = 0
        for _ in pairs(skilling.thieving) do totalActions = totalActions + 1 end
        local totalPages = math.ceil(totalActions / pages.skill.perPage)
        if totalPages > 1 then
            love.graphics.printf("Page " .. (pages.skill.pages.thieving or 1) .. " of " .. totalPages, 0, 170, love.graphics.getWidth(), "center")
        end
    end,
    buttons = {}
}

states.mining = {
    text = function ()
        love.graphics.setColor(1, 1, 1) -- White
        love.graphics.printf("Mining", 0, 50, love.graphics.getWidth(), "center")
        love.graphics.print("Choose a resource to mine:", 50, 100)
        love.graphics.print("Your mining level: " .. player.skills.mining, 50, 120)
        
        if currentSkill == "mining" and currentAction ~= "" then
            love.graphics.print("Currently mining: " .. currentAction, 50, 140)
        end

        local totalActions = 0
        for _ in pairs(skilling.mining) do totalActions = totalActions + 1 end
        local totalPages = math.ceil(totalActions / pages.skill.perPage)
        if totalPages > 1 then
            love.graphics.printf("Page " .. (pages.skill.pages.mining or 1) .. " of " .. totalPages, 0, 170, love.graphics.getWidth(), "center")
        end
    end,
    buttons = {}
}

states.crafting = {
    text = function ()
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("Crafting", 0, 50, love.graphics.getWidth(), "center")
        love.graphics.print("Choose a recipe to craft:", 50, 100)
        love.graphics.printf("Your coins: " .. player.inventory.coins, 0, 120, love.graphics.getWidth(), "center")
        
        local totalRecipes = 0
        for _ in pairs(recipies) do totalRecipes = totalRecipes + 1 end
        local totalPages = math.ceil(totalRecipes / pages.crafting.perPage)
        if totalPages > 1 then
            love.graphics.printf("Page " .. pages.crafting.pages .. " of " .. totalPages, 0, 140, love.graphics.getWidth(), "center")
        end
    end,
    buttons = {}
}

states.combat = {
    text = function ()
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("Combat", 0, 50, love.graphics.getWidth(), "center")
        love.graphics.print("Choose a monster to fight:", 50, 100)
        love.graphics.print("Your attack level: " .. player.skills.attack, 50, 120)
        love.graphics.print("Your defence level: " .. player.skills.defence, 50, 140)
        love.graphics.print("Health: " .. player.life.current .. "/" .. player.life.max, 50, 160)
        
        if currentTarget then
            love.graphics.print("Fighting: " .. currentTarget.name, 50, 190)
            love.graphics.print("Monster Health: " .. currentTarget.currentHealth .. "/" .. currentTarget.health, 50, 210)
        end
        
        local totalMonsters = 0
        for _ in pairs(monsters) do totalMonsters = totalMonsters + 1 end
        local totalPages = math.ceil(totalMonsters / pages.combat.perPage)
        if totalPages > 1 then
            love.graphics.printf("Page " .. pages.combat.pages .. " of " .. totalPages, 0, 230, love.graphics.getWidth(), "center")
        end
    end,
    buttons = {}
}



function checkSkillRequirement(skill, actionName)
    local skillData = skilling[skill] and skilling[skill][actionName]
    if not skillData then
        return false
    end
    
    return player.skills[skill] >= skillData.requirement
end

function updateSkillButtons(skillName)
    local skillData = skilling[skillName]
    if not skillData then return end

    if not pages.skill.pages[skillName] then
        pages.skill.pages[skillName] = 1
    end

    states[skillName].buttons = {
        {
            x = 400,
            y = 500,
            width = 120,
            height = 50,
            text = "Back to Game",
            action = function() currentState = "game" end
        }
    }

    local actionsArray = {}
    for actionName, actionData in pairs(skillData) do
        table.insert(actionsArray, {name = actionName, data = actionData})
    end
    
    local totalActions = #actionsArray
    local totalPages = math.ceil(totalActions / pages.skill.perPage)
    local currentPage = pages.skill.pages[skillName]

    local startIndex = (currentPage - 1) * pages.skill.perPage + 1
    local endIndex = math.min(startIndex + pages.skill.perPage - 1, totalActions)

    local buttonY = 200
    for i = startIndex, endIndex do
        local action = actionsArray[i]
        local newButton = {
            x = 100,
            y = buttonY,
            width = 200,
            height = 40,
            text = action.name .. " (Req: " .. action.data.requirement .. ")",
            requirement = action.data.requirement,
            skill = skillName,
        }

        if skillName == "woodcutting" then
            newButton.action = function()
                if checkSkillRequirement("woodcutting", action.name) then
                    if not tools[player.inventory.tools.axe] then
                        print("You need an axe to woodcut!")
                        return
                    end
                    currentSkill = "woodcutting"
                    currentAction = action.name
                    print("Started " .. action.name .. " woodcutting!")
                else
                    print("You need level " .. action.data.requirement .. " woodcutting!")
                end
            end
        elseif skillName == "thieving" then
            newButton.action = function()
                if checkSkillRequirement("thieving", action.name) then
                    currentSkill = "thieving"
                    currentAction = action.name
                    print("Started pickpocketing " .. action.name .. "!")
                else
                    print("You need level " .. action.data.requirement .. " thieving!")
                end
            end
        elseif skillName == "mining" then
            newButton.action = function()
                if checkSkillRequirement("mining", action.name) then
                    if not tools[player.inventory.tools.pickaxe] then
                        print("You need a pickaxe to mine!")
                        return
                    end
                    currentSkill = "mining"
                    currentAction = action.name
                    print("Started mining " .. action.name .. "!")
                else
                    print("You need level " .. action.data.requirement .. " mining!")
                end
            end
        end
        
        buttonY = buttonY + 50
        table.insert(states[skillName].buttons, newButton)
    end

    if totalPages > 1 then
        if currentPage > 1 then
            table.insert(states[skillName].buttons, {
                x = 100,
                y = 450,
                width = 80,
                height = 40,
                text = "Previous",
                action = function()
                    pages.skill.pages[skillName] = pages.skill.pages[skillName] - 1
                    updateSkillButtons(skillName)
                end
            })
        end

        if currentPage < totalPages then
            table.insert(states[skillName].buttons, {
                x = 300,
                y = 450,
                width = 80,
                height = 40,
                text = "Next",
                action = function()
                    pages.skill.pages[skillName] = pages.skill.pages[skillName] + 1
                    updateSkillButtons(skillName)
                end
            })
        end
    end
end

function createSkillButtons()
    pages.skill.pages.woodcutting = 1
    pages.skill.pages.thieving = 1
    pages.skill.pages.mining = 1

    updateSkillButtons("woodcutting")
    updateSkillButtons("thieving")
    updateSkillButtons("mining")
end

function love.load()
    love.filesystem.setIdentity("idleRPG")
    loadPlayerData()
    updateEquipmentButtons()
    createSkillButtons()
    updateCombatButtons()
    
    addChatMessage("Welcome to Idle RPG!")
    addChatMessage("Use this chat to see game messages.")
    addChatMessage("Scroll with mouse wheel over chat box.")
end

function love.update(dt)
    if currentState ~= "menu" and currentState ~= "settings" then
        timer = timer + dt
        if timer > 1 then
            timer = 0
            if currentState == "combat" then
                doCombat()
            else
                doSkill()
            end
        end
    end
    
    updateNotifications(dt)
end

function drawChatBox()
    local chatX = love.graphics.getWidth() - 410
    local chatY = love.graphics.getHeight() - 310
    local chatW = 400
    local chatH = 300
    
    -- Chat box background
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", chatX, chatY, chatW, chatH)
    love.graphics.setColor(0.3, 0.3, 0.3, 1)
    love.graphics.rectangle("line", chatX, chatY, chatW, chatH)
    
    -- Chat title
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("Chat", chatX + 5, chatY + 5)
    
    -- Chat messages
    local startY = chatY + 25
    local messageHeight = 15
    local visibleMessages = math.floor((chatH - 35) / messageHeight)
    local startIndex = math.max(1, #chatMessages - visibleMessages + 1 - chatScroll)
    
    for i = startIndex, math.min(startIndex + visibleMessages - 1, #chatMessages) do
        if chatMessages[i] then
            local y = startY + (i - startIndex) * messageHeight
            -- Wrap text if too long
            local wrappedText = chatMessages[i]
            if love.graphics.getFont():getWidth(wrappedText) > chatW - 10 then
                wrappedText = string.sub(wrappedText, 1, 30) .. "..."
            end
            love.graphics.print(wrappedText, chatX + 5, y)
        end
    end
    
    -- Scroll indicator
    if #chatMessages > visibleMessages then
        love.graphics.setColor(0.7, 0.7, 0.7, 1)
        love.graphics.print("Scroll: Mouse Wheel", chatX + 5, chatY + chatH - 15)
    end
end

function love.draw()
    local state = states[currentState]
    if state then
        for name,func in pairs(state) do
            if type(func) == "function" then
                func()
            elseif name == "buttons" then
                for _, button in ipairs(func) do
                    drawButton(button)
                end
            end
        end
    end
    if currentState ~= "menu" and currentState ~= "settings" then
        love.graphics.setColor(1, 1, 1) -- White
        love.graphics.print("Coins: " .. player.inventory.coins, 10, 10)
        if currentSkill ~= "" then
            love.graphics.print("Current Skill: " .. currentSkill .. " (" .. currentAction .. ")", 10, 30)
        end
    end
    drawNotifications()
    drawChatBox()
end

function love.wheelmoved(x, y)
    local chatX = love.graphics.getWidth() - 410
    local chatY = love.graphics.getHeight() - 310
    local chatW = 400
    local chatH = 300
    local mouseX, mouseY = love.mouse.getPosition()
    
    -- Check if mouse is over chat box
    if mouseX >= chatX and mouseX <= chatX + chatW and mouseY >= chatY and mouseY <= chatY + chatH then
        local visibleMessages = math.floor((chatH - 35) / 15)
        local maxScroll = math.max(0, #chatMessages - visibleMessages)
        chatScroll = math.max(0, math.min(maxScroll, chatScroll + y))
    end
end

function drawButton(button)
    -- Set button color based on requirements or crafting availability
    if button.requirement ~= nil then
        if button.requirement <= player.skills[button.skill] then
            love.graphics.setColor(0.7, 1, 0.7) -- Light green if meets requirement
        else
            love.graphics.setColor(1, 0.7, 0.7) -- Light red if doesn't meet requirement
        end
    elseif button.canCraft ~= nil then
        if button.canCraft then
            love.graphics.setColor(0.7, 1, 0.7) -- Light green if can craft
        else
            love.graphics.setColor(1, 0.7, 0.7) -- Light red if can't craft
        end
    elseif button.meetsRequirement ~= nil then
        if button.meetsRequirement then
            love.graphics.setColor(0.7, 1, 0.7) -- Light green if meets requirement
        else
            love.graphics.setColor(1, 0.7, 0.7) -- Light red if doesn't meet requirement
        end
    else
        love.graphics.setColor(0.7, 0.7, 0.7) -- Default light gray
    end
    
    love.graphics.rectangle("fill", button.x, button.y, button.width, button.height)
    love.graphics.setColor(0, 0, 0) -- Black border
    love.graphics.rectangle("line", button.x, button.y, button.width, button.height)
    love.graphics.setColor(0, 0, 0) -- Black text
    love.graphics.printf(button.text, button.x, button.y + button.height / 4, button.width, "center")
end

function love.mousepressed(x, y, button, istouch, presses)
    if button == 1 then -- Left mouse button
        local currentStateButtons = states[currentState].buttons
        if currentStateButtons then
            for _, btn in ipairs(currentStateButtons) do
                if x >= btn.x and x <= btn.x + btn.width and y >= btn.y and y <= btn.y + btn.height then
                    btn.action()
                    break
                end
            end
        end
    end
end

local love_errorhandler = love.errorhandler
function love.errorhandler(msg)
    if lldebugger then
        error(msg, 2)
    else
        return love_errorhandler(msg)
    end
end