local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

-- API URL
local API_URL = "https://zenithghz.qzz.io/api/update"

-------------------------------------------------------------------------------
-- GIAO DIỆN (UI) - Giữ nguyên thiết kế của bạn
-------------------------------------------------------------------------------
local uiLayer = (gethui and gethui()) or CoreGui:FindFirstChild("RobloxGui") or CoreGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "GHZ_Tracker_UI"
screenGui.ResetOnSpawn = false
if uiLayer:FindFirstChild("GHZ_Tracker_UI") then uiLayer["GHZ_Tracker_UI"]:Destroy() end
screenGui.Parent = uiLayer

local mainFrame = Instance.new("Frame")
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
titleLabel.Text = "🌱 GHZ Tracker v2.0 (Strict Mode)"
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
statusLabel.Parent = mainFrame

local infoLabel = Instance.new("TextLabel")
infoLabel.Size = UDim2.new(1, -20, 0, 40)
infoLabel.Position = UDim2.new(0, 10, 0, 55)
infoLabel.BackgroundTransparency = 1
infoLabel.Text = "Data: Chờ quét..."
infoLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
infoLabel.Font = Enum.Font.Gotham
infoLabel.TextSize = 11
infoLabel.Parent = mainFrame

local function updateUI(statusMsg, infoMsg, color)
    statusLabel.Text = statusMsg
    if infoMsg then infoLabel.Text = infoMsg end
    if color then statusLabel.TextColor3 = color end
end

-------------------------------------------------------------------------------
-- LOGIC BỘ LỌC CỰC CHẶT (STRICT FILTERS)
-------------------------------------------------------------------------------

-- Danh sách tên hạt giống cụ thể (Bỏ từ "plant" chung chung để tránh nhầm thống kê)
local SEED_NAMES = {
    "onion", "corn", "carrot", "potato", "tomato", "blueberry", "strawberry",
    "grape", "wheat", "pumpkin", "watermelon", "mushroom", "apple", "orange",
    "lemon", "cherry", "pear", "pineapple", "coconut", "mango", "peach",
    "pepper", "eggplant", "sunflower", "bamboo", "cactus", "rose", "tulip",
    "lily", "daisy", "orchid", "lavender", "sprout", "seed pack", "dawn", "royal", "streak"
}

local GEAR_NAMES = {
    "sprinkler", "watering", "trowel", "shovel", "hoe", "scythe", "basket",
    "reverter", "tool", "can", "gloves", "boots", "hat", "planter", "rake"
}

-- Blacklist cực mạnh để loại bỏ rác
local GLOBAL_BLACKLIST = {
    "harvested", "earned", "last seen", "common", "rare", "legendary", "uncommon",
    "shillings", "balance", "total", "level", "xp", "rank", "fertile soil",
    "statistics", "profile", "inventory", "equipped", "ago", "seen"
}

local function isBlacklisted(text)
    local t = string.lower(text)
    for _, word in ipairs(GLOBAL_BLACKLIST) do
        if string.find(t, word) then return true end
    end
    -- Loại bỏ nếu text chứa ký tự thời gian ":" (Ví dụ 23:51:25)
    if string.find(t, ":") then return true end
    return false
end

local function guessItemCategory(itemName)
    if isBlacklisted(itemName) then return nil end
    local name = string.lower(itemName)
    
    -- Ưu tiên check GEAR trước để loại Fertilizer/Soil
    for _, keyword in ipairs(GEAR_NAMES) do
        if string.find(name, keyword) then return "gear" end
    end
    
    for _, keyword in ipairs(SEED_NAMES) do
        if string.find(name, keyword) then return "seed" end
    end
    
    -- Nếu có chữ "Seed" mà không dính blacklist thì vẫn nhận
    if string.find(name, "seed") then return "seed" end
    
    return nil
end

-- Hàm lấy Stock dựa trên cấu trúc "x[Số] left" trong ảnh của bạn
local function extractStockStrict(text)
    if not text or isBlacklisted(text) then return nil end
    
    -- Pattern chuẩn trong GHZ: "x6 left" hoặc "x5"
    local stockValue = string.match(text, "[xX]%s*(%d+)")
    if stockValue then
        return tonumber(stockValue)
    end
    return nil
end

