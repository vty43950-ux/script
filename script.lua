local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

-- URL API
local API_URL = "https://zenithghz.qzz.io/api/update"

-------------------------------------------------------------------------------
-- CONFIG & WHITELISTS (WIKI UPDATED)
-------------------------------------------------------------------------------
local SEED_WHITELIST = {
    -- Standard
    "carrot", "corn", "onion", "strawberry", "mushroom", "beetroot", "tomato", 
    "apple", "rose", "wheat", "banana", "plum", "potato", "cabbage", "cherry", 
    "bamboo", "mango", "pineapple", "watermelon", "carrot seed", "corn seed", "onion seed", "strawberry seed", "mushroom seed", "beetroot seed", "tomato seed", 
    "apple seed", "rose seed", "wheat seed", "banana seed", "plum seed", "potato seed", "cabbage seed", "cherry seed", 
    "bamboo seed", "mango seed", "pineapple seed", "watermelon seed"
}

local GEAR_WHITELIST = {
    "watering can", "basic sprinkler", "harvest bell", "turbo sprinkler",
    "favorite tool", "super sprinkler", "trowel", "harvest hand",
    "godly sprinkler", "ultra sprinkler", "shovel", "scythe", "hoe", "rake",
    "reverter", "recall wrench"
}

local STRICT_ITEMS = { "mushroom" }

-------------------------------------------------------------------------------
-- UI SETUP (WAIT FOR LOAD)
-------------------------------------------------------------------------------
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui", 20)
local uiLayer = (gethui and gethui()) or (CoreGui:FindFirstChild("RobloxGui")) or CoreGui or PlayerGui

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "GHZ_Stable_UI"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 999
if uiLayer:FindFirstChild("GHZ_Stable_UI") then uiLayer["GHZ_Stable_UI"]:Destroy() end
screenGui.Parent = uiLayer

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 250, 0, 100)
mainFrame.Position = UDim2.new(0, 10, 0, 50)
mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
mainFrame.BackgroundTransparency = 0.3
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screenGui

Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 8)

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -20, 0, 30)
statusLabel.Position = UDim2.new(0, 10, 0, 5)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "🌱 GHZ Tracker v2.1"
statusLabel.TextColor3 = Color3.fromRGB(150, 255, 150)
statusLabel.Font = Enum.Font.GothamBold
statusLabel.TextSize = 14
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Parent = mainFrame

local infoLabel = Instance.new("TextLabel")
infoLabel.Size = UDim2.new(1, -20, 0, 50)
infoLabel.Position = UDim2.new(0, 10, 0, 35)
infoLabel.BackgroundTransparency = 1
infoLabel.Text = "Status: Calculating restock..."
infoLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
infoLabel.Font = Enum.Font.Gotham
infoLabel.TextSize = 12
infoLabel.TextXAlignment = Enum.TextXAlignment.Left
infoLabel.TextYAlignment = Enum.TextYAlignment.Top
infoLabel.Parent = mainFrame

local function updateUI(status, info, color)
    if status then statusLabel.Text = status end
    if info then infoLabel.Text = info end
    if color then statusLabel.TextColor3 = color end
end

-------------------------------------------------------------------------------
-- UTILS
-------------------------------------------------------------------------------
local function isPrice(text)
    local t = string.lower(text)
    if string.find(t, "shilling") or string.find(t, "coin") or string.find(t, "$") then return true end
    local n = tonumber(string.match(text, "^%d+$"))
    return n and n >= 500
end

local function extractQty(text)
    local lt = string.lower(text)
    if string.find(lt, "stock") or string.find(lt, "left") or string.find(lt, "remain") then
        local n = string.match(text, "(%d+)")
        return tonumber(n)
    end
    return nil
end

