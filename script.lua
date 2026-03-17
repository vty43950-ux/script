local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

-- API URL CỦA BẠN 
local API_URL = "https://zenithghz.qzz.io/api/update"

-------------------------------------------------------------------------------
-- GIAO DIỆN (UI) THÔNG BÁO CHO NGƯỜI DÙNG
-------------------------------------------------------------------------------
local uiLayer = (gethui and gethui()) or CoreGui:FindFirstChild("RobloxGui") or CoreGui

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "GHZ_Tracker_UI"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- Xóa UI cũ nếu chạy lại script nhiều lần
if uiLayer:FindFirstChild("GHZ_Tracker_UI") then
    uiLayer["GHZ_Tracker_UI"]:Destroy()
end
screenGui.Parent = uiLayer

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 250, 0, 100)
mainFrame.Position = UDim2.new(0, 10, 0, 10) -- Góc trên cùng bên trái
mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
mainFrame.BorderSizePixel = 0
mainFrame.BackgroundTransparency = 0.2
mainFrame.Parent = screenGui

local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, 8)
uiCorner.Parent = mainFrame

local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "Title"
titleLabel.Size = UDim2.new(1, 0, 0, 30)
titleLabel.Position = UDim2.new(0, 0, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "🌱 GHZ Auto-Tracker"
titleLabel.TextColor3 = Color3.fromRGB(150, 255, 150)
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 14
titleLabel.Parent = mainFrame

local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "Status"
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
infoLabel.Name = "Info"
infoLabel.Size = UDim2.new(1, -20, 0, 40)
infoLabel.Position = UDim2.new(0, 10, 0, 55)
infoLabel.BackgroundTransparency = 1
infoLabel.Text = "Data: Chưa có | Thời tiết: None"
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
-- HÀM HỖ TRỢ DÒ TÌM TỰ ĐỘNG (AUTO-SCAN)
-------------------------------------------------------------------------------

local function findTextLabelWithKeyword(parent, keyword)
    for _, obj in pairs(parent:GetDescendants()) do
        if obj:IsA("TextLabel") or obj:IsA("TextBox") or obj:IsA("TextButton") then
            if obj.Text and string.match(string.lower(obj.Text), string.lower(keyword)) then
                return obj
            end
        end
    end
    return nil
end

-- 2. Dò tìm Frame chứa danh sách Item (Dùng cho Shop)
local function guessItemCategory(itemName)
    local name = string.lower(itemName)
    if string.find(name, "seed") or string.find(name, "sprout") or string.find(name, "plant") then
        return "seed"
    elseif string.find(name, "sprinkler") or string.find(name, "pot") or string.find(name, "water") or string.find(name, "gear") then
        return "gear"
    else
        return "unknown" 
    end
end

-- Rút trích số ra khỏi chuỗi (Ví dụ "Stock: 15" -> 15)
local function extractNumber(text)
    if not text then return nil end
    local num = string.match(text, "%d+")
    return num and tonumber(num) or nil
end

-- Hàm kiểm tra xem 1 text có giống "Giá Tiền" không (Ví dụ: "$100", "150 Coins")
local function isPriceOrMoney(text)
    local t = string.lower(text)
    if string.match(t, "%$") or string.find(t, "coin") or string.find(t, "cash") or string.find(t, "gem") then
        return true
    end
    return false
end

local function scanUIForStock(guiLayer)
    local results = { seeds = {}, gear = {}, foundTracker = {} }
    
    -- Blacklist rác
    local blacklist = {
        "harvested", "earned", "playtime", "shillings", "total", "level", "xp", 
        "balance", "owned", "shilling", "rank", "prestige", "quest", "inventory",
        "buy", "sell", "confirm", "close", "back", "next", "equip", "status", "v643",
        "money", "cash", "gems", "claimed", "rewards"
    }

    -- 1. CHẾ ĐỘ QUÉT CHUẨN (Tìm Containers có Layout)
    local function processItemUI(itemUI)
        if not itemUI:IsA("Frame") and not itemUI:IsA("ImageLabel") and not itemUI:IsA("TextButton") then return end
        
        local cardLabels = {}
        local itemImage = ""
        local isJunkCard = false
        local isSoldOut = false
        
        for _, child in pairs(itemUI:GetDescendants()) do
            if child:IsA("TextLabel") and child.Text ~= "" and child.Visible then
                local txt = child.Text
                local ltxt = string.lower(txt)
                for _, word in ipairs(blacklist) do
                    if string.find(ltxt, word) then isJunkCard = true break end
                end
                if string.find(ltxt, "no stock") or string.find(ltxt, "sold out") or string.find(ltxt, "0 left") or string.find(ltxt, "0x") then 
                    isSoldOut = true 
                end
                if isJunkCard or isSoldOut then break end
                table.insert(cardLabels, txt)
            elseif child:IsA("ImageLabel") and child.Visible and child.Image ~= "" then
                local assetId = string.match(child.Image, "%d+")
                if assetId and itemImage == "" then
                    itemImage = "https://www.roblox.com/asset-thumbnail/image?assetId=" .. assetId .. "&width=420&height=420&format=png"
                end
            end
        end
        
        if isJunkCard or isSoldOut or #cardLabels == 0 then return end
        
        local itemName = ""
        local itemStock = -1
        local isExplicitStock = false
        
        for _, text in ipairs(cardLabels) do
            local lowerText = string.lower(text)
            if not isPriceOrMoney(text) then
                local num = extractNumber(text)
                if num then
                    if string.find(lowerText, "stock") or string.find(lowerText, "left") or string.match(text, "%d+[xX]") or string.match(text, "[xX]%s*%d+") then
                        itemStock = num
                        isExplicitStock = true
                    elseif itemStock == -1 then
                        itemStock = num
                    end
                end
            end
            
            if not isPriceOrMoney(text) and not string.find(lowerText, "stock") and not string.find(lowerText, "left") then
                if not tonumber(text) and string.len(text) > 2 and not string.match(text, "^%d+[xX]$") and not string.match(text, "^[xX]%s*%d+$") then
                    if string.len(text) > string.len(itemName) and string.len(text) < 40 then
                        itemName = text
                    end
                end
            end
        end
        
        if itemName ~= "" and itemStock > 0 and not results.foundTracker[itemName] then
            local cat = guessItemCategory(itemName)
            table.insert(cat == "seed" and results.seeds or results.gear, {
                name = itemName,
                quantity = itemStock,
                category = cat,
                image = itemImage
            })
            results.foundTracker[itemName] = true
            return true
        end
    end

    -- CHẠY QUÉT
    local foundAny = false
    for _, container in pairs(guiLayer:GetDescendants()) do
        if screenGui and container:IsDescendantOf(screenGui) then continue end

        -- Quét các Frame có layout (Chuẩn nhất)
        if (container:IsA("ScrollingFrame") or container:IsA("Frame")) and 
           (container:FindFirstChildWhichIsA("UIGridLayout") or container:FindFirstChildWhichIsA("UIListLayout")) then
            for _, itemUI in pairs(container:GetChildren()) do
                if processItemUI(itemUI) then foundAny = true end
            end
        end
    end
    
    -- 2. CHẾ ĐỘ QUÉT SÂU (Nếu quét chuẩn không ra gì - Dành cho các game UI lạ)
    if not foundAny then
        print("[GHZ Debug] 🔍 Quét chuẩn không thấy gì, đang chuyển sang Deep Scan...")
        for _, obj in pairs(guiLayer:GetDescendants()) do
            if obj:IsA("Frame") and #obj:GetChildren() >= 2 then
                -- Nếu frame có chứa chữ "Stock" hoặc "Price" hoặc ký hiệu tiền tệ
                local hasKeywords = false
                for _, child in pairs(obj:GetDescendants()) do
                    if child:IsA("TextLabel") then
                        local t = string.lower(child.Text)
                        if string.find(t, "stock") or string.find(t, "left") or string.find(t, "$") or string.find(t, "price") then
                            hasKeywords = true break
                        end
                    end
                end
                if hasKeywords then processItemUI(obj) end
            end
        end
    end
    
    return results.seeds, results.gear
end

-------------------------------------------------------------------------------
-- HÀM TRÍCH XUẤT DỮ LIỆU TỰ ĐỘNG TỪ GARDEN HORIZONS
-------------------------------------------------------------------------------
local function getGardenHorizonsData()
    local seeds = {}
    local gear = {}
    local weather = { status = "None", duration = 0 }
    
    local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
    
    updateUI("Status: 🔍 Đang quét dữ liệu...", nil, Color3.fromRGB(255, 200, 100))
    
    pcall(function()
        -- 1. Weather scan (Mở rộng tìm kiếm)
        local wKeywords = {"starfall", "storm", "clear", "rain", "sunny", "meteor", "mowis", "cloudy", "windy", "snow"}
        local foundW = false
        
        -- Tìm trong toàn bộ ScreenGui trước
        for _, kw in ipairs(wKeywords) do
            local wLabel = findTextLabelWithKeyword(PlayerGui, kw)
            if wLabel then
                weather.status = (kw:gsub("^%l", string.upper)) 
                
                local function findDuration(root)
                    for _, child in pairs(root:GetDescendants()) do
                        if child:IsA("TextLabel") then
                            local txt = child.Text
                            local m, s = string.match(txt, "(%d+):(%d+)")
                            if m and s then return (tonumber(m) * 60) + tonumber(s) end
                            local numsec = string.match(txt, "(%d+)s")
                            if numsec then return tonumber(numsec) end
                        end
                    end
                end
                
                weather.duration = findDuration(wLabel.Parent) or findDuration(wLabel.Parent.Parent) or 0
                foundW = true
                break
            end
        end
        
        -- 2. Item scan
        seeds, gear = scanUIForStock(PlayerGui)
    end)
    
    local infoStr = string.format("Data: %d Hạt, %d Đồ\nWeather: %s (%ds)", #seeds, #gear, weather.status, weather.duration)
    updateUI("Status: ✅ Đã quét xong!", infoStr, Color3.fromRGB(130, 255, 130))
    
    print(string.format("[GHZ Scanner] 📊 Kết quả: Seeds: %d, Gears: %d | Weather: %s (%ds)", #seeds, #gear, weather.status, weather.duration))
    return seeds, gear, weather
end

-------------------------------------------------------------------------------
-- HÀM GỬI LÊN API SERVER
-------------------------------------------------------------------------------
local function postDataToAPI()
    local seeds, gear, weather = getGardenHorizonsData()
    
    -- Cho phép gửi nếu CÓ ít nhất 1 thứ (Hạt HOẶC Đồ HOẶC Thời tiết khác None)
    if #seeds == 0 and #gear == 0 and weather.status == "None" then
        print("[GHZ Script] ❌ Không thấy dữ liệu gì để gửi. Hãy mở cửa hàng!")
        updateUI("Status: ⚠️ Không thấy Shop UI!", "Mở Shop để script lấy data.", Color3.fromRGB(255, 100, 100))
        return 
    end
    
    local payload = {
        seeds = seeds,
        gear = gear,
        weather = weather,
        timestamp = os.time()
    }
    
    local jsonData = HttpService:JSONEncode(payload)
    local req = (syn and syn.request) or (http and http.request) or request
    
    if req then
        print("[GHZ Script] 📡 Đang gửi dữ liệu lên Server: " .. API_URL)
        local success, response = pcall(function()
            return req({
                Url = API_URL,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = jsonData
            })
        end)
        
        if success then
            if response.StatusCode == 200 then
                print("[GHZ Script] ✅ Cập nhật thành công!")
                updateUI("Status: ✅ Up API Thành công", nil, Color3.fromRGB(150, 255, 150))
            else
                print("[GHZ Script] ❌ Server lỗi: " .. tostring(response.StatusCode))
                updateUI("Status: ❌ Server Lỗi", "Code: " .. tostring(response.StatusCode), Color3.fromRGB(255, 100, 100))
            end
        else
            print("[GHZ Script] ❌ Không kết nối được Server. Hãy kiểm tra node server.js")
            updateUI("Status: ❌ Mất kết nối Server", nil, Color3.fromRGB(255, 100, 100))
        end
    end
end

-------------------------------------------------------------------------------
-- VÒNG LẶP CHÍNH
-------------------------------------------------------------------------------
task.spawn(function()
    print("[GHZ Script] 🚀 Bắt đầu trình lấy data (Reliability Build 1.4)")
    
    postDataToAPI()
    
    while true do
        local waitTime = getSecondsUntilNextRestock()
        if waitTime <= 0 then waitTime = 300 end
        
        for i = waitTime, 1, -1 do
            updateUI(string.format("Status: ⏳ Đợi restock... (%ds)", i), nil, Color3.fromRGB(200, 200, 255))
            task.wait(1)
            if not screenGui or not screenGui.Parent then return end
        end
        
        postDataToAPI()
    end
end)





