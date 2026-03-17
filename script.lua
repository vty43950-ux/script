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

local function extractNumber(text)
    if not text then return nil end
    local num = string.match(text, "%d+")
    return num and tonumber(num) or nil
end

local function scanUIForStock(guiLayer)
    local results = { seeds = {}, gear = {}, foundTracker = {} }
    
    for _, frame in pairs(guiLayer:GetDescendants()) do
        if frame:IsA("Frame") or frame:IsA("ScrollingFrame") then
            if frame:FindFirstChildWhichIsA("UIListLayout") or frame:FindFirstChildWhichIsA("UIGridLayout") then
                
                for _, itemUI in pairs(frame:GetChildren()) do
                    if itemUI:IsA("Frame") or itemUI:IsA("ImageLabel") or itemUI:IsA("TextButton") then
                        
                        local itemName = ""
                        local itemStock = 0 
                        local hasStockLabel = false 
                        
                        for _, child in pairs(itemUI:GetDescendants()) do
                            if child:IsA("TextLabel") then
                                local text = child.Text
                                local num = extractNumber(text)
                                if num and string.len(text) < 15 and not string.match(text, "[a-zA-Z]+") then
                                    itemStock = num
                                    hasStockLabel = true
                                elseif num and string.match(string.lower(text), "stock") then
                                    itemStock = num
                                    hasStockLabel = true
                                elseif text ~= "" and not tonumber(text) and not string.match(text, "^%d+") then
                                    if string.len(text) > string.len(itemName) then
                                        itemName = text
                                    end
                                end
                            end
                        end
                        
                        if itemName ~= "" and hasStockLabel and itemStock > 0 and not results.foundTracker[itemName] then
                            local isJunk = false
                            local lowerName = string.lower(itemName)
                            local junkWords = {"buy", "sell", "shop", "close", "confirm", "cancel", "equip", "inventory"}
                            for _, jw in ipairs(junkWords) do
                                if string.find(lowerName, jw) then isJunk = true; break end
                            end
                            
                            if not isJunk then
                                local cat = guessItemCategory(itemName)
                                local data = { name = itemName, quantity = itemStock, category = cat }
                                
                                if cat == "seed" then
                                    table.insert(results.seeds, data)
                                else
                                    table.insert(results.gear, data) 
                                end
                                results.foundTracker[itemName] = true
                            end
                        end
                        
                    end
                end
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
    
    updateUI("Status: 🔍 Đang quét màn hình game...", nil, Color3.fromRGB(255, 200, 100))
    print("[GHZ Scanner] 🔍 Đang tự động quét UI tìm VIP Shop và Weather...")
    
    pcall(function()
        local wKeywords = {"starfall", "storm", "clear", "rain", "sunny", "meteor"}
        
        for _, kw in ipairs(wKeywords) do
            local wLabel = findTextLabelWithKeyword(PlayerGui, kw)
            if wLabel then
                weather.status = (kw:gsub("^%l", string.upper)) 
                
                local parentUI = wLabel.Parent
                for _, sibling in pairs(parentUI:GetChildren()) do
                    if sibling:IsA("TextLabel") and sibling ~= wLabel then
                        local m, s = sibling.Text:match("(%d+):(%d+)")
                        if m and s then
                            weather.duration = (tonumber(m) * 60) + tonumber(s)
                            break
                        end
                        local numsec = sibling.Text:match("(%d+)s")
                        if numsec then
                            weather.duration = tonumber(numsec)
                            break
                        end
                    end
                end
                break
            end
        end
        
        local s_seeds, s_gear = scanUIForStock(PlayerGui)
        
        for _, v in ipairs(s_seeds) do table.insert(seeds, v) end
        for _, v in ipairs(s_gear) do table.insert(gear, v) end
    end)
    
    local infoStr = string.format("Data: %d Hạt, %d Đồ\nWeather: %s (%ds)", #seeds, #gear, weather.status, weather.duration)
    updateUI("Status: ✅ Quét xong! Đang up...", infoStr, Color3.fromRGB(100, 255, 100))
    
    print(string.format("[GHZ Scanner] ✅ Hoàn tất! Lọc thành công Stock thực: Seeds: %d, Gears: %d | Thời Tiết: %s (%ds)", #seeds, #gear, weather.status, weather.duration))
    return seeds, gear, weather
end

-------------------------------------------------------------------------------
-- HÀM GỬI LÊN API SERVER
-------------------------------------------------------------------------------
local function postDataToAPI()
    local seeds, gear, weather = getGardenHorizonsData()
    
    if #seeds == 0 and #gear == 0 and weather.status == "None" then
        warn("[GHZ Script] ⚠️ Auto-scan không tìm thấy Data trên màn hình!")
        updateUI("Status: ⚠️ Không tìm thấy Shop UI!", nil, Color3.fromRGB(255, 100, 100))
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
        local success, response = pcall(function()
            return req({
                Url = API_URL,
                Method = "POST",
                Headers = {
                    ["Content-Type"] = "application/json"
                },
                Body = jsonData
            })
        end)
        
        if success then
            if response.StatusCode == 200 then
                print("[GHZ Script] ✅ Cập nhật API thành công lúc " .. os.date("%H:%M:%S"))
                updateUI("Status: ✅ Đã Up API thành công", nil, Color3.fromRGB(150, 255, 150))
            else
                warn("[GHZ Script] ❌ Lỗi sever/API:", response.StatusCode, response.Body)
                updateUI("Status: ❌ Lỗi Server API", nil, Color3.fromRGB(255, 100, 100))
            end
        else
            warn("[GHZ Script] ❌ Thất bại khi gửi request:", response)
            updateUI("Status: ❌ Request thất bại", nil, Color3.fromRGB(255, 100, 100))
        end
    else
        warn("[GHZ Script] ❌ Executor của bạn (Delta) bị thiếu hàm request!")
        updateUI("Status: ❌ Delta thiếu hàm request()", nil, Color3.fromRGB(255, 50, 50))
    end
end

-------------------------------------------------------------------------------
-- LOGIC TÍNH CHU KỲ 5 PHÚT (VD 19:05, 19:10)
-------------------------------------------------------------------------------
local function getSecondsUntilNextRestock()
    local timeT = os.date("*t")
    local currentMin = timeT.min
    local currentSec = timeT.sec
    
    local minutesToNext = 5 - (currentMin % 5)
    local secondsToNext = (minutesToNext * 60) - currentSec
    
    return secondsToNext + 3
end

-------------------------------------------------------------------------------
-- VÒNG LẶP CHẠY THEO CHU KỲ RESTOCK MẶC ĐỊNH
-------------------------------------------------------------------------------
task.spawn(function()
    print("[GHZ Script] 🚀 Bắt đầu trình lấy data cho Garden Horizons (Chu kỳ 5 phút - Chế độ Auto-Scan)")
    
    postDataToAPI()
    
    while true do
        local waitTime = getSecondsUntilNextRestock()
        
        -- Đếm ngược giây cho đẹp mắt lồng vào UI
        for i = waitTime, 1, -1 do
            local nextScanTime = os.date("%H:%M:%S", os.time() + i)
            updateUI(string.format("Status: ⏳ Đợi restock... (%ds)", i), nil, Color3.fromRGB(200, 200, 255))
            task.wait(1)
            -- Phá vỡ vòng lặp đếm ngược nếu UI bị xóa (người dùng tắt script)
            if not screenGui or not screenGui.Parent then return end
        end
        
        postDataToAPI()
    end
end)

