if arg[2] == "debug" then
    require("lldebugger").start()
end

local items = require("items")
local levelupTable = require("levelup")
local skilling = require("skilling")
local weapons = require("weapons")
local armour = require("armour")
local tools = require("tools")
local shops = require("shops")
local json = require("json")

local states = {}
local currentState = "menu"
local currentSkill = ""
local currentAction = ""
local timer = 0
local tickCount = 0
local notifications = {}
local notificationTimer = 0

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
        thieving = 1,
    },
    experience = {
        woodcutting = 0,
        thieving = 0,
    },
}

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
        local roll = math.random(baseStrength+ tickCount, data.requiredRoll)
        print(roll)
        if roll ~= data.requiredRoll then
            return
        end
    end
    print("You start woodcutting...")
    addItem(data.item, data.item_amount)
    addExperience("woodcutting", data.experience)
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
        print(roll)
        if roll ~= data.requiredRoll then
            return
        end
    end
    print("You start thieving...")
    updateCoins(data.item_amount)
    addExperience("thieving", data.experience)
    tickCount = 0
end

function addItem(itemName, quantity)
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
    
    addNotification(itemName, quantity, "center")
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
        if player.experience[skill] >= levelupTable[player.skills[skill]] then
            player.skills[skill] = player.skills[skill] + 1
            print(skill .. " leveled up to " .. player.skills[skill])
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
    local skillName = string.upper(string.sub(skill, 1, 1)) .. string.sub(skill, 2) -- Capitalize first letter
    
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
            
            local bgWidth = math.max(600, textWidth + padding * 4) -- Minimum 600px width
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
            love.graphics.setLineWidth(1) -- Reset line width
            
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
        addItem(itemName, quantity)
        print("Purchased " .. quantity .. " " .. itemName .. "(s) for " .. cost .. " coins.")
    else
        print("Not enough coins to purchase " .. itemName)
    end
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
    end
    player.inventory.tools[tool.slot] = toolName
    print("Equipped " .. toolName .. " in slot: " .. tool.slot)
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
        print("Unequipping " .. player.inventory.equipment.weapon)
    end
    
    player.inventory.equipment.weapon = weaponName
    print("Equipped " .. weaponName .. " as weapon")
    return true
end

function equipArmor(armorName)
    if not armour[armorName] then
        print("Armor not found: " .. armorName)
        return false
    end
    if not player.inventory.backpack[armorName] then
        print("You do not have a " .. armorName .. " in your backpack.")
        return false
    end
    
    local armor = armour[armorName]
    local slot = armor.slot or "shield"
    
    if player.inventory.equipment[slot] ~= "" then
        print("Unequipping " .. player.inventory.equipment[slot])
    end
    
    player.inventory.equipment[slot] = armorName
    print("Equipped " .. armorName .. " in slot: " .. slot)
    return true
end

function unequipTool(slot)
    if player.inventory.tools[slot] ~= "" then
        local toolName = player.inventory.tools[slot]
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
        player.inventory.equipment.weapon = ""
        print("Unequipped " .. weaponName)
        return true
    else
        print("No weapon equipped")
        return false
    end
end

function unequipArmor(slot)
    slot = slot or "shield"
    if player.inventory.equipment[slot] ~= "" then
        local armorName = player.inventory.equipment[slot]
        player.inventory.equipment[slot] = ""
        print("Unequipped " .. armorName)
        return true
    else
        print("No armor equipped in slot: " .. slot)
        return false
    end
end

function doSkill()
    if currentSkill == "woodcutting" then
        if not tools[player.inventory.tools.axe] then
            print("You need an axe to woodcut!")
            currentSkill = ""
            return
        end
        woodcuttingActions(currentAction)
    elseif currentSkill == "thieving" then
        thievingActions(currentAction)
    else
        return
    end
    tickCount = tickCount + 1
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
                        equipArmor(itemName)
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
                        unequipArmor(slot)
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
            action = function() currentState = "woodcutting" end
        },
        {
            x = 100,
            y = 200,
            width = 100,
            height = 50,
            text = "Thieving",
            action = function() currentState = "thieving" end
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
            action = function() currentState = "basicShop" end
        },
        {
            x = 300,
            y = 280,
            width = 200,
            height = 60,
            text = "Back to Game",
            action = function() currentState = "game" end
        },
    }
}

