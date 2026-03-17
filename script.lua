local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

-- URL API
local API_URL = "https://zenithghz.qzz.io/api/update"

-------------------------------------------------------------------------------
-- CONFIG & WHITELISTS
-------------------------------------------------------------------------------
local SEED_WHITELIST = {
    "carrot", "corn", "onion", "potato", "tomato", "strawberry", "blueberry",
    "grape", "wheat", "pumpkin", "watermelon", "mushroom", "apple", "orange",
    "lemon", "cherry", "pear", "pineapple", "coconut", "mango", "peach",
    "pepper", "eggplant", "sunflower", "bamboo", "cactus", "rose", "tulip",
    "lily", "daisy", "orchid", "lavender", "beanstalk", "dragonfruit",
    "seed", "sprout", "fertile soil" -- Fix categorization
}

local GEAR_WHITELIST = {
    "basic sprinkler", "advanced sprinkler", "godly sprinkler",
    "super sprinkler", "ultra sprinkler",
    "watering can", "trowel", "shovel", "scythe", "hoe", "rake",
    "reverter", "favorite tool", "recall wrench",
    "harvest hand", "basket", "pitchfork"
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
statusLabel.Text = "🌱 GHZ Tracker v2.0"
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
-- SCANNING
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
                    -- Try to find duration in parent
                    for _, d in pairs(obj.Parent:GetChildren()) do
                        if d:IsA("TextLabel") and string.find(d.Text, ":") then
                            local m, s = string.match(d.Text, "(%d+):(%d+)")
                            if m and s then weather.duration = tonumber(m)*60 + tonumber(s) end
                        end
                    end
                    break
                end
            end
        end
    end

    -- Scan Shop
    local BLACKLIST = {"level", "owned", "rank", "prestige", "quest", "inventory", "shop"}
    for _, container in pairs(PlayerGui:GetDescendants()) do
        if (container:IsA("ScrollingFrame") or container:IsA("Frame")) and 
           (container:FindFirstChildWhichIsA("UIGridLayout") or container:FindFirstChildWhichIsA("UIListLayout")) then
            
            for _, card in pairs(container:GetChildren()) do
                if card:IsA("GuiObject") and #card:GetChildren() > 2 then
                    local labels = {}
                    local img = ""
                    local junk = false
                    
                    for _, c in pairs(card:GetDescendants()) do
                        if c:IsA("TextLabel") and c.Visible and c.Text ~= "" then
                            local lt = string.lower(c.Text)
                            for _, b in ipairs(BLACKLIST) do if string.find(lt, b) then junk = true break end end
                            table.insert(labels, c.Text)
                        elseif c:IsA("ImageLabel") and img == "" then
                            local id = string.match(c.Image, "%d+")
                            if id then img = "https://www.roblox.com/asset-thumbnail/image?assetId=" .. id .. "&width=420&height=420&format=png" end
                        end
                    end
                    
                    if not junk and #labels >= 2 then
                        local name, qty = "", nil
                        -- Find Name
                        for _, l in ipairs(labels) do
                            if not isPrice(l) and not tonumber(l) and string.len(l) > 3 then
                                if string.len(l) > string.len(name) then name = l end
                            end
                        end
                        -- Find Qty
                        for _, l in ipairs(labels) do
                            local q = extractQty(l)
                            if q then qty = q break end
                        end
                        -- Fallback Qty
                        local isStrictItem = false
                        for _, s in ipairs(STRICT_ITEMS) do if string.find(string.lower(name), s) then isStrictItem = true break end end
                        
                        if not qty and not isStrictItem then
                            for _, l in ipairs(labels) do
                                local n = tonumber(string.match(l, "^%d+$"))
                                if n and n > 0 and n < 100 then qty = n break end
                            end
                        end
                        
                        if name ~= "" and qty and not seen[name] then
                            seen[name] = true
                            local cat = nil
                            local ln = string.lower(name)
                            for _, s in ipairs(SEED_WHITELIST) do if string.find(ln, s) then cat = "seed" break end end
                            if not cat then for _, g in ipairs(GEAR_WHITELIST) do if string.find(ln, g) then cat = "gear" break end end end
                            
                            if cat then
                                local entry = {name = name, quantity = qty, category = cat, image = img}
                                if cat == "seed" then table.insert(seeds, entry) else table.insert(gear, entry) end
                            end
                        end
                    end
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
    updateUI(nil, "Status: Scanning Shop...", Color3.fromRGB(255, 200, 100))
    local seeds, gear, weather = scanAll()
    
    if #seeds == 0 and #gear == 0 then
        updateUI(nil, "Status: No Shop Open!", Color3.fromRGB(255, 100, 100))
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
    updateUI(nil, "Status: API Updated!", Color3.fromRGB(150, 255, 150))
    print("[GHZ] Posted " .. #seeds + #gear .. " items.")
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
