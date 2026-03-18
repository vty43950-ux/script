-------------------------------------------------------------------------------
-- 🌱 GHZ STOCK BOT  v6  — Garden Horizons (The Ultimate Hybrid)
-- KẾT HỢP: 
-- 1/ Hook thụ động vào `ShopRestocked` (xịn nhất, tiết kiệm nhất).
-- 2/ Hook mạnh bạo vào TẤT CẢ remotes (Catch-all) để bắt `ReplicaSetValues`.
-- 3/ Quét AI Giao diện (Fallback) ngay lúc mới bật tool để có data TỨC THÌ.
-- 4/ Admin Notify hook
-------------------------------------------------------------------------------

if _G.GHZ_Bot_Running then return end
_G.GHZ_Bot_Running = true

-- ══════════════════════════════════════════════════════════════════════════════
-- ⚙️  CẤU HÌNH
-- ══════════════════════════════════════════════════════════════════════════════
local CONFIG = {
    API_URL          = "https://zenithghz.qzz.io/api/update",
    NOTIFY_URL       = "https://zenithghz.qzz.io/api/adminnotify",
    API_ENABLED      = true,

    WEBHOOK_URL      = "https://discord.com/api/webhooks/PASTE_HERE",
    WEBHOOK_ENABLED  = false,

    SKIP_EMPTY       = true,
    ANTI_AFK         = true,
    DISABLE_RENDERING = true,
}

local HttpService       = game:GetService("HttpService")
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui           = game:GetService("CoreGui")
local RunService        = game:GetService("RunService")
local VirtualUser       = cloneref(game:GetService("VirtualUser"))
local LocalPlayer       = Players.LocalPlayer

if CONFIG.DISABLE_RENDERING then
    pcall(function() RunService:Set3dRenderingEnabled(false) end)
end

local req = (syn and syn.request) or (http and http.request) or request

-- ══════════════════════════════════════════════════════════════════════════════
-- 🖥️ UI CỦA BOT
-- ══════════════════════════════════════════════════════════════════════════════
local uiLayer = (gethui and gethui()) or CoreGui
if uiLayer:FindFirstChild("GHZ_Bot_UI") then uiLayer.GHZ_Bot_UI:Destroy() end

local sg = Instance.new("ScreenGui")
sg.Name = "GHZ_Bot_UI"; sg.ResetOnSpawn = false
sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling; sg.Parent = uiLayer

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 300, 0, 200); frame.Position = UDim2.new(0, 10, 0, 10)
frame.BackgroundColor3 = Color3.fromRGB(15, 18, 25); frame.BackgroundTransparency = 0.05
frame.BorderSizePixel = 0; frame.Parent = sg
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)
local stroke = Instance.new("UIStroke"); stroke.Color = Color3.fromRGB(50, 220, 80)
stroke.Thickness = 1.5; stroke.Transparency = 0.35; stroke.Parent = frame

local titleBar = Instance.new("Frame"); titleBar.Size = UDim2.new(1,0,0,30)
titleBar.BackgroundColor3 = Color3.fromRGB(18, 60, 22); titleBar.BorderSizePixel = 0; titleBar.Parent = frame
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0,10)
local titleLbl = Instance.new("TextLabel"); titleLbl.Size = UDim2.new(1,0,1,0)
titleLbl.BackgroundTransparency = 1; titleLbl.Text = "🌱 GHZ Bot v6 ✦ Hybrid"
titleLbl.TextColor3 = Color3.fromRGB(140, 255, 150); titleLbl.Font = Enum.Font.GothamBold
titleLbl.TextSize = 13; titleLbl.Parent = titleBar

local function mkRow(y, color)
    local l = Instance.new("TextLabel"); l.Size = UDim2.new(1,-14,0,20)
    l.Position = UDim2.new(0,7,0,y); l.BackgroundTransparency = 1
    l.TextColor3 = color or Color3.fromRGB(220,220,220); l.Font = Enum.Font.Gotham
    l.TextSize = 11; l.TextXAlignment = Enum.TextXAlignment.Left; l.Parent = frame; return l
end

