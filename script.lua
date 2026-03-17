local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

-- ⚠️ Đổi "localhost" thành IP LAN của máy tính (vd: "http://192.168.1.15:3456/api/update")
local API_URL = "https://zenithghz.qzz.io/api/update" 

local LocalPlayer = Players.LocalPlayer

-------------------------------------------------------------------------------
-- HỆ THỐNG QUÉT DỮ LIỆU TỪ BỘ NHỚ GAME (KHÔNG CẦN LƯỚT GIAO DIỆN)
-------------------------------------------------------------------------------

-- 1. Hàm quét thư mục chứa Data của Shop 
-- (Thông thường Data Shop sẽ lưu ở ReplicatedStorage.ShopData, ReplicatedStorage.Items, Workspace...)
local function scanFolderForItems(folder, category)
    local items = {}
    
    for _, itemObj in ipairs(folder:GetChildren()) do
        local itemName = itemObj.Name
        local itemQuantity = 1
        
        -- Dữ liệu Stock (Số lượng) thường được lưu ở các biến Value như IntValue, NumberValue ...
        -- Hoặc qua Attribute của Objejct
        local stockValue = itemObj:FindFirstChild("Stock") or itemObj:FindFirstChild("Amount") or itemObj:FindFirstChild("Quantity")
        
        if stockValue and stockValue:IsA("IntValue") or stockValue:IsA("NumberValue") then
            itemQuantity = stockValue.Value
        else
            -- Check Value thông qua Attribute (Tính năng mới của Roblox)
            local attrStock = itemObj:GetAttribute("Stock") or itemObj:GetAttribute("Quantity")
            if attrStock then
                itemQuantity = tonumber(attrStock)
            end
        end
        
        table.insert(items, {
            name = itemName,
            quantity = itemQuantity,
            category = category
        })
    end
    
    return items
end

-- 2. Đọc trực tiếp từ RemoteEvent / RemoteFunction (Dành cho game pro)
local function fetchDataFromRemote()
    -- CÁC GAME LỚN thường có 1 RemoteFunction để Client hỏi Server thông tin Shop
    -- VD: local shopData = ReplicatedStorage.Remotes.GetShop:InvokeServer()
    -- Phần này yêu cầu bạn dùng công cụ Dex/SimpleSpy để tìm đúng tên Remote của game!
    return nil -- Trả về nil mặc định nếu chưa có Remote
end

local function getMarketData()
    local seeds = {}
    local gear = {}
    local weather = { status = "Clear", duration = 0 }
    
    --------------------------------------------------------------------------
    -- TÌM SEED & GEAR QUA THƯ MỤC CỐ ĐỊNH (Không phụ thuộc UI bị ẩn)
    --------------------------------------------------------------------------
    -- Ví dụ GAME lưu Data ở ReplicatedStorage (Sửa tên thư mục "SeedData", "GearData" lại cho đúng Game của bạn)
    local seedFolder = ReplicatedStorage:FindFirstChild("SeedData", true) or ReplicatedStorage:FindFirstChild("Seeds", true)
    if seedFolder then
        seeds = scanFolderForItems(seedFolder, "seed")
    end
    
    local gearFolder = ReplicatedStorage:FindFirstChild("GearData", true) or ReplicatedStorage:FindFirstChild("Gears", true) or ReplicatedStorage:FindFirstChild("Equipment", true)
    if gearFolder then
        gear = scanFolderForItems(gearFolder, "gear")
    end
    
    --------------------------------------------------------------------------
    -- PHƯƠNG ÁN DỰ PHÒNG: Quét Game State qua Player's Data hoặc ServerStats
    --------------------------------------------------------------------------
    if #seeds == 0 and #gear == 0 then
        -- Thử tìm trong Workspace (Biển báo Shop)
        local shopBoard = Workspace:FindFirstChild("ShopBoard", true) or Workspace:FindFirstChild("MarketStock", true)
        if shopBoard then
            -- Quét Attribute của cái bảng Shop
            local attributes = shopBoard:GetAttributes()
            for key, val in pairs(attributes) do
                if type(val) == "number" then
                    -- Quy ước tự động: Nếu tên key có chữ Seed thì bỏ vào Seed, còn lại vào Gear
                    if string.match(key:lower(), "seed") then
                        table.insert(seeds, { name = key, quantity = val, category = "seed" })
                    else
                        table.insert(gear, { name = key, quantity = val, category = "gear" })
                    end
                end
            end
        end
    end
    
    --------------------------------------------------------------------------
    -- TÌM WEATHER STATE (Thường lưu ở Lighting hoặc Workspace.Weather)
    --------------------------------------------------------------------------
    local lighting = game:GetService("Lighting")
    -- Lấy thông qua Attribute
    local currentWea = lighting:GetAttribute("CurrentWeather") or Workspace:GetAttribute("Weather") or ReplicatedStorage:GetAttribute("WeatherState")
    if currentWea then
        weather.status = tostring(currentWea)
    end
    
    -- Lấy thời gian còn lại (Duration)
    local durationVal = lighting:GetAttribute("WeatherDuration") or lighting:GetAttribute("WeatherTimeLeft")
    if durationVal then
        weather.duration = tonumber(durationVal)
    end
    
    -- In Log Debug
    print(string.format("[GHZ Parser] Mined Data -> Seeds: %d, Gears: %d | Thời Tiết: %s (%ds)", #seeds, #gear, weather.status, weather.duration))
    
    return seeds, gear, weather
end

-------------------------------------------------------------------------------
-- HỆ THỐNG GỬI API 
-------------------------------------------------------------------------------
local function sendData()
    local seeds, gear, weather = getMarketData()
    
    -- Nếu vẫn không lấy được dữ liệu nội bộ nào
    if #seeds == 0 and #gear == 0 then
        warn("[GHZ Script] Chưa tìm trúng thư mục Data của Game! Bạn cần mở SimpleSpy/Dex để tìm tên Thư Mục chuẩn xác ở ReplicatedStorage.")
        -- Dữ liệu mẫu (Gửi lên để API không bị crash)
        seeds = {{ name = "Unknown Seed", quantity = 0, category = "seed" }} 
        gear = {{ name = "Unknown Gear", quantity = 0, category = "gear" }} 
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
        local response = req({
            Url = API_URL,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json"
            },
            Body = jsonData
        })
        
        if response.StatusCode == 200 then
            print("[GHZ Script] ✅ Bơm Data Ẩn thành công!", response.Body)
        else
            warn("[GHZ Script] ❌ Lỗi API:", response.StatusCode)
        end
    else
        warn("[GHZ Script] ❌ Executor thiếu hụt hàm request()!")
    end
end

-- Vòng lặp gửi tự động (Mỗi 15 giây)
task.spawn(function()
    while true do
        local success, err = pcall(sendData)
        if not success then
            warn("[GHZ Script] Lỗi lúc quét Game Data:", err)
        end
        task.wait(15)
    end
end)

print("[GHZ Script] 🕵️ Trình lấy dữ liệu 'Ẩn' đã khởi chạy. Không cần cuộn Cửa hàng!")