local function scanUIForStock(guiLayer)
    local results = { seeds = {}, gear = {}, foundTracker = {} }
    
    for _, container in pairs(guiLayer:GetDescendants()) do
        if screenGui and container:IsDescendantOf(screenGui) then continue end

        -- Chỉ quét trong các khung có Layout (Shop Cards)
        if (container:IsA("ScrollingFrame") or container:IsA("Frame")) and 
           (container:FindFirstChildWhichIsA("UIGridLayout") or container:FindFirstChildWhichIsA("UIListLayout")) then
            
            for _, card in pairs(container:GetChildren()) do
                if not (card:IsA("Frame") or card:IsA("ImageLabel") or card:IsA("TextButton")) then continue end
                
                local cardTexts = {}
                local itemImage = ""
                
                -- Lấy tất cả text trong 1 ô vật phẩm
                for _, child in pairs(card:GetDescendants()) do
                    if child:IsA("TextLabel") and child.Visible and child.Text ~= "" then
                        table.insert(cardTexts, child.Text)
                    elseif child:IsA("ImageLabel") and child.Visible and child.Image ~= "" then
                        if string.find(child.Image, "rbxassetid") or string.find(child.Image, "http") then
                            local assetId = string.match(child.Image, "%d+")
                            if assetId and itemImage == "" then
                                itemImage = "https://www.roblox.com/asset-thumbnail/image?assetId=" .. assetId .. "&width=150&height=150&format=png"
                            end
                        end
                    end
                end

                -- Bước 1: Xác định Tên và Category
                local finalName = ""
                local category = nil
                for _, txt in ipairs(cardTexts) do
                    category = guessItemCategory(txt)
                    if category then
                        finalName = txt
                        break
                    end
                end

                -- Bước 2: Xác định Stock (Chỉ lấy nếu đã có tên)
                if finalName ~= "" and not results.foundTracker[finalName] then
                    local finalStock = nil
                    
                    -- Tìm label có dạng "x10 left" hoặc tương tự
                    for _, txt in ipairs(cardTexts) do
                        finalStock = extractStockStrict(txt)
                        if finalStock then break end
                    end

                    -- Chỉ chấp nhận nếu có stock rõ ràng (tránh lấy nhầm số 5 ảo)
                    if finalStock and finalStock >= 0 then
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
-- THỜI TIẾT & GỬI DỮ LIỆU
-------------------------------------------------------------------------------

local function postDataToAPI()
    local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
    updateUI("Status: 🔍 Đang quét...", nil, Color3.fromRGB(255, 200, 100))
    
    local seeds, gear = scanUIForStock(PlayerGui)
    
    -- Quét thời tiết (Strict)
    local weather = { status = "None", duration = 0 }
    local wKeywords = {"starfall", "storm", "clear", "rain", "sunny", "meteor", "mowis", "cloudy", "windy", "snow"}
    for _, obj in pairs(PlayerGui:GetDescendants()) do
        if obj:IsA("TextLabel") and obj.Visible and not isBlacklisted(obj.Text) then
            local t = string.lower(obj.Text)
            for _, kw in ipairs(wKeywords) do
                if string.find(t, kw) then
                    weather.status = kw:gsub("^%l", string.upper)
                    break
                end
            end
        end
    end

    if #seeds == 0 and #gear == 0 then
        updateUI("Status: ⚠️ Không thấy Shop!", "Hãy mở Merchant UI", Color3.fromRGB(255, 100, 100))
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
        pcall(function()
            req({
                Url = API_URL,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = HttpService:JSONEncode(payload)
            })
        end)
        updateUI("Status: ✅ Đã cập nhật API", "Seeds: "..#seeds.." | Gears: "..#gear, Color3.fromRGB(150, 255, 150))
    end
end

-------------------------------------------------------------------------------
-- VÒNG LẶP UTC 5 PHÚT
-------------------------------------------------------------------------------
task.spawn(function()
    postDataToAPI()
    while true do
        local t = os.date("!*t")
        local waitTime = 300 - ((t.min % 5) * 60 + t.sec)
        for i = waitTime, 1, -1 do
            local mins = math.floor(i / 60)
            local secs = i % 60
            statusLabel.Text = string.format("Status: ⏳ Restock %02d:%02d", mins, secs)
            task.wait(1)
        end
        postDataToAPI()
        task.wait(2)
    end
end)
