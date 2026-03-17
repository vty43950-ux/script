print("[GHZ] 🟢 Script loading...")

local function getServiceSafe(name)
    local ok, service = pcall(function() return game:GetService(name) end)
    return ok and service or nil
end

local HttpService = getServiceSafe("HttpService")
local Players = getServiceSafe("Players")
local CoreGui = getServiceSafe("CoreGui")

print("[GHZ] 📦 Services loaded")

-- API URL
local API_URL = "https://zenithghz.qzz.io/api/update"

-------------------------------------------------------------------------------
-- CHỜ LOCALPLAYER & PLAYERGUI (Failsafe)
-------------------------------------------------------------------------------
local LocalPlayer = Players.LocalPlayer
for i = 1, 10 do
    if LocalPlayer then break end
    print("[GHZ] ⏳ Waiting for LocalPlayer... (" .. i .. ")")
    task.wait(1)
    LocalPlayer = Players.LocalPlayer
end

if not LocalPlayer then
    warn("[GHZ] ❌ LocalPlayer not found! Script stopping.")
    return
end

local PlayerGui = LocalPlayer:WaitForChild("PlayerGui", 20)
if not PlayerGui then
    warn("[GHZ] ❌ PlayerGui not found!")
end

print("[GHZ] 👤 Player found: " .. LocalPlayer.Name)

-------------------------------------------------------------------------------
-- GIAO DIỆN (UI) THÔNG BÁO - Resilient Selection
-------------------------------------------------------------------------------
local uiLayer = nil
local ok_ui, err_ui = pcall(function()
    uiLayer = (gethui and gethui()) or (CoreGui and CoreGui:FindFirstChild("RobloxGui")) or CoreGui or PlayerGui
end)

if not uiLayer then
    warn("[GHZ] ❌ Could not find a valid UI Layer: " .. tostring(err_ui))
    uiLayer = PlayerGui
end

print("[GHZ] 🖼 UI Layer selected: " .. (uiLayer and uiLayer.Name or "Unknown"))

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "GHZ_Tracker_UI"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder = 999999
screenGui.IgnoreGuiInset = true

if uiLayer:FindFirstChild("GHZ_Tracker_UI") then
    uiLayer["GHZ_Tracker_UI"]:Destroy()
end

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 250, 0, 100)
mainFrame.Position = UDim2.new(0, 10, 0, 40)
mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
mainFrame.BorderSizePixel = 0
mainFrame.BackgroundTransparency = 0.2
mainFrame.Parent = mainFrame -- Placeholder

local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, 8)
uiCorner.Parent = mainFrame

local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "Title"
titleLabel.Size = UDim2.new(1, 0, 0, 30)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "🌱 GHZ Auto-Tracker v1.9"
titleLabel.TextColor3 = Color3.fromRGB(150, 255, 150)
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 14
titleLabel.Parent = mainFrame

local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "Status"
statusLabel.Size = UDim2.new(1, -20, 0, 25)
statusLabel.Position = UDim2.new(0, 10, 0, 30)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Status: ⚪ Khởi động..."
statusLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
statusLabel.Font = Enum.Font.GothamMedium
statusLabel.TextSize = 12
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Parent = mainFrame

local infoLabel = Instance.new("TextLabel")
infoLabel.Name = "Info"
infoLabel.Size = UDim2.new(1, -20, 0, 40)
infoLabel.Position = UDim2.new(0, 10, 0, 55)
infoLabel.BackgroundTransparency = 1
infoLabel.Text = "Logs: Waiting for start..."
infoLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
infoLabel.Font = Enum.Font.Gotham
infoLabel.TextSize = 11
infoLabel.TextXAlignment = Enum.TextXAlignment.Left
infoLabel.TextYAlignment = Enum.TextYAlignment.Top
infoLabel.Parent = mainFrame

mainFrame.Parent = screenGui
pcall(function() screenGui.Parent = uiLayer end)

local function updateUI(statusMsg, infoMsg, color)
    if statusLabel then statusLabel.Text = statusMsg end
    if infoMsg and infoLabel then infoLabel.Text = infoMsg end
    if color and statusLabel then statusLabel.TextColor3 = color end
end

print("[GHZ] ✅ UI Built")

-------------------------------------------------------------------------------
-- HÀM HỖ TRỢ DÒ TÌM TỰ ĐỘNG (AUTO-SCAN)
-------------------------------------------------------------------------------

local function findTextLabelWithKeyword(parent, keyword)
    if not parent then return nil end
    local kw = string.lower(keyword)
    for _, obj in pairs(parent:GetDescendants()) do
        if (obj:IsA("TextLabel") or obj:IsA("TextButton")) and obj.Visible then
            local txt = obj.Text
            if txt and txt ~= "" and string.find(string.lower(txt), kw, 1, true) then
                return obj
            end
        end
    end
    return nil
