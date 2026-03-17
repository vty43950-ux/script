local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

-- API URL
local API_URL = "https://zenithghz.qzz.io/api/update"

-------------------------------------------------------------------------------
-- GIAO DIỆN (UI)
-------------------------------------------------------------------------------
local uiLayer = (gethui and gethui()) or CoreGui:FindFirstChild("RobloxGui") or CoreGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "GHZ_Tracker_UI"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

if uiLayer:FindFirstChild("GHZ_Tracker_UI") then
    uiLayer["GHZ_Tracker_UI"]:Destroy()
end
screenGui.Parent = uiLayer

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 250, 0, 100)
mainFrame.Position = UDim2.new(0, 10, 0, 10)
mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
mainFrame.BackgroundTransparency = 0.2
mainFrame.Parent = screenGui

local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, 8)
uiCorner.Parent = mainFrame

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, 0, 0, 30)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "🌱 GHZ Auto-Tracker"
titleLabel.TextColor3 = Color3.fromRGB(150, 255, 150)
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 14
titleLabel.Parent = mainFrame

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -20, 0, 25)
statusLabel.Position = UDim2.new(0, 10, 0, 30)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Status: 🟡 Khởi động..."
statusLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
statusLabel.Font = Enum.Font.GothamMedium
statusLabel.TextSize = 12
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Parent = mainFrame

local infoLabel = Instance.new("TextLabel")
infoLabel.Size = UDim2.new(1, -20, 0, 40)
infoLabel.Position = UDim2.new(0, 10, 0, 55)
infoLabel.BackgroundTransparency = 1
infoLabel.Text = "Data: Chờ quét..."
infoLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
infoLabel.Font = Enum.Font.Gotham
infoLabel.TextSize = 11
infoLabel.TextXAlignment = Enum.TextXAlignment.Left
infoLabel.TextYAlignment = Enum.TextYAlignment.Top
infoLabel.Parent = mainFrame

local function updateUI(statusMsg, infoMsg, color)
    statusLabel.Text = statusMsg
    if infoMsg then infoLabel.Text = infoMsg end
    if color then statusLabel.TextColor3 = color end
end

-------------------------------------------------------------------------------
-- LOGIC QUÉT VÀ BỘ LỌC
-------------------------------------------------------------------------------

local SEED_NAMES = {
    "onion", "corn", "carrot", "potato", "tomato", "blueberry", "strawberry",
    "grape", "wheat", "pumpkin", "watermelon", "mushroom", "apple", "orange",
    "lemon", "cherry", "pear", "pineapple", "coconut", "mango", "peach",
    "pepper", "eggplant", "sunflower", "bamboo", "cactus", "rose", "tulip",
    "lily", "daisy", "orchid", "lavender", "seed", "sprout", "plant"
}

local GEAR_NAMES = {
    "sprinkler", "watering", "trowel", "shovel", "hoe", "scythe", "basket",
    "reverter", "favorite", "tool", "can", "gloves", "boots", "hat",
    "fertilizer", "soil", "pot", "planter", "rake", "pitchfork"
}

-- Blacklist các mục không mong muốn hoặc gây nhiễu
local ITEM_BLACKLIST = {
    "fertile soil", "max", "owned", "inventory", "level", "xp", "rank", 
    "requirement", "equipped", "shillings", "balance", "total", "buy", "sell"
}

local function guessItemCategory(itemName)
    local name = string.lower(itemName)
    
    -- Kiểm tra Blacklist trước
    for _, word in ipairs(ITEM_BLACKLIST) do
        if string.find(name, word) then return nil end
    end

    for _, keyword in ipairs(SEED_NAMES) do
        if string.find(name, keyword) then return "seed" end
    end
    for _, keyword in ipairs(GEAR_NAMES) do
        if string.find(name, keyword) then return "gear" end
    end
    return nil
end

local function extractStockQuantity(text)
    if not text then return nil end
    local lowerText = string.lower(text)
    
    -- Ưu tiên tìm pattern x10 hoặc 10x
    local p1 = string.match(text, "[xX]%s*(%d+)")
    local p2 = string.match(text, "(%d+)%s*[xX]")
    if p1 then return tonumber(p1) end
    if p2 then return tonumber(p2) end
    
    -- Nếu có từ khóa Stock/Left
    if string.find(lowerText, "stock") or string.find(lowerText, "left") then
        local n = string.match(text, "%d+")
        return n and tonumber(n)
    end
    return nil
end

local function isPrice(text)
    local t = string.lower(text)
    if string.match(t, "[%$%¢]") or string.find(t, "shilling") or string.find(t, "coin") then
        return true
    end
    local n = tonumber(string.match(text, "^%d+$"))
    return n and n >= 500
end

