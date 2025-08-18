if arg[2] == "debug" then
    require("lldebugger").start()
end

-- Import items from items.lua
local items = require("items")
local levelupTable = require("levelup")
local weapons = require("weapons")
local shops = require("shops")
local json = require("json")
-- State management
local states = {}
local currentState = "menu"
local currentSkill = ""
local currentAction = ""
local timer = 0
local tickCount = 0
-- Player data
local player = {
    inventory = {
        coins = 0,
        backpack = {}
    },
    skills = {
        Woodcutting = 1,
        thieving = 1,
    },
    experience = {
        Woodcutting = 0,
        thieving = 0,
    },
}

local woodcuttingActions = {
    ["regular"] = function()
        if tickCount < 5 then
            return
        end
        print("You start woodcutting...")
        addItem("wood", 1)
        player.experience.Woodcutting = player.experience.Woodcutting + 101
        tickCount = 0
    end,
}

local thievingActions = {
    ["man"] = function()
        if tickCount < 5 then
            return
        end
        print("You start thieving...")
        updateCoins(5)
        player.experience.thieving = player.experience.thieving + 5
        tickCount = 0
    end,
}

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
end

function addExperience(skill, amount)
    if player.experience[skill] then
        player.experience[skill] = player.experience[skill] + amount
        print(skill .. player.skills[skill] .. levelupTable[player.skills[skill]])
        if player.experience[skill] >= levelupTable[player.skills[skill]] then
            player.skills[skill] = player.skills[skill] + 1
            print(skill .. " leveled up to " .. player.skills[skill])
        end
        print("Added " .. amount .. " experience to " .. skill .. ". Total: " .. player.experience[skill])
    else
        print("Skill not found: " .. skill)
    end
end

-- JSON Save/Load Functions
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
        
        -- Decode JSON and load into player table
        local success, loadedData = pcall(json.decode, jsonString)
        if success and loadedData then
            -- Merge loaded data into player table
            if loadedData.inventory then
                player.inventory.coins = loadedData.inventory.coins or 0
                player.inventory.backpack = loadedData.inventory.backpack or {}
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

function doSkill()
    if currentSkill == "woodcutting" then
        if woodcuttingActions[currentAction] then
            woodcuttingActions[currentAction]()
        else
            print("No action defined for woodcutting: " .. currentSkill)
        end
    elseif currentSkill == "thieving" then
        if thievingActions[currentAction] then
            thievingActions[currentAction]()
        else
            print("No action defined for thieving: " .. currentSkill)
        end
    else
        print("Unknown skill: " .. currentSkill)
    end
    tickCount = tickCount + 1
end

-- Menu state
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

-- Game state
states.game = {
    text = function ()
        love.graphics.setColor(1, 1, 1) -- White
        love.graphics.print("Coins: " .. player.inventory.coins, 10, 10)
    end,
    buttons = {
        {
            x = 100,
            y = 100,
            width = 100,
            height = 50,
            text = "Start Woodcutting",
            action = function() currentSkill = "woodcutting" currentAction = "regular" end
        },
        {
            x = 100,
            y = 200,
            width = 100,
            height = 50,
            text = "Start Thieving",
            action = function() currentSkill = "thieving" currentAction = "man" end
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
        }
    }
}

-- Settings state
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

function love.load()
    love.filesystem.setIdentity("idleRPG") 
end

function love.update(dt)
    if currentState ~= "menu" and currentState ~= "settings" then
        timer = timer + dt
        if timer > 1 then
            timer = 0
            doSkill()
        end
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
end

function drawButton(button)
    love.graphics.setColor(0.7, 0.7, 0.7) -- Light gray
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