end

local SEED_WHITELIST = {
    "carrot", "corn", "onion", "potato", "tomato", "strawberry", "blueberry",
    "grape", "wheat", "pumpkin", "watermelon", "mushroom", "apple", "orange",
    "lemon", "cherry", "pear", "pineapple", "coconut", "mango", "peach",
    "pepper", "eggplant", "sunflower", "bamboo", "cactus", "rose", "tulip",
    "lily", "daisy", "orchid", "lavender", "beanstalk", "dragonfruit",
    "seed", "sprout"
}

local GEAR_WHITELIST = {
    "basic sprinkler", "advanced sprinkler", "godly sprinkler",
    "super sprinkler", "ultra sprinkler",
    "watering can", "trowel", "shovel", "scythe", "hoe", "rake",
    "reverter", "favorite tool", "recall wrench",
    "harvest hand", "basket", "pitchfork"
}

local STRICT_STOCK_ITEMS = { "mushroom" }

local function guessItemCategory(itemName)
    local name = string.lower(itemName)
    for _, kw in ipairs(SEED_WHITELIST) do
        if string.find(name, kw, 1, true) then return "seed" end
    end
    for _, kw in ipairs(GEAR_WHITELIST) do
        if string.find(name, kw, 1, true) then return "gear" end
    end
    return nil
end

local function isStrict(itemName)
    local name = string.lower(itemName)
    for _, s in ipairs(STRICT_STOCK_ITEMS) do
        if string.find(name, s, 1, true) then return true end
    end
    return false
end

local function isPriceText(text)
    local t = string.lower(text)
    if string.find(t, "shilling", 1, true) or string.find(t, "coin", 1, true)
    or string.find(t, "cash",  1, true)    or string.find(t, "gem",  1, true)
    or string.match(t, "%$")               then return true end
    local n = tonumber(string.match(text, "^%s*%d+%s*$"))
    return n and n >= 500
end

local function extractStockQty(text)
    local lt = string.lower(text)
    local hasKw = string.find(lt, "stock", 1, true) or string.find(lt, "left", 1, true) or string.find(lt, "remain", 1, true)
    if hasKw then
        local best = nil
        for n in string.gmatch(text, "%d+") do
            local num = tonumber(n)
            if num and num > 0 and num <= 999 then
                if not best or num < best then best = num end
            end
        end
        return best
    end
    return nil
end

local function scanUIForStock(guiLayer)
    local seeds, gear = {}, {}
    local seen = {}
    local BLACKLIST = {
        "harvested","earned","playtime","total","level","xp","balance","owned",
        "rank","prestige","quest","inventory","confirm","close","back","next",
        "equip","v643","claimed","rewards","settings","shop"
    }

    local function addItem(name, qty, cat, img)
        if seen[name] then return end
        seen[name] = true
        local entry = { name = name, quantity = qty, category = cat, image = img or "" }
        if cat == "seed" then table.insert(seeds, entry) else table.insert(gear, entry) end
    end

    for _, container in pairs(guiLayer:GetDescendants()) do
        if screenGui and container:IsDescendantOf(screenGui) then continue end
        if (container:IsA("ScrollingFrame") or container:IsA("Frame"))
        and (container:FindFirstChildWhichIsA("UIGridLayout") or container:FindFirstChildWhichIsA("UIListLayout")) then
            for _, card in pairs(container:GetChildren()) do
                if card:IsA("Frame") or card:IsA("ImageLabel") or card:IsA("TextButton") then
                    local labels, img = {}, ""
                    local junk, soldout = false, false
                    for _, child in pairs(card:GetDescendants()) do
                        if child:IsA("TextLabel") and child.Visible and child.Text ~= "" then
                            local txt = child.Text
                            local lt = string.lower(txt)
                            for _, bw in ipairs(BLACKLIST) do
                                if string.find(lt, bw, 1, true) then junk = true break end
                            end
                            if not junk and (string.find(lt, "no stock", 1, true) or string.find(lt, "sold out", 1, true) or txt == "0") then
                                soldout = true
                            end
                            if junk or soldout then break end
                            table.insert(labels, txt)
                        elseif child:IsA("ImageLabel") and child.Visible and child.Image ~= "" and img == "" then
                            local id = string.match(child.Image, "%d+")
                            if id then img = "https://www.roblox.com/asset-thumbnail/image?assetId=" .. id .. "&width=420&height=420&format=png" end
                        end
                    end

                    if not junk and not soldout and #labels >= 2 then
                        local itemName = ""
                        for _, txt in ipairs(labels) do
                            if not isPriceText(txt) and not tonumber(txt) and string.len(txt) > 2 and string.len(txt) > string.len(itemName) then
                                itemName = txt
                            end
                        end
                        if itemName ~= "" then
                            local qty = nil
                            for _, txt in ipairs(labels) do
                                if not isPriceText(txt) then
                                    qty = extractStockQty(txt)
                                    if qty then break end
                                end
                            end
                            if not qty and not isStrict(itemName) then
                                for _, txt in ipairs(labels) do
                                    if not isPriceText(txt) then
                                        for n in string.gmatch(txt, "%d+") do
                                            local num = tonumber(n)
                                            if num and num >= 1 and num <= 99 then qty = num break end
                                        end
                                    end
                                    if qty then break end
                                end
                            end
                            local cat = guessItemCategory(itemName)
                            if qty and qty > 0 and cat then addItem(itemName, qty, cat, img) end
                        end
                    end
                end
            end
        end
    end
    return seeds, gear
