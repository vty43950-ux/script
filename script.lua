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

-- Whitelist tên Hạt Giống (Seeds)
local SEED_NAMES = {
    "onion", "corn", "carrot", "potato", "tomato", "blueberry", "strawberry",
    "grape", "wheat", "pumpkin", "watermelon", "mushroom", "apple", "orange",
    "lemon", "cherry", "pear", "pineapple", "coconut", "mango", "peach",
    "pepper", "eggplant", "sunflower", "bamboo", "cactus", "rose", "tulip",
    "lily", "daisy", "orchid", "lavender", "seed", "sprout", "plant",
    "fertile soil", "soil"  -- Fertile Soil là seed, không phải gear
}

-- Whitelist tên Đồ Dùng (Gear)
local GEAR_NAMES = {
    "sprinkler", "watering can", "trowel", "shovel", "hoe", "scythe", "basket",
    "reverter", "favorite tool", "can", "gloves", "boots", "hat",
    "fertilizer", "rake", "pitchfork", "recall wrench", "wrench",
    "watering", "harvest"  -- Chỉ giữ gear thực sự
}

-- Item đặc biệt CẦN nhãn Stock/Left TỰ MINH mới nhận (tránh ghost stock)
local STRICT_ITEMS = {
    "mushroom",  -- Mushroom hay bị ghost stock
}

-- Trả về "seed", "gear", hoặc NIL nếu không khớp whitelist
local function guessItemCategory(itemName)
    local name = string.lower(itemName)
    for _, keyword in ipairs(SEED_NAMES) do
        if string.find(name, keyword) then return "seed" end
    end
    for _, keyword in ipairs(GEAR_NAMES) do
        if string.find(name, keyword) then return "gear" end
    end
    return nil  -- Không trong whitelist -> Bỏ qua hoàn toàn
end

-- Rút trích số ra khỏi chuỗi (Ví dụ "Stock: 15" -> 15)
local function extractNumber(text)
    if not text then return nil end
    local num = string.match(text, "%d+")
    return num and tonumber(num) or nil
end

-- Kiểm tra text có phải giá tiền không (Garden Horizons dùng Shillings)
local function isPriceOrMoney(text)
    local t = string.lower(text)
    -- Từ khóa tiền tệ rõ ràng
    if string.match(t, "%$") or string.find(t, "coin") or string.find(t, "cash")
    or string.find(t, "gem") or string.find(t, "shilling") then
        return true
    end
    -- Số lớn úm tròn (>= 500) rất có khả năng là giá tiền
    local n = tonumber(string.match(text, "^%d+$"))
    if n and n >= 500 then return true end
    return false
end

