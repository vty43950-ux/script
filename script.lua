local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

-- URL API
local API_URL = "https://zenithghz.qzz.io/api/update"

-------------------------------------------------------------------------------
-- CONFIG (v3.0 OPEN SCANNER)
-------------------------------------------------------------------------------
-- Whitelists removed for broad detection.
-- Specific items that still need "Stock" keywords to avoid ghost numbers:
local STRICT_ITEMS = { "mushroom", "fertile soil", "harvest hand" }
local JUNK_WORDS = { "inventory", "owned", "earned", "quest", "hud", "hotbar", "bag" }

-------------------------------------------------------------------------------
-- UI SETUP
-------------------------------------------------------------------------------
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui", 20)
local uiLayer = (gethui and gethui()) or (CoreGui:FindFirstChild("RobloxGui")) or CoreGui or PlayerGui

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "GHZ_v3_UI"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 9999
if uiLayer:FindFirstChild("GHZ_v3_UI") then uiLayer["GHZ_v3_UI"]:Destroy() end
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
statusLabel.Text = "🌱 GHZ Tracker v3.0"
statusLabel.TextColor3 = Color3.fromRGB(150, 255, 150)
statusLabel.Font = Enum.Font.GothamBold
statusLabel.TextSize = 13
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Parent = mainFrame

local infoLabel = Instance.new("TextLabel")
infoLabel.Size = UDim2.new(1, -20, 0, 50)
infoLabel.Position = UDim2.new(0, 10, 0, 35)
infoLabel.BackgroundTransparency = 1
infoLabel.Text = "Status: Running Safe Scan..."
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
-- LOGIC
-------------------------------------------------------------------------------
local function getFullPath(obj)
    local p = obj.Name
    local parent = obj.Parent
    while parent and parent ~= game do
        p = parent.Name .. "/" .. p
        parent = parent.Parent
    end
    return string.lower(p)
end

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

local function scanAll()
    local seeds, gear = {}, {}
    local weather = { status = "None", duration = 0 }
    local seen = {}

    -- 1. Scan everything broad
    for _, obj in pairs(PlayerGui:GetDescendants()) do
        if not obj:IsA("TextLabel") or not obj.Visible or string.len(obj.Text) <= 2 then continue end
        
        local path = getFullPath(obj)
        local isJunk = false
        for _, j in ipairs(JUNK_WORDS) do if string.find(path, j) then isJunk = true break end end
        if isJunk then continue end

        local txt = obj.Text
        local low = string.lower(txt)

        -- Weather
        local wKeywords = {"starfall", "meteor", "storm", "rain", "snow", "mowis"}
        for _, kw in ipairs(wKeywords) do
            if string.find(low, kw) then
                weather.status = txt
                break
            end
        end

        -- Shop Extraction
        local isShopItem = string.find(path, "shop") or string.find(path, "bill") or string.find(path, "molly") or string.find(path, "store")
        
        if isShopItem and not seen[txt] and not isPrice(txt) then
            -- Climbing to Card
            local current = obj.Parent
            local qty, img = nil, ""
            local card = nil
            
            for i = 1, 4 do
                if not current or not current:IsA("GuiObject") then break end
                if #current:GetChildren() >= 2 then
                    card = current
                    local labels = {}
                    local soldOut = false
                    for _, child in pairs(card:GetDescendants()) do
                        if child:IsA("TextLabel") and child.Visible and child.Text ~= "" then
                            local ct = string.lower(child.Text)
                            if string.find(ct, "sold out") or string.find(ct, "no stock") then soldOut = true break end
                            table.insert(labels, child.Text)
                        elseif child:IsA("ImageLabel") and child.Visible and img == "" then
                            local id = string.match(child.Image, "%d+")
                            if id then img = "https://www.roblox.com/asset-thumbnail/image?assetId=" .. id .. "&width=420&height=420&format=png" end
                        end
                    end
                    
                    if not soldOut then
                        local force = false
                        for _, s in ipairs(STRICT_ITEMS) do if string.find(low, s) then force = true break end end
                        for _, l in ipairs(labels) do
                            qty = extractQty(l, force)
                            if qty then break end
                        end
                    end
                    if qty then break end
                end
                current = current.Parent
            end

            if qty and qty > 0 then
                seen[txt] = true
                local cat = "seed"
                if string.find(path, "gear") or string.find(path, "molly") or string.find(low, "hand") or string.find(low, "tool") then
                    cat = "gear"
                end
                local entry = {name = txt, quantity = qty, category = cat, image = img}
                if cat == "seed" then table.insert(seeds, entry) else table.insert(gear, entry) end
                print("[GHZ v3] Verified " .. cat .. ": " .. txt .. " x" .. qty)
            end
        end
    end
    return seeds, gear, weather
end

local function postData(retried)
    updateUI("Status: Scanning Shops...", Color3.fromRGB(255, 200, 100))
    local ok, seeds, gear, weather = pcall(scanAll)
    
    if not ok or (#seeds == 0 and #gear == 0) then
        updateUI("Status: Items not found.", Color3.fromRGB(180, 180, 180))
        return
    end

    local payload = { seeds = seeds, gear = gear, weather = weather, timestamp = os.time() }
    local req = (syn and syn.request) or (http and http.request) or request
    if not req then return end

    local ok_post = pcall(function()
        req({
            Url = API_URL,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode(payload)
        })
    end)

    if ok_post then
        updateUI("Status: Synced (v3.0)", Color3.fromRGB(130, 255, 130))
        print("[GHZ v3] Synced " .. #seeds + #gear .. " items.")
    elseif not retried then
        task.wait(2)
        postData(true)
    end
end

task.spawn(function()
    print("[GHZ v3.0] Scanner Ready.")
    postData()
    while true do
        local now = os.time()
        local target = now + (300 - (now % 300)) + 3
        while os.time() < target do
            local rem = target - os.time()
            updateUI(string.format("Next Update: %02d:%02d\nAPI: Monitoring...", math.floor(rem/60), rem%60))
            task.wait(1)
        end
        postData()
        task.wait(10)
    end
end)
