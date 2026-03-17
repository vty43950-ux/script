local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

-- URL API
local API_URL = "https://zenithghz.qzz.io/api/update"

-------------------------------------------------------------------------------
-- CONFIG & WHITELISTS (v2.5 MASSIVE UPDATE)
-------------------------------------------------------------------------------
local SEED_WHITELIST = {
    -- Basic
    "carrot", "corn", "onion", "strawberry", "mushroom", "beetroot", "tomato", 
    "apple", "rose", "wheat", "banana", "plum", "potato", "cabbage", "cherry", 
    "bamboo", "mango"
}

local GEAR_WHITELIST = {
    "watering can", "basic sprinkler", "harvest bell", "turbo sprinkler",
    "favorite tool", "super sprinkler", "trowel",
    "godly sprinkler"
}

-- Force specific category irrespective of name
local OVERRIDE_SEED = { "fertile soil" }
local OVERRIDE_GEAR = { "harvest hand" }

-- Items that MUST have the word "Stock" or "Left" to avoid ghost numbers (like x5)
local STRICT_ITEMS = { "Mushroom Seed", "fertile soil", "harvest hand", "Total Shoveled" }

-------------------------------------------------------------------------------
-- UI SETUP
-------------------------------------------------------------------------------
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui", 20)
local uiLayer = (gethui and gethui()) or (CoreGui:FindFirstChild("RobloxGui")) or CoreGui or PlayerGui

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "GHZ_v2.5_UI"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 9999
if uiLayer:FindFirstChild("GHZ_v2.5_UI") then uiLayer["GHZ_v2.5_UI"]:Destroy() end
screenGui.Parent = uiLayer

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 250, 0, 100)
mainFrame.Position = UDim2.new(0, 10, 0, 100)
mainFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
mainFrame.BackgroundTransparency = 0.2
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screenGui
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 8)

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -20, 0, 30)
statusLabel.Position = UDim2.new(0, 10, 0, 5)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "🌱 GHZ Tracker v2.5"
statusLabel.TextColor3 = Color3.fromRGB(150, 255, 150)
statusLabel.Font = Enum.Font.GothamBold
statusLabel.TextSize = 13
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Parent = mainFrame

local infoLabel = Instance.new("TextLabel")
infoLabel.Size = UDim2.new(1, -20, 0, 50)
infoLabel.Position = UDim2.new(0, 10, 0, 35)
infoLabel.BackgroundTransparency = 1
infoLabel.Text = "Status: Waiting for first scan..."
infoLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
infoLabel.Font = Enum.Font.Gotham
infoLabel.TextSize = 11
infoLabel.TextXAlignment = Enum.TextXAlignment.Left
infoLabel.TextYAlignment = Enum.TextYAlignment.Top
infoLabel.Parent = mainFrame

local function updateUI(info, color)
    if info then infoLabel.Text = info end
    if color then statusLabel.TextColor3 = color end
end

-------------------------------------------------------------------------------
-- HELPERS
-------------------------------------------------------------------------------
local function isPrice(text)
    local t = string.lower(text)
    if string.find(t, "shilling") or string.find(t, "coin") or string.find(t, "$") then return true end
    local n = tonumber(string.match(text, "^%d+$"))
    return n and n >= 500
end

local function extractQty(text, forceKeyword)
    local lt = string.lower(text)
    local hasKeyword = string.find(lt, "stock") or string.find(lt, "left") or string.find(lt, "remain")
    if hasKeyword then
        local n = string.match(text, "(%d+)")
        return tonumber(n)
    end
    if not forceKeyword then
        local xNum = string.match(text, "x(%d+)")
        if xNum then return tonumber(xNum) end
        local plainNum = tonumber(string.match(text, "^%s*(%d+)%s*$"))
        if plainNum and plainNum > 0 and plainNum < 500 then return plainNum end
    end
    return nil
end