-------------------------------------------------------------------------------
-- SCANNING CORE (ENHANCED v2.1)
-------------------------------------------------------------------------------
local function scanAll()
    local seeds, gear = {}, {}
    local weather = { status = "None", duration = 0 }
    local seen = {}

    -- Scan Weather
    local wKeywords = {"starfall", "meteor", "storm", "rain", "snow", "mowis", "sandstorm"}
    for _, obj in pairs(PlayerGui:GetDescendants()) do
        if obj:IsA("TextLabel") and obj.Visible then
            local t = string.lower(obj.Text)
            for _, kw in ipairs(wKeywords) do
                if string.find(t, kw) then
                    weather.status = obj.Text
                    -- Try to find duration (00:00) in same container
                    local root = obj.Parent
                    for _, d in pairs(root:GetDescendants()) do
                        if d:IsA("TextLabel") and d.Visible and string.find(d.Text, ":") then
                            local m, s = string.match(d.Text, "(%d+):(%d+)")
                            if m and s then weather.duration = tonumber(m)*60 + tonumber(s) break end
                        end
                    end
                    break
                end
            end
        end
    end

    -- Scan Shop Items
    for _, obj in pairs(PlayerGui:GetDescendants()) do
        if obj:IsA("TextLabel") and obj.Visible and string.len(obj.Text) > 3 then
            local rawName = obj.Text
            local lowName = string.lower(rawName)
            
            -- Check if this is an item name
            local cat = nil
            for _, s in ipairs(SEED_WHITELIST) do if string.find(lowName, s) then cat = "seed" break end end
            if not cat then for _, g in ipairs(GEAR_WHITELIST) do if string.find(lowName, g) then cat = "gear" break end end end
            
            if cat and not seen[rawName] then
                -- Broad search for Card (find the container that holds both name and info)
                local card = obj.Parent
                if card:IsA("Frame") or card:IsA("ImageLabel") or card:IsA("TextButton") then
                    -- If the parent is just a small wrapper, look one level higher
                    if card.Parent and (card.Parent:IsA("Frame") or card.Parent:IsA("ScrollingFrame")) then
                        card = card.Parent
                    end
                end
                
                local qty = nil
                local img = ""
                local labels = {}
                
                -- Look inside the card and its children for info
                for _, child in pairs(card:GetDescendants()) do
                    if child:IsA("TextLabel") and child.Visible and child.Text ~= "" then
                        table.insert(labels, child.Text)
                        local q = extractQty(child.Text)
                        if q then qty = q end
                    elseif child:IsA("ImageLabel") and child.Visible and img == "" then
                        local id = string.match(child.Image, "%d+")
                        if id then img = "https://www.roblox.com/asset-thumbnail/image?assetId=" .. id .. "&width=420&height=420&format=png" end
                    end
                end
                
                -- Fallback for non-strict items (just look for a small number)
                local isStrictItem = false
                for _, s in ipairs(STRICT_ITEMS) do if string.find(lowName, s) then isStrictItem = true break end end
                
                if not qty and not isStrictItem then
                    for _, l in ipairs(labels) do
                        local n = tonumber(string.match(l, "^%d+$"))
                        if n and n > 0 and n < 100 then qty = n break end
                    end
                end
                
                if qty then
                    seen[rawName] = true
                    local entry = {name = rawName, quantity = qty, category = cat, image = img}
                    if cat == "seed" then table.insert(seeds, entry) else table.insert(gear, entry) end
                    print("[GHZ] Found " .. cat .. ": " .. rawName .. " (x" .. qty .. ")")
                end
            end
        end
    end

    return seeds, gear, weather
end

-------------------------------------------------------------------------------
-- MAIN LOOP
-------------------------------------------------------------------------------
local function post()
    updateUI(nil, "Status: Scanning...", Color3.fromRGB(255, 200, 100))
    local ok, seeds, gear, weather = pcall(scanAll)
    
    if not ok then
        updateUI(nil, "Status: Scan Error!", Color3.fromRGB(255, 0, 0))
        warn("[GHZ] Scan Error: " .. tostring(seeds))
        return
    end
    
    if #seeds == 0 and #gear == 0 then
        updateUI(nil, "Status: No Items Found", Color3.fromRGB(180, 180, 180))
        return
    end

    local payload = { seeds = seeds, gear = gear, weather = weather, timestamp = os.time() }
    local req = (syn and syn.request) or (http and http.request) or request
    if not req then warn("No Request Support") return end

    pcall(function()
        req({
            Url = API_URL,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode(payload)
        })
    end)
    updateUI(nil, "Status: API Post Success!", Color3.fromRGB(130, 255, 130))
end

task.spawn(function()
    print("[GHZ] Script v2.0 Starting")
    post()
    while true do
        local now = os.time()
        local target = now + (300 - (now % 300)) + 2
        while os.time() < target do
            local rem = target - os.time()
            updateUI(nil, string.format("Next Restock: %02d:%02d\nAPI: Waiting cycle...", math.floor(rem/60), rem%60))
            task.wait(1)
        end
        print("[GHZ] Cycle triggered!")
        post()
        task.wait(5)
    end
end)
