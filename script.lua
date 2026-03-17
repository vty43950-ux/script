local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

-- API URL CỦA BẠN 
local API_URL = "https://zenithghz.indevs.in/api/update"

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
    
    -- Blacklist các từ khóa của HUD/Stats/UI rác
    local blacklist = {
        "harvested", "earned", "playtime", "shillings", "total", "level", "xp", 
        "balance", "owned", "shilling", "rank", "prestige", "quest", "inventory",
        "buy", "sell", "confirm", "close", "back", "next", "equip", "status", "v643",
        "shilling", "money", "cash", "gems"
    }

    -- Duyệt tìm các khung chứa (ScrollingFrame/Frame có layout)
    for _, container in pairs(guiLayer:GetDescendants()) do
        -- SKIP CHÍNH UI CỦA SCRIPT ĐỂ KHÔNG TỰ QUÉT MÌNH
        if screenGui and container:IsDescendantOf(screenGui) then continue end

        if (container:IsA("ScrollingFrame") or container:IsA("Frame")) and 
           (container:FindFirstChildWhichIsA("UIGridLayout") or container:FindFirstChildWhichIsA("UIListLayout")) then
            
            -- Duyệt từng ô vật phẩm (con trực tiếp của container)
            for _, itemUI in pairs(container:GetChildren()) do
                if itemUI:IsA("Frame") or itemUI:IsA("ImageLabel") or itemUI:IsA("TextButton") then
                    
                    local cardLabels = {}
                    local itemImage = ""
                    local isJunkCard = false
                    local isSoldOut = false
                    
                    -- 1. THU THẬP VÀ KIỂM TRA TOÀN BỘ CARD
                    for _, child in pairs(itemUI:GetDescendants()) do
                        if child:IsA("TextLabel") and child.Text ~= "" and child.Visible then
                            local txt = child.Text
                            local ltxt = string.lower(txt)
                            
                            -- A. Kiểm tra Blacklist (Nếu dính 1 chữ rác -> Bỏ cả card)
                            for _, word in ipairs(blacklist) do
                                if string.find(ltxt, word) then isJunkCard = true break end
                            end
                            
                            -- B. Kiểm tra ký tự đặc biệt (@, %)
                            if string.find(txt, "@") or string.find(txt, "%%") then isJunkCard = true end
                            
                            -- C. Kiểm tra Hết hàng (NO STOCK / SOLD OUT)
                            if string.find(ltxt, "no stock") or string.find(ltxt, "sold out") then isSoldOut = true end
                            
                            if isJunkCard or isSoldOut then break end
                            table.insert(cardLabels, txt)
                        elseif child:IsA("ImageLabel") and child.Visible and child.Image ~= "" then
                            -- D. Lấy Asset ID từ ảnh roblox
                            local assetId = string.match(child.Image, "%d+")
                            if assetId and itemImage == "" then
                                itemImage = "https://www.roblox.com/asset-thumbnail/image?assetId=" .. assetId .. "&width=420&height=420&format=png"
                            end
                        end
                    end
                    
                    -- NẾU LÀ CARD RÁC HOẶC HẾT HÀNG -> BỎ QUA NGAY
                    if isJunkCard or isSoldOut or #cardLabels == 0 then continue end
                    
                    -- 2. PHÂN TÍCH DỮ LIỆU TRONG CARD HỢP LỆ
                    local itemName = ""
                    local itemStock = -1
                    local isActuallyStock = false
                    
                    for _, text in ipairs(cardLabels) do
                        local lowerText = string.lower(text)
                        
                        -- TÌM STOCK (Ưu tiên những nhãn có chữ Stock/Left hoặc có dấu x)
                        if not isPriceOrMoney(text) then
                            local num = extractNumber(text)
                            if num then
                                -- Nếu text chứa "stock", "left" hoặc định dạng "Nx" hoặc "xN" -> Đây là stock chuẩn
                                if string.find(lowerText, "stock") or string.find(lowerText, "left") or string.match(text, "%d+[xX]") or string.match(text, "[xX]%s*%d+") then
                                    itemStock = num
                                    isActuallyStock = true
                                elseif itemStock == -1 then
                                    -- Nếu chưa tìm thấy stock chuẩn, lấy tạm số đầu tiên thấy được (có thể là fallback nếu card không có chữ "Stock")
                                    itemStock = num
                                end
                            end
                        end
                        
                        -- TÌM TÊN (Nhãn dài nhất không phải số/giá)
                        if not isPriceOrMoney(text) and not string.find(lowerText, "stock") and not string.find(lowerText, "left") then
                            -- LỌC TÊN: Không được là số thuần túy (VD: "358") và độ dài > 2
                            if not tonumber(text) and string.len(text) > 2 and not string.match(text, "^%d+[xX]$") and not string.match(text, "^[xX]%d+$") then
                                if string.len(text) > string.len(itemName) and string.len(text) < 40 then
                                    itemName = text
                                end
                            end
                        end
                    end
                    
                    -- 3. LƯU KẾT QUẢ
                    if itemName ~= "" and itemStock > 0 and isActuallyStock and not results.foundTracker[itemName] then
                        local cat = guessItemCategory(itemName)
                        table.insert(cat == "seed" and results.seeds or results.gear, {
                            name = itemName,
                            quantity = itemStock,
                            category = cat,
                            image = itemImage -- Thêm ảnh vào payload (Roblox Asset ID)
                        })
                        results.foundTracker[itemName] = true
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
    
    updateUI("Status: 🔍 Đang lọc Stock (>0)...", nil, Color3.fromRGB(255, 200, 100))
    
    pcall(function()
        -- 1. Weather scan (giữ nguyên vì logic này khá ổn)
        local wKeywords = {"starfall", "storm", "clear", "rain", "sunny", "meteor"}
        for _, kw in ipairs(wKeywords) do
            local wLabel = findTextLabelWithKeyword(PlayerGui, kw)
            if wLabel then
                weather.status = (kw:gsub("^%l", string.upper)) 
                local parentUI = wLabel.Parent
                for _, sibling in pairs(parentUI:GetChildren()) do
                    if sibling:IsA("TextLabel") and sibling ~= wLabel then
                        local m, s = sibling.Text:match("(%d+):(%d+)")
                        if m and s then weather.duration = (tonumber(m) * 60) + tonumber(s) break end
                        local numsec = sibling.Text:match("(%d+)s")
                        if numsec then weather.duration = tonumber(numsec) break end
                    end
                end
                break
            end
        end
        
        -- 2. Item scan (Dùng logic Container mới)
        seeds, gear = scanUIForStock(PlayerGui)
    end)
    
    local infoStr = string.format("Data: %d Hạt, %d Đồ (Đã lọc)\nWeather: %s (%ds)", #seeds, #gear, weather.status, weather.duration)
    updateUI("Status: ✅ Đã lọc xong!", infoStr, Color3.fromRGB(130, 255, 130))
    
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
    
    return secondsToNext
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


