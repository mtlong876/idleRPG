if arg[2] == "debug" then
    require("lldebugger").start()
end

-- Import items from items.lua
local items = require("items")
local levelupTable = require("levelup")
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
        player.inventory.backpack[itemName] = { item = item, quantity = quantity }
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
        if player.experience[skill] >= levelupTable[player.skills[skill]] then
            player.skills[skill] = player.skills[skill] + 1
            print(skill .. " leveled up to " .. player.skills[skill])
        end
        print("Added " .. amount .. " experience to " .. skill .. ". Total: " .. player.experience[skill])
    else
        print("Skill not found: " .. skill)
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
        }
    }
}

-- Settings state
states.settings = {
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

function love.load()
    
end

function love.update(dt)
    if currentState == "game" then
        timer = timer + dt
        if timer > 1 then
            timer = 0
            doSkill()
        end
    end
end

function love.draw()
    if currentState == "menu" then
        love.graphics.setColor(1, 1, 1) -- White
        love.graphics.printf("Idle RPG - Main Menu", 0, 100, love.graphics.getWidth(), "center")
        
        for _, button in ipairs(states.menu.buttons) do
            drawButton(button)
        end
        
    elseif currentState == "game" then
        love.graphics.setColor(1, 1, 1) -- White
        love.graphics.print("Coins: " .. player.inventory.coins, 10, 10)
        
        for _, button in ipairs(states.game.buttons) do
            drawButton(button)
        end
        
    elseif currentState == "settings" then
        love.graphics.setColor(1, 1, 1) -- White
        love.graphics.printf("Settings", 0, 100, love.graphics.getWidth(), "center")
        
        for _, button in ipairs(states.settings.buttons) do
            drawButton(button)
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