-------------------------------------------------------------------------------
-- RECURSIVE SCAN ENGINE (v2.5)
-------------------------------------------------------------------------------
local function scanAll()
    local seeds, gear = {}, {}
    local weather = { status = "None", duration = 0 }
    local seen = {}

    local wKeywords = {"starfall", "meteor", "storm", "rain", "snow", "mowis", "sandstorm"}
    for _, obj in pairs(PlayerGui:GetDescendants()) do
        if not obj:IsA("TextLabel") or not obj.Visible then continue end
        local txt = obj.Text
        local low = string.lower(txt)

        -- 1. Weather Detect
        for _, kw in ipairs(wKeywords) do
            if string.find(low, kw) then
                weather.status = txt
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

        -- 2. Item Mining
        local category = nil
        for _, s in ipairs(SEED_WHITELIST) do if string.find(low, s) then category = "seed" break end end
        if not category then for _, g in ipairs(GEAR_WHITELIST) do if string.find(low, g) then category = "gear" break end end end
        
        -- Override specific items
        for _, s in ipairs(OVERRIDE_SEED) do if string.find(low, s) then category = "seed" end end
        for _, s in ipairs(OVERRIDE_GEAR) do if string.find(low, s) then category = "gear" end end

        if category and not seen[txt] and string.len(txt) > 3 then
            -- Find the Container (Ancestry Mining)
            local current = obj.Parent
            local infoFrame = nil
            local qty, img = nil, ""
            
            -- Go up until we find a frame with more than 2 children (likely the Card)
            for i = 1, 5 do
                if not current or not current:IsA("GuiObject") then break end
                if #current:GetChildren() >= 2 then
                    infoFrame = current
                    -- Check if it contains a quantity and image
                    for _, child in pairs(infoFrame:GetDescendants()) do
                        if child:IsA("TextLabel") and child.Visible and child.Text ~= "" then
                            local force = false
                            for _, s in ipairs(STRICT_ITEMS) do if string.find(low, s) then force = true break end end
                            if not isPrice(child.Text) then
                                local q = extractQty(child.Text, force)
                                if q then qty = q end
                            end
                        elseif child:IsA("ImageLabel") and child.Visible and img == "" then
                            local id = string.match(child.Image, "%d+")
                            if id then img = "https://www.roblox.com/asset-thumbnail/image?assetId=" .. id .. "&width=420&height=420&format=png" end
                        end
                    end
                end
                if qty then break end
                current = current.Parent
            end
            
            if qty and qty > 0 then
                seen[txt] = true
                local entry = {name = txt, quantity = qty, category = category, image = img}
                if category == "seed" then table.insert(seeds, entry) else table.insert(gear, entry) end
                print("[GHZ v2.5] Verified: " .. txt .. " x" .. qty)
            end
        end
    end
    return seeds, gear, weather
end

local function postData(retried)
    updateUI("Status: Mining Data...", Color3.fromRGB(255, 200, 100))
    local ok, seeds, gear, weather = pcall(scanAll)
    
    if not ok or (#seeds == 0 and #gear == 0) then
        updateUI("Status: Shop not detected.", Color3.fromRGB(180, 180, 180))
        return
    end

    local payload = { seeds = seeds, gear = gear, weather = weather, timestamp = os.time() }
    local req = (syn and syn.request) or (http and http.request) or request
    if not req then return end

    local ok_post, resp = pcall(function()
        return req({
            Url = API_URL,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode(payload)
        })
    end)

    if ok_post then
        updateUI("Status: Synced (OK)", Color3.fromRGB(130, 255, 130))
        print("[GHZ v2.5] API Sync Success: " .. #seeds + #gear .. " items found.")
    elseif not retried then
        updateUI("Status: Retrying API...", Color3.fromRGB(255, 150, 50))
        task.wait(5)
        postData(true)
    else
        updateUI("Status: API Error!", Color3.fromRGB(255, 50, 50))
    end
end

-------------------------------------------------------------------------------
-- MAIN EXECUTION
-------------------------------------------------------------------------------
task.spawn(function()
    print("[GHZ v2.5] Loaded Successfully.")
    postData()
    while true do
        local now = os.time()
        local target = now + (300 - (now % 300)) + 3 -- Fire 3s after restock
        while os.time() < target do
            local rem = target - os.time()
            updateUI(string.format("Next Update: %02d:%02d\nAPI: Listening...", math.floor(rem/60), rem%60))
            task.wait(1)
        end
        postData()
        task.wait(10)
    end
end)