local rowStatus  = mkRow(33,  Color3.fromRGB(255, 230, 80))
local rowCount   = mkRow(53,  Color3.fromRGB(180, 180, 255))
local rowSeeds   = mkRow(75,  Color3.fromRGB(100, 255, 100))
local rowGear    = mkRow(95,  Color3.fromRGB(255, 190, 80))
local rowWeather = mkRow(115, Color3.fromRGB(100, 205, 255))
local rowTime    = mkRow(135, Color3.fromRGB(160, 160, 160))
local rowAPI     = mkRow(158, Color3.fromRGB(150, 150, 150))

rowStatus.Text  = "Status: 🟡 Khởi động..."
rowCount.Text   = "⏳ Restock: --:--"
rowSeeds.Text   = "🌿 Seeds: pending..."
rowGear.Text    = "⚙️  Gear:  pending..."
rowWeather.Text = "⛅ Weather: None"
rowTime.Text    = "🕐 Cập nhật: chưa có"
rowAPI.Text     = "📡 API: -   💬 Hook: " .. (CONFIG.WEBHOOK_ENABLED and "bật" or "tắt")

-- Dữ liệu state
local currentWeather = { status = "None", duration = 0 }
local lastSeeds, lastGear = {}, {}
local lastDataHash = ""

-- ══════════════════════════════════════════════════════════════════════════════
-- 📬 GỬI DỮ LIỆU ĐI API + WEBHOOK
-- ══════════════════════════════════════════════════════════════════════════════
local function sendWebhook(seeds, gear, weather)
    if not CONFIG.WEBHOOK_ENABLED or not req or CONFIG.WEBHOOK_URL:find("PASTE") then return false end
    local fields = {}
    if #seeds > 0 then
        local s = ""
        for _, it in ipairs(seeds) do s = s .. string.format("🌱 **%s** — %d\n", it.name, it.quantity) end
        table.insert(fields, { name="🌿 SEEDS", value=s, inline=true })
    end
    if #gear > 0 then
        local g = ""
        for _, it in ipairs(gear) do g = g .. string.format("🔧 **%s** — %d\n", it.name, it.quantity) end
        table.insert(fields, { name="⚙️ GEAR", value=g, inline=true })
    end
    if weather and weather.status and weather.status ~= "None" then
        table.insert(fields, { name="⛅ WEATHER", value=string.format("**%s**", weather.status), inline=false })
    end
    if #fields == 0 then return false end

    pcall(function()
        task.spawn(function()
            req({ Url=CONFIG.WEBHOOK_URL, Method="POST", Headers={["Content-Type"]="application/json"},
                Body=HttpService:JSONEncode({
                    username = "🌱 GHZ Stock Tracker",
                    embeds   = {{ title="🌱 GHZ Restock Update!", color=0x38ee17, fields=fields, timestamp=DateTime.now():ToIsoDate() }}
                })
            })
        end)
    end)
    return true
end

local function postAPI(seeds, gear, weather)
    if not CONFIG.API_ENABLED or not req then return false end
    local ok, res = pcall(function()
        return req({ Url=CONFIG.API_URL, Method="POST", Headers={["Content-Type"]="application/json"},
            Body=HttpService:JSONEncode({ seeds=seeds, gear=gear, weather=weather or {status="None",duration=0}, timestamp=os.time() })
        })
    end)
    return ok and res and res.StatusCode == 200
end

local function postAdminMessage(msg)
    if not CONFIG.API_ENABLED or not req or not CONFIG.NOTIFY_URL then return false end
    pcall(function()
        task.spawn(function()
            req({ Url=CONFIG.NOTIFY_URL, Method="POST", Headers={["Content-Type"]="application/json"},
                Body=HttpService:JSONEncode({ message=msg, timestamp=os.time() }) })
            if CONFIG.WEBHOOK_ENABLED and not CONFIG.WEBHOOK_URL:find("PASTE") then
                req({ Url=CONFIG.WEBHOOK_URL, Method="POST", Headers={["Content-Type"]="application/json"},
                    Body=HttpService:JSONEncode({ username="⚠️ Admin", content="@everyone **ADMIN: ** `" .. msg .. "`" }) })
            end
        end)
    end)