local function scanUIForStock(guiLayer)
    local results = { seeds = {}, gear = {}, foundTracker = {} }
    
    -- Tìm các Container chứa Item (thường có Layout)
    for _, container in pairs(guiLayer:GetDescendants()) do
        if screenGui and container:IsDescendantOf(screenGui) then continue end

        if (container:IsA("ScrollingFrame") or container:IsA("Frame")) and 
           (container:FindFirstChildWhichIsA("UIGridLayout") or container:FindFirstChildWhichIsA("UIListLayout")) then
            
            for _, itemCard in pairs(container:GetChildren()) do
                if not (itemCard:IsA("Frame") or itemCard:IsA("ImageLabel") or itemCard:IsA("TextButton")) then continue end
                
                local cardTexts = {}
                local itemImage = ""
                
                -- Thu thập thông tin trong Card
                for _, child in pairs(itemCard:GetDescendants()) do
                    if child:IsA("TextLabel") and child.Visible and child.Text ~= "" then
                        table.insert(cardTexts, child.Text)
                    elseif child:IsA("ImageLabel") and child.Visible and child.Image ~= "" then
                        local assetId = string.match(child.Image, "%d+")
                        if assetId and itemImage == "" then
                            itemImage = "https://www.roblox.com/asset-thumbnail/image?assetId=" .. assetId .. "&width=420&height=420&format=png"
                        end
                    end
                end

                -- 1. Tìm Tên hợp lệ
                local finalName = ""
                local category = nil
                for _, txt in ipairs(cardTexts) do
                    category = guessItemCategory(txt)
                    if category then
                        finalName = txt
                        break
                    end
                end

                -- 2. Tìm Stock (Chỉ tiếp tục nếu tìm được tên)
                if finalName ~= "" and not results.foundTracker[finalName] then
                    local finalStock = -1
                    
                    for _, txt in ipairs(cardTexts) do
                        local s = extractStockQuantity(txt)
                        if s then 
                            finalStock = s 
                            break 
                        end
                    end
                    
                    -- Fallback nếu không có nhãn x10 (Tìm số nhỏ 1-99 không phải giá)
                    if finalStock == -1 then
                        for _, txt in ipairs(cardTexts) do
                            if not isPrice(txt) then
                                local n = tonumber(string.match(txt, "%d+"))
                                if n and n > 0 and n < 200 then
                                    finalStock = n
                                    break
                                end
                            end
                        end
                    end

                    -- Chỉ thêm nếu dữ liệu hợp lệ (Tránh stock = 0 hoặc k tìm thấy)
                    if finalStock > 0 then
                        table.insert(category == "seed" and results.seeds or results.gear, {
                            name = finalName,
                            quantity = finalStock,
                            category = category,
                            image = itemImage
                        })
                        results.foundTracker[finalName] = true
                    end
                end
            end
        end
    end
    return results.seeds, results.gear
end

-------------------------------------------------------------------------------
-- THỜI TIẾT & API
-------------------------------------------------------------------------------

local function getGardenHorizonsData()
    local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
    updateUI("Status: 🔍 Đang quét dữ liệu...", nil, Color3.fromRGB(255, 200, 100))
    
    local weather = { status = "None", duration = 0 }
    local wKeywords = {"starfall", "storm", "clear", "rain", "sunny", "meteor", "mowis", "cloudy", "windy", "snow"}
    
    pcall(function()
        -- Quét thời tiết
        for _, obj in pairs(PlayerGui:GetDescendants()) do
            if obj:IsA("TextLabel") and obj.Visible then
                local t = string.lower(obj.Text)
                for _, kw in ipairs(wKeywords) do
                    if string.find(t, kw) then
                        weather.status = kw:gsub("^%l", string.upper)
                        -- Tìm thời gian gần đó
                        local m, s = string.match(obj.Parent:GetFullName(), "(%d+):(%d+)") -- Thử tìm trong node cha
                        break
                    end
                end
            end
        end
    end)

    local seeds, gear = scanUIForStock(PlayerGui)
    
    local infoStr = string.format("Data: %d Hạt, %d Đồ\nWeather: %s", #seeds, #gear, weather.status)
    updateUI("Status: ✅ Quét hoàn tất", infoStr, Color3.fromRGB(130, 255, 130))
    
    return seeds, gear, weather
end

local function postDataToAPI()
    local seeds, gear, weather = getGardenHorizonsData()
    
    if #seeds == 0 and #gear == 0 and weather.status == "None" then
        updateUI("Status: ⚠️ Không thấy Shop!", "Hãy mở Cửa hàng để lấy data", Color3.fromRGB(255, 100, 100))
        return 
    end
    
    local payload = {
        seeds = seeds,
        gear = gear,
        weather = weather,
        timestamp = os.time()
    }
    
    local req = (syn and syn.request) or (http and http.request) or request
    if req then
        local success, response = pcall(function()
            return req({
                Url = API_URL,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = HttpService:JSONEncode(payload)
            })
        end)
        
        if success and response.StatusCode == 200 then
            updateUI("Status: ✅ API Updated", nil, Color3.fromRGB(150, 255, 150))
        else
            updateUI("Status: ❌ Lỗi gửi API", "Kiểm tra Server của bạn", Color3.fromRGB(255, 100, 100))
        end
    end
end

-------------------------------------------------------------------------------
-- VÒNG LẶP ĐỒNG BỘ UTC
-------------------------------------------------------------------------------

local function getSecondsUntilNextRestock()
    local t = os.date("!*t")
    local secIntoCycle = (t.min % 5) * 60 + t.sec
    local remaining = 300 - secIntoCycle
    return remaining > 0 and remaining or 300
end

task.spawn(function()
    postDataToAPI()
    while true do
        local waitTime = getSecondsUntilNextRestock()
        for i = waitTime, 1, -1 do
            local mins = math.floor(i / 60)
            local secs = i % 60
            updateUI(string.format("Status: ⏳ Restock sau %02d:%02d", mins, secs), nil)
            task.wait(1)
            if not screenGui.Parent then return end
        end
        postDataToAPI()
        task.wait(2) -- Nghỉ ngắn tránh spam
    end
end)