for shopName,shop in pairs(shops) do
    states[shopName] = {
        text = function ()
            love.graphics.setColor(1, 1, 1) -- White
            love.graphics.printf(shop.name, 0, 100, love.graphics.getWidth(), "center")
            love.graphics.printf(shop.description, 0, 150, love.graphics.getWidth(), "center")
        end,
        buttons = {
            {
                x = 300,
                y = 400,
                width = 200,
                height = 60,
                text = "Back to Shops",
                action = function() currentState = "shops" end
            }
        }
    }
    local y = 200
    for itemName, price in pairs(shop.items) do
        local newButton = {
            x = 300,
            y = y,
            width = 200,
            height = 40,
            text = itemName .. ": " .. price .. " coins",
            action = function()
                purchaseItem(shopName, itemName, 1)
            end
        }
        y= y + 50
        table.insert(states[shopName].buttons, newButton)
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
        love.graphics.print("Available Items:", 400, 100)
        local itemY = 125
        for itemName, itemData in pairs(player.inventory.backpack) do
            local item = items[itemName]
            if item and (item.type == "weapon" or item.type == "armour" or item.type == "tool") then
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

function createSkillButtons()
    states.woodcutting.buttons = {
        {
            x = 400,
            y = 400,
            width = 120,
            height = 50,
            text = "Back to Game",
            action = function() currentState = "game" end
        }
    }
    
    local buttonY = 200
    for actionName, actionData in pairs(skilling.woodcutting) do
        table.insert(states.woodcutting.buttons, {
            x = 100,
            y = buttonY,
            width = 200,
            height = 40,
            text = actionName .. " (Req: " .. actionData.requirement .. ")",
            action = function()
                if checkSkillRequirement("woodcutting", actionName) then
                    if not tools[player.inventory.tools.axe] then
                        print("You need an axe to woodcut!")
                        return
                    end
                    currentSkill = "woodcutting"
                    currentAction = actionName
                    print("Started " .. actionName .. " woodcutting!")
                else
                    print("You need level " .. actionData.requirement .. " woodcutting!")
                end
            end,
            requirement = actionData.requirement,
            skill = "woodcutting",
        })
        buttonY = buttonY + 50
    end
    
    states.thieving.buttons = {
        {
            x = 400,
            y = 400,
            width = 120,
            height = 50,
            text = "Back to Game",
            action = function() currentState = "game" end
        }
    }
    
    buttonY = 200
    for actionName, actionData in pairs(skilling.thieving) do

        table.insert(states.thieving.buttons, {
            x = 100,
            y = buttonY,
            width = 200,
            height = 40,
            text = actionName .. " (Req: " .. actionData.requirement .. ")",
            action = function() 
                if checkSkillRequirement("thieving", actionName) then
                    currentSkill = "thieving"
                    currentAction = actionName
                    print("Started pickpocketing " .. actionName .. "!")
                else
                    print("You need level " .. actionData.requirement .. " thieving!")
                end
            end,
            requirement = actionData.requirement,
            skill = "thieving",
            
        })
        buttonY = buttonY + 50
    end
end

function love.load()
    love.filesystem.setIdentity("idleRPG")
    updateEquipmentButtons()
    createSkillButtons()  
end

function love.update(dt)
    if currentState ~= "menu" and currentState ~= "settings" then
        timer = timer + dt
        if timer > 1 then
            timer = 0
            doSkill()
        end
    end
    
    updateNotifications(dt)
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
    end
    drawNotifications()
end

function drawButton(button)
    if button.requirement ~= nil then
        if button.requirement <= player.skills[button.skill] then
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