end

-- ══════════════════════════════════════════════════════════════════════════════
-- 🧠 HÀM XỬ LÝ KHI NHẬN ĐƯỢC DATA
-- ══════════════════════════════════════════════════════════════════════════════
local function onRestockData(seeds, gear, sourceName)
    if #seeds == 0 and #gear == 0 then return end
    
    -- Tránh gửi trùng data liên tục
    local newHash = HttpService:JSONEncode(seeds) .. HttpService:JSONEncode(gear)
    if newHash == lastDataHash then return end
    lastDataHash = newHash
    lastSeeds, lastGear = seeds, gear

    rowSeeds.Text  = string.format("🌿 Seeds: %d món", #seeds)
    rowGear.Text   = string.format("⚙️  Gear:  %d món", #gear)
    rowTime.Text   = "🕐 Cập nhật: " .. os.date("%H:%M:%S") .. " (" .. sourceName .. ")"
    rowStatus.Text = "Status: ✅ Đã cập nhật!"

    task.spawn(function()
        local apiOk  = postAPI(seeds, gear, currentWeather)
        local hookOk = sendWebhook(seeds, gear, currentWeather)
        rowAPI.Text  = "📡 API:" .. (apiOk and "✅" or "❌") .. "  💬 Hook:" .. (hookOk and "✅" or "❌")
    end)
end


-- ══════════════════════════════════════════════════════════════════════════════
-- PHƯƠNG PHÁP 1: PARSE THEO CẤU TRÚC JSON REMOTE Server (Độ chính xác: Bất tử)
-- Cấu trúc: {SeedShop={Items={Carrot={Amount=15}}}}
-- ══════════════════════════════════════════════════════════════════════════════
local SEED_SHOPS = {"seedshop", "seed shop", "seeds"}
local GEAR_SHOPS = {"gearshop", "gear shop", "gears", "toolshop"}

local function getCat(shopName)
    local n = shopName:lower():gsub("%s+","")
    for _, k in ipairs(SEED_SHOPS) do if n:find(k) then return "seed" end end
    for _, k in ipairs(GEAR_SHOPS) do if n:find(k) then return "gear" end end
end

local function parseRemoteTable(dataTable)
    local seeds, gear = {}, {}
    if type(dataTable) ~= "table" then return seeds, gear end

    -- Đệ quy tìm table chứa SeedShop hoặc GearShop
    local function searchForShops(t, depth)
        if depth > 4 then return end
        for k, v in pairs(t) do
            local cat = type(k) == "string" and getCat(k) or nil
            if cat and type(v) == "table" then
                local items = v.Items or v.items or v
                if type(items) == "table" then
                    for itemName, itemData in pairs(items) do
                        local amt = type(itemData)=="table" and (itemData.Amount or itemData.amount or itemData.Stock) or (type(itemData)=="number" and itemData or nil)
                        if amt then
                            amt = tonumber(amt) or 0
                            if not CONFIG.SKIP_EMPTY or amt > 0 then
                                local entry = {name=tostring(itemName), quantity=amt, category=cat}
                                if cat=="seed" then table.insert(seeds,entry) else table.insert(gear,entry) end
                            end
                        end
                    end
                end
            elseif type(v) == "table" then
                searchForShops(v, depth + 1)
            end
        end
    end
    
    searchForShops(dataTable, 1)
    return seeds, gear
end

-- ══════════════════════════════════════════════════════════════════════════════
-- PHƯƠNG PHÁP 2: QUÉT UI (Dành cho Cập Nhật Khởi Động)
-- ══════════════════════════════════════════════════════════════════════════════
local SEED_NAMES = {"onion", "corn", "carrot", "potato", "tomato", "blueberry", "strawberry", "grape", "wheat", "pumpkin", "watermelon", "mushroom", "apple", "orange", "lemon", "cherry", "pear", "pineapple", "coconut", "mango", "peach", "pepper", "eggplant", "sunflower", "bamboo", "cactus", "rose", "lavender", "seed", "sprout", "fertile soil"}
local GEAR_NAMES = {"sprinkler", "watering", "trowel", "shovel", "hoe", "scythe", "basket", "reverter", "favorite", "tool", "can", "pot"}

local function uiGuessCat(itemName)
    local name = itemName:lower()
    if name:find("fertile soil") then return "seed" end
    for _, k in ipairs(SEED_NAMES) do if name:find(k) then return "seed" end end
    for _, k in ipairs(GEAR_NAMES) do if name:find(k) then return "gear" end end
    return nil
end

local function scanUserInterface()
    local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
    local seeds, gear = {}, {}
    local tracked = {}
    
    for _, gui in pairs(PlayerGui:GetChildren()) do
        if gui:IsA("ScreenGui") and gui.Enabled then
            if not gui.Name:lower():find("inventory") then
                for _, container in pairs(gui:GetDescendants()) do
                    if (container:IsA("ScrollingFrame") or container:IsA("Frame")) and 
                       (container:FindFirstChildWhichIsA("UIGridLayout") or container:FindFirstChildWhichIsA("UIListLayout")) then
                        for _, itemUI in pairs(container:GetChildren()) do
                            if itemUI:IsA("Frame") or itemUI:IsA("ImageLabel") or itemUI:IsA("TextButton") then
                                local lbls = {}
                                local bestName = ""
                                local isSoldOut = false
                                
                                for _, child in pairs(itemUI:GetDescendants()) do
                                    if child:IsA("TextLabel") and child.Visible and child.Text ~= "" then
                                        local txt = child.Text
                                        local lowerTxt = txt:lower()
                                        if lowerTxt:find("sold out") or lowerTxt:find("0 left") then isSoldOut = true end
                                        
                                        local isJunk = lowerTxt:find("harvest") or lowerTxt:find("confirm") or lowerTxt:find("owned")
                                        if not isJunk and not (lowerTxt:find("%$") or tonumber(txt) and tonumber(txt)>500) then
                                            table.insert(lbls, txt)
                                            if uiGuessCat(txt) and #txt > #bestName then bestName = txt end
                                        end
                                    end
                                end
                                
                                if not isSoldOut and bestName ~= "" then
                                    local qty = 0
                                    for _, txt in ipairs(lbls) do
                                        if txt ~= bestName then
                                            local num = tonumber(string.match(txt, "%d+"))
                                            if num and num > 0 and num < 999 then qty = num; break; end
                                        end
                                    end
                                    if qty <= 0 then
                                        local match = string.match(bestName, "x(%d+)") or string.match(bestName, "(%d+)x")
                                        if match then qty = tonumber(match) end
                                    end
                                    
                                    if qty > 0 and not tracked[bestName] then
                                        tracked[bestName] = true
                                        local cat = uiGuessCat(bestName)
                                        table.insert(cat == "seed" and seeds or gear, {name = bestName, quantity = qty, category=cat})
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return seeds, gear
end

-- ══════════════════════════════════════════════════════════════════════════════
-- 🎯 LẮNG NGHE DỮ LIỆU TỪ GAME (Hooks)
-- ══════════════════════════════════════════════════════════════════════════════

local function hookGameRemotes()
    local remotes = ReplicatedStorage:WaitForChild("RemoteEvents", 10)
    if not remotes then return false end
    
    -- 1. Móc riêng ShopRestocked
    local shopRE = remotes:FindFirstChild("ShopRestocked")
    if shopRE then
        shopRE.OnClientEvent:Connect(function(...)
            local args = {...}
            print("[GHZ Bot] 🔔 ShopRestocked fired!")
            for _, arg in ipairs(args) do
                local s, g = parseRemoteTable(arg)
                if #s > 0 or #g > 0 then onRestockData(s, g, "ServerRestock") end
            end
        end)
    end
    
    -- 2. Móc ReplicaSetValues và những remote giấu mặt (Catch-all)
    for _, rem in pairs(remotes:GetChildren()) do
        if rem:IsA("RemoteEvent") and rem.Name ~= "ShopRestocked" then
            rem.OnClientEvent:Connect(function(...)
                local args = {...}
                for _, arg in ipairs(args) do
                    -- Nếu arg là table mang giao diện shop
                    if type(arg) == "table" then
                        local flatStr = HttpService:JSONEncode(arg)
                        if flatStr:find("SeedShop") or flatStr:find("MaxAmount") then
                            local s, g = parseRemoteTable(arg)
                            if #s > 0 or #g > 0 then onRestockData(s, g, "ReplicaData") end
                        end
                    end
                end
            end)
        end
    end
    
    -- 3. Móc thời tiết
    local weatherNames = {"WeatherEvent", "WeatherUpdate", "Weather"}
    for _, wName in ipairs(weatherNames) do
        local wRE = remotes:FindFirstChild(wName)
        if wRE then
            wRE.OnClientEvent:Connect(function(...)
                local args = {...}
                for _, arg in ipairs(args) do
                    if type(arg) == "string" then
                        currentWeather.status = arg; rowWeather.Text = "⛅ Weather: " .. arg
                        task.spawn(function() sendWebhook({}, {}, currentWeather) end)
                    elseif type(arg) == "table" then
                        currentWeather.status = arg.name or arg.status or "Unknown"
                        rowWeather.Text = "⛅ Weather: " .. currentWeather.status
                        task.spawn(function() sendWebhook({}, {}, currentWeather) end)
                    end
                end
            end)
        end
    end
end

-- Admin hook
local function hookAdminMessages()
    pcall(function()
        game:GetService("TextChatService").MessageReceived:Connect(function(msg)
            local t = msg.Text
            if t:match("^%[Server%]") or t:match("^%[Admin%]") then postAdminMessage(t) end
        end)
    end)
    pcall(function()
        local cEvts = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
        if cEvts and cEvts:FindFirstChild("OnMessageDoneFiltering") then
            cEvts.OnMessageDoneFiltering.OnClientEvent:Connect(function(m)
                if type(m)=="table" and m.Message and (m.MessageType=="System" or m.Message:match("^%[Admin%]")) then
                    postAdminMessage(m.Message)
                end
            end)
        end
    end)
end

-- ══════════════════════════════════════════════════════════════════════════════
-- 🛡️ ANTI-AFK & COUNTDOWN
-- ══════════════════════════════════════════════════════════════════════════════
if CONFIG.ANTI_AFK then
    LocalPlayer.Idled:Connect(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end)
end

task.spawn(function()
    while sg and sg.Parent do
        local t   = os.date("!*t")
        local sec = (t.min % 5) * 60 + t.sec
        local left = math.max(300 - sec, 1)
        rowCount.Text = string.format("⏳ Restock UTC: %02d:%02d", math.floor(left/60), left%60)
        
        -- Nếu đếm ngược về < 3 giây mà chưa có data, tự tát nước bằng UI Scan
        if left <= 3 and left >= 1 then
            local ss, gg = scanUserInterface()
            if #ss > 0 or #gg > 0 then onRestockData(ss, gg, "UI Fallback (End of cycle)") end
        end
        
        task.wait(1)
    end
end)

-- ══════════════════════════════════════════════════════════════════════════════
-- 🚀 KHỞI ĐỘNG
-- ══════════════════════════════════════════════════════════════════════════════
task.spawn(function()
    print("=" .. string.rep("=", 50))
    print("[GHZ Bot] 🚀 Khởi động v6 Hybrid")
    
    hookGameRemotes()
    hookAdminMessages()
    
    -- INITIAL FETCH (Quét ngay và luôn để bù đắp việc phải đợi server restock)
    rowStatus.Text = "Status: 🔍 Đang quét khởi động (UI)..."
    task.wait(1)
    local iSeeds, iGear = scanUserInterface()
    if #iSeeds > 0 or #iGear > 0 then
        onRestockData(iSeeds, iGear, "UI Khởi động")
    else
        rowStatus.Text = "Status: 🟡 Chờ Mở Shop / Chờ Restock..."
    end
    
    print("[GHZ Bot] ✅ Bot sẵn sàng!")
end)