end

local function scanWeather(guiLayer)
    local WEATHER_KEYWORDS = { "starfall", "meteor", "storm", "rain", "snow", "mowis", "sandstorm" }
    for _, kw in ipairs(WEATHER_KEYWORDS) do
        local label = findTextLabelWithKeyword(guiLayer, kw)
        if label then
            local status = label.Text
            local duration = 0
            local function findDur(root)
                if not root then return 0 end
                for _, obj in pairs(root:GetDescendants()) do
                    if obj:IsA("TextLabel") and obj.Visible then
                        local t = obj.Text or ""
                        local m, s = string.match(t, "(%d+):(%d+)")
                        if m and s then return tonumber(m)*60 + tonumber(s) end
                    end
                end
                return 0
            end
            duration = findDur(label.Parent)
            if duration == 0 and label.Parent then duration = findDur(label.Parent.Parent) end
            return { status = status, duration = duration }
        end
    end
    return { status = "None", duration = 0 }
end

local function getGardenHorizonsData()
    if not PlayerGui then return {}, {}, {status="None", duration=0} end
    local seeds, gear = {}, {}
    local weather = { status = "None", duration = 0 }
    updateUI("Status: 🔍 Đang quét...", nil, Color3.fromRGB(255, 200, 100))
    pcall(function()
        weather = scanWeather(PlayerGui)
        seeds, gear = scanUIForStock(PlayerGui)
    end)
    local info = string.format("Seeds:%d Gear:%d | %s (%ds)", #seeds, #gear, weather.status, weather.duration)
    updateUI("Status: ✅ Quét xong!", info, Color3.fromRGB(130, 255, 130))
    return seeds or {}, gear or {}, weather or {status="None", duration=0}
end

local function postDataToAPI()
    local ok_data, seeds, gear, weather = pcall(getGardenHorizonsData)
    if not ok_data then warn("[GHZ] Scan failed") return end
    
    if #seeds == 0 and #gear == 0 and weather.status == "None" then
        updateUI("Status: ⚠️ Không thấy shop!", "Mở Shop để lấy data.", Color3.fromRGB(255,100,100))
        return
    end
    
    local payload = { seeds = seeds, gear = gear, weather = weather, timestamp = os.time() }
    local jsonData = HttpService:JSONEncode(payload)
    local req = (syn and syn.request) or (http and http.request) or request
    
    if not req then
        warn("[GHZ] No request function found")
        updateUI("Status: ❌ Lỗi Request", "Executor không hỗ trợ.", Color3.fromRGB(255,0,0))
        return
    end
    
    local ok_post, resp = pcall(function()
        return req({
            Url = API_URL,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = jsonData
        })
    end)
    
    if ok_post then
        updateUI("Status: ✅ API Đã gửi", "Dữ liệu mới đã lên web.", Color3.fromRGB(150,255,150))
        print("[GHZ] API Post success")
    else
        updateUI("Status: ❌ API Lỗi", tostring(resp), Color3.fromRGB(255,100,100))
        warn("[GHZ] API Post failed: " .. tostring(resp))
    end
end

-------------------------------------------------------------------------------
-- MAIN EXECUTION
-------------------------------------------------------------------------------
task.spawn(function()
    print("[GHZ] 🚀 Main loop starting...")
    postDataToAPI()
    
    while true do
        local now = os.time()
        local targetTs = now + (300 - (now % 300)) + 2
        
        while os.time() < targetTs do
            local remaining = targetTs - os.time()
            updateUI(string.format("Status: ⏳ Restock %02d:%02d", math.floor(remaining/60), remaining%60),
                     nil, Color3.fromRGB(180, 180, 255))
            task.wait(1)
            -- Failsafe: Re-parent UI if it disappears
            if screenGui and not screenGui.Parent and uiLayer then
                pcall(function() screenGui.Parent = uiLayer end)
            end
        end
        
        print("[GHZ] ⚡ Restock trigger!")
        postDataToAPI()
        task.wait(5)
    end
end)

print("[GHZ] 🔥 Script Ready!")