-- Trích xuất số NHẾ NHẤT trong một string (tránh nhầm số giá tiền lớn)
local function extractSmallestNumber(text)
    local smallest = nil
    for n in string.gmatch(text, "%d+") do
        local num = tonumber(n)
        if num and num > 0 and num <= 999 then  -- Cập giới hạn hợp lý cho số lượng
            if not smallest or num < smallest then
                smallest = num
            end
        end
    end
    return smallest
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
            
            -- TÌM STOCK: Tìm nhãn có từ khóa stock/left/remain hoặc định dạng "Nx"/"xN"
            if not isPriceOrMoney(text) then
                local isStockLabel = string.find(lowerText, "stock") 
                    or string.find(lowerText, "left")
                    or string.find(lowerText, "remain")
                    or string.match(text, "^%d+[xX]$")   -- "9x"
                    or string.match(text, "^[xX]%d+$")   -- "x9"
                if isStockLabel then
                    -- Lấy số NHỎ NHẤT trong nhãn (tránh nhầm giá)
                    local num = extractSmallestNumber(text)
                    if num and num > 0 then
                        itemStock = num
                        isExplicitStock = true
                    end
                end
            end
            
            -- TÌM TÊN: Nhãn dài, không phải số, không phải tiền
            if not isPriceOrMoney(text) then
                local isNumberLike = tonumber(text) 
                    or string.match(text, "^%d+[xX]$")
                    or string.match(text, "^[xX]%s*%d+$")
                    or string.match(text, "^[%d%s]+$")
                local isStockTag = string.find(lowerText, "stock") or string.find(lowerText, "left")
                if not isNumberLike and not isStockTag and string.len(text) > 2 and string.len(text) < 40 then
                    if string.len(text) > string.len(itemName) then
                        itemName = text
                    end
                end
            end
        end
        
        -- Nếu KHÔNG tìm thấy nhãn stock rõ ràng:
        -- STRICT_ITEMS (VD: Mushroom) -> Bỏ qua hoàn toàn (ghost stock)
        -- Các item khác -> Thử fallback: tìm số nhỏ (1-99)
        if not isExplicitStock then
            -- Kiểm tra có phải strict item không
            local isStrict = false
            for _, strictName in ipairs(STRICT_ITEMS) do
                if string.find(string.lower(itemName), strictName) then
                    isStrict = true
                    break
                end
            end
            
            if isStrict then
                -- Strict item: Yêu cầu nhãn số TƯᨌNG MINH, không fallback
                return
            else
                -- Item bình thường: fallback tìm số nhỏ (1-99)
                for _, text in ipairs(cardLabels) do
                    if not isPriceOrMoney(text) then
                        local lt = string.lower(text)
                        local isStockTag = string.find(lt, "stock") or string.find(lt, "left")
                        if not isStockTag then
                            for n in string.gmatch(text, "%d+") do
                                local num = tonumber(n)
                                if num and num >= 1 and num <= 99 then
                                    if itemStock == -1 or num < itemStock then
                                        itemStock = num
                                        isExplicitStock = true
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        if itemName == "" or itemStock <= 0 then return end
        
        -- Kiểm tra whitelist - Bỏ ngay nếu không khớp
        local cat = guessItemCategory(itemName)
        if not cat then return end  -- Không trong whitelist -> Bỏ qua
        
        if not results.foundTracker[itemName] then
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

    -- CHẠY QUÉT CHUẨN (Container có Layout - đáng tin nhất)
    for _, container in pairs(guiLayer:GetDescendants()) do
        if screenGui and container:IsDescendantOf(screenGui) then continue end

        if (container:IsA("ScrollingFrame") or container:IsA("Frame")) and 
           (container:FindFirstChildWhichIsA("UIGridLayout") or container:FindFirstChildWhichIsA("UIListLayout")) then
            for _, itemUI in pairs(container:GetChildren()) do
                processItemUI(itemUI)
            end
        end
    end
    -- LƯU Ý: Đã tắt Deep Scan vì nó quét nhầm quá nhiều Frame không phải Shop UI
    
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
-- TÍNH UNIX TIMESTAMP CỦA MỐC RESTOCK 5 PHÚT TIẾP THEO (UTC)
-- Game restock mỗi mốc :00, :05, :10, :15, ... :55 theo UTC
-- Dùng os.time() thay vì đếm ngược để KHÔNG bị drift từ task.wait()
-------------------------------------------------------------------------------
local function getNextRestockTimestamp()
    local now = os.time()
    -- Số giây đã qua trong chu kỳ 5 phút hiện tại
    local secIntoCycle = now % 300
    -- Timestamp của mốc 5 phút tiếp theo, trừ 1 giây để bù latency
    return now + (300 - secIntoCycle) - 1
end

-- Định dạng thời gian UTC để hiển thị
local function fmtUTC(ts)
    local t = os.date("!*t", ts)
    return string.format("UTC %02d:%02d:%02d", t.hour, t.min, t.sec)
end

-------------------------------------------------------------------------------
-- VÒNG LẶP CHÍNH — THEO TIMESTAMP TUYỆT ĐỐI, KHÔNG DRIFT
-------------------------------------------------------------------------------
task.spawn(function()
    print("[GHZ Script] 🚀 Bắt đầu trình lấy data (No-Drift Build 1.6)")
    
    -- Quét ngay lần đầu
    postDataToAPI()
    
    while true do
        -- Tính mốc thời gian tuyệt đối cho lần restock kế tiếp
        local targetTs = getNextRestockTimestamp()
        
        print(string.format("[GHZ Script] ⏳ Restock kế tiếp lúc %s", fmtUTC(targetTs)))
        
        -- Đợi đến mốc đó bằng cách so sánh os.time() thực tế
        -- KHÔNG đếm ngược bằng i-- vì task.wait(1) hay bị drift
        while os.time() < targetTs do
            local remaining = targetTs - os.time()
            local mins = math.floor(remaining / 60)
            local secs = remaining % 60
            updateUI(
                string.format("Status: ⏳ Restock trong %02d:%02d", mins, secs),
                string.format("Tiếp theo: %s", fmtUTC(targetTs)),
                Color3.fromRGB(180, 180, 255)
            )
            task.wait(0.5)   -- Poll mỗi 0.5s để UI mượt, nhưng không ảnh hưởng timing
            if not screenGui or not screenGui.Parent then return end
        end
        
        postDataToAPI()
    end
end)
