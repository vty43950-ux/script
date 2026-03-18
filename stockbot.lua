-------------------------------------------------------------------------------
-- 🌱 GHZ STOCK BOT  v9  — THE GOD MODE (Memory GC Scraper + Pure Remote)
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

    WEBHOOK_URL      = "https://discord.com/api/webhooks/1482391815024803963/6V8VLwhL7X1o9FL_n1GNxxsoRH6su1tDzhbxzT4wJe_qr_MGCVaqp1fUs8ZKdnbyyC_H",
    WEBHOOK_ENABLED  = true,

    SKIP_EMPTY       = true,
    ANTI_AFK         = true,
    DISABLE_RENDERING = false,
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
frame.Size = UDim2.new(0, 310, 0, 200); frame.Position = UDim2.new(0, 10, 0, 10)
frame.BackgroundColor3 = Color3.fromRGB(15, 18, 25); frame.BackgroundTransparency = 0.05
frame.BorderSizePixel = 0; frame.Parent = sg
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)
local stroke = Instance.new("UIStroke"); stroke.Color = Color3.fromRGB(50, 180, 255)
stroke.Thickness = 1.5; stroke.Transparency = 0.35; stroke.Parent = frame

local titleBar = Instance.new("Frame"); titleBar.Size = UDim2.new(1,0,0,30)
titleBar.BackgroundColor3 = Color3.fromRGB(18, 50, 90); titleBar.BorderSizePixel = 0; titleBar.Parent = frame
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0,10)
local titleLbl = Instance.new("TextLabel"); titleLbl.Size = UDim2.new(1,0,1,0)
titleLbl.BackgroundTransparency = 1; titleLbl.Text = "🔍 GHZ Bot v9 ✦ GOD MODE"
titleLbl.TextColor3 = Color3.fromRGB(180, 220, 255); titleLbl.Font = Enum.Font.GothamBold
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

rowStatus.Text  = "Status: 🟡 Chờ nhận data..."
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
    if seeds and #seeds > 0 then
        local s = ""
        for _, it in ipairs(seeds) do s = s .. string.format("🌱 **%s** — %s\n", tostring(it.name), tostring(it.quantity)) end
        table.insert(fields, { name="🌿 SEEDS", value=s, inline=true })
    end
    if gear and #gear > 0 then
        local g = ""
        for _, it in ipairs(gear) do g = g .. string.format("🔧 **%s** — %s\n", tostring(it.name), tostring(it.quantity)) end
        table.insert(fields, { name="⚙️ GEAR", value=g, inline=true })
    end
    if weather and weather.status and weather.status ~= "None" then
        local durStr = (weather.duration and weather.duration > 0) and (" (" .. weather.duration .. "s)") or ""
        table.insert(fields, { name="⛅ WEATHER", value=string.format("**%s**%s", weather.status, durStr), inline=false })
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
    local ok = pcall(function()
        req({ Url=CONFIG.API_URL, Method="POST", Headers={["Content-Type"]="application/json"},
            Body=HttpService:JSONEncode({ seeds=seeds or {}, gear=gear or {}, weather=weather or {status="None",duration=0}, timestamp=os.time() })
        })
    end)
    return ok
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
local function onRestockData(seeds, gear, debugInfo)
    if #seeds == 0 and #gear == 0 then return end
    
    -- In ra kết quả chi tiết
    print("[GHZ Bot] ============= NEW STOCK DATA ==============")
    print("[GHZ Bot] " .. debugInfo)
    local sList, gList = "", ""
    for _,s in ipairs(seeds) do sList = sList .. s.name .. ":" .. s.quantity .. ", " end
    for _,g in ipairs(gear) do  gList = gList .. g.name .. ":" .. g.quantity .. ", " end
    print("[GHZ Bot] Seeds: " .. sList)
    print("[GHZ Bot] Gear: " .. gList)
    print("[GHZ Bot] ===========================================")
    
    lastSeeds, lastGear = seeds, gear

    rowSeeds.Text  = string.format("🌿 Seeds: %d món", #seeds)
    rowGear.Text   = string.format("⚙️  Gear:  %d món", #gear)
    rowTime.Text   = "🕐 Cập nhật: " .. os.date("%H:%M:%S")
    rowStatus.Text = "Status: ✅ Dữ liệu Live từ Server!"

    task.spawn(function()
        local apiOk  = postAPI(seeds, gear, currentWeather)
        local hookOk = sendWebhook(seeds, gear, currentWeather)
        rowAPI.Text  = "📡 API:" .. (apiOk and "✅" or "❌") .. "  💬 Hook:" .. (hookOk and "✅" or "❌")
    end)
end

-- ══════════════════════════════════════════════════════════════════════════════
-- PHƯƠNG PHÁP 1: PARSE JSON TỪ REMOTE VÀ BỘ NHỚ THEO KIỂU ĐỆ QUY SÂU
-- ══════════════════════════════════════════════════════════════════════════════
local SEED_SHOPS = {"seed", "seedshop", "seeds"}
local GEAR_SHOPS = {"gear", "gearshop", "gears", "tool", "toolshop"}
local WEATHER_WHITELIST = {"Clear","Rain","Storm","Snow","Meteor","Starfall","Cloudy","Windy","Sunny","Mowis","Sandstorm","Acid Rain","Foggy"}

local function getCat(text)
    local n = tostring(text):lower():gsub("%s+","")
    for _, k in ipairs(SEED_SHOPS) do if n:find(k) then return "seed" end end
    for _, k in ipairs(GEAR_SHOPS) do if n:find(k) then return "gear" end end
end

local function parseRemoteTable(dataTable)
    local seeds, gear = {}, {}
    local tracked = {}
    
    -- Fix: dataTable có thể bị gói trong 1 array (VD: args[2])
    local function search(t, depth)
        if depth > 10 then return end
        for k, v in pairs(t) do
            -- Trường hợp 1: cấu trúc { SeedShop = { Items = { Carrot = {Amount = 15} } } }
            local cat = type(k) == "string" and getCat(k) or nil
            if cat and type(v) == "table" then
                -- Nếu có bảng Items -> đi sâu vào nó
                local items = v.Items or v.items or v
                if type(items) == "table" then
                    for itemName, itemData in pairs(items) do
                        if type(itemName) == "string" then
                            local amt = nil
                            if type(itemData) == "table" then
                                amt = itemData.Amount or itemData.amount or itemData.Stock or itemData.stock
                            elseif type(itemData) == "number" then
                                amt = itemData
                            end
                            if amt and type(amt) == "number" then
                                if not CONFIG.SKIP_EMPTY or amt > 0 then
                                    if not tracked[itemName] then
                                        tracked[itemName] = true
                                        local entry = {name=itemName, quantity=amt, category=cat}
                                        if cat=="seed" then table.insert(seeds,entry) else table.insert(gear,entry) end
                                    end
                                end
                            end
                        end
                    end
                end
            end
            
             -- Trường hợp 2: Data ẩn giấu dưới dạng mảng {{Name="Carrot", Amount=15}, ...}
            if type(v) == "table" then
                local eName = v.Name or v.name or v.Item or v.item
                local eAmt = v.Amount or v.amount or v.Stock or v.stock or v.Quantity or v.quantity
                if eName and eAmt and type(eName) == "string" and type(eAmt) == "number" then
                    local realCat = getCat(eName) or "seed" -- Mặc định là seed nếu ko đoán dc
                    if not tracked[eName] then
                        tracked[eName] = true
                        local entry = {name=eName, quantity=eAmt, category=realCat}
                        if realCat=="seed" then table.insert(seeds,entry) else table.insert(gear,entry) end
                    end
                else
                    search(v, depth + 1)
                end
            end
        end
    end
    
    if type(dataTable) == "table" then search(dataTable, 1) end
    return seeds, gear
end

-- ══════════════════════════════════════════════════════════════════════════════
-- 🧠 HÀM MỔ NÃO BỘ NHỚ (GETGC SILENT SCRAPER) - LẤY DATA KHÔNG CẦN CHỜ
-- ══════════════════════════════════════════════════════════════════════════════
local function getInstantMemoryData()
    print("[GHZ Bot] 🧠 Đang quét sâu vào RAM (Garbage Collector)...")
    local extSeeds, extGear = {}, {}
    local extWeather = {status = "None", duration = 0}
    
    local seen = {}
    local gc = getgc(true)
    for i = 1, #gc do
        local obj = gc[i]
        if type(obj) == "table" and not seen[obj] then
            seen[obj] = true
            
            -- Tìm dữ liệu Shop trong RAM (ReplicaService Data)
            local ok, d = pcall(function() return rawget(obj, "Data") or rawget(obj, "data") end)
            if ok and type(d) == "table" then
                local ok2, hasShopKeys = pcall(function() return rawget(d, "SeedShop") or rawget(d, "GearShop") or rawget(d, "Items") end)
                if ok2 and hasShopKeys then
                    local s, g = parseRemoteTable(d)
                    if #s > 0 or #g > 0 then
                        print("[GHZ Bot] 🔥 BẮT ĐƯỢC KHO LƯU TRỮ SHOP TRONG GC!")
                        for _,v in ipairs(s) do table.insert(extSeeds, v) end
                        for _,v in ipairs(g) do table.insert(extGear, v) end
                    end
                end
            end
            
            -- Trường hợp Replica object chính nó là data
            local ok3, isDirectShopData = pcall(function() return rawget(obj, "SeedShop") or rawget(obj, "GearShop") end)
            if ok3 and isDirectShopData then
                local s, g = parseRemoteTable(obj)
                if #s > 0 or #g > 0 then
                    print("[GHZ Bot] 🔥 BẮT ĐƯỢC TÀI LIỆU GỐC SHOP TRONG GC!")
                    for _,v in ipairs(s) do table.insert(extSeeds, v) end
                    for _,v in ipairs(g) do table.insert(extGear, v) end
                end
            end
            
            -- Tìm dữ liệu Thời Tiết trong RAM
            local ok4, wTarget = pcall(function() return rawget(obj, "Weather") or rawget(obj, "WeatherType") or rawget(obj, "Status") end)
            if ok4 and type(wTarget) == "string" then
                for _, clean in ipairs(WEATHER_WHITELIST) do
                    if string.lower(wTarget) == string.lower(clean) then
                        local dur = pcall(function() return rawget(obj, "Duration") or rawget(obj, "Time") end)
                        extWeather.status = clean
                        extWeather.duration = type(dur) == "number" and dur or 0
                    end
                end
            end
        end
    end
    
    -- Xóa trùng lặp (trường hợp nhiều table GC tham chiếu chung)
    local uSeeds, uGear = {}, {}
    local tS, tG = {}, {}
    for _, item in ipairs(extSeeds) do
        if not tS[item.name] then tS[item.name] = true; table.insert(uSeeds, item) end
    end
    for _, item in ipairs(extGear) do
        if not tG[item.name] then tG[item.name] = true; table.insert(uGear, item) end
    end

    print(string.format("[GHZ Bot] 🧠 Kết quả quét GC: %d hạt giống, %d công cụ. Weather: %s", #uSeeds, #uGear, extWeather.status))
    return uSeeds, uGear, extWeather
end

-- ══════════════════════════════════════════════════════════════════════════════
-- 🎯 LẮNG NGHE DỮ LIỆU TỪ GAME (Hooks)
-- ══════════════════════════════════════════════════════════════════════════════
local function hookGameRemotes()
    local remotes = ReplicatedStorage:WaitForChild("RemoteEvents", 10)
    if not remotes then return false end
    
    -- 1. BẮT BIẾN THỂ THẬT CỦA SHOPRESTOCKED
    for _, rem in pairs(remotes:GetChildren()) do
        if rem:IsA("RemoteEvent") then
            -- Bắt ShopRestocked VÀ các Replica...
            if rem.Name == "ShopRestocked" or rem.Name:find("Replica") then
                rem.OnClientEvent:Connect(function(...)
                    local args = {...}
                    local strArgs = HttpService:JSONEncode(args)
                    
                    -- Lọc các packet Tào Lao
                    if strArgs:find("Amount") and (strArgs:find("SeedShop") or strArgs:find("GearShop") or strArgs:find("Items")) then
                        print(string.format("[GHZ Bot] 🎯 Đã BẮT ĐƯỢC data từ [%s]: %s", rem.Name, strArgs))
                        for _, arg in ipairs(args) do
                            local s, g = parseRemoteTable(arg)
                            if #s > 0 or #g > 0 then onRestockData(s, g, rem.Name) end
                        end
                    end
                end)
            end
        end
    end
    
    -- 2. BẮT THỜI TIẾT (LỌC CỰC KỲ KHẮT KHE)
    for _, rem in pairs(remotes:GetChildren()) do
        if rem:IsA("RemoteEvent") and string.find(string.lower(rem.Name), "weather") then
            rem.OnClientEvent:Connect(function(...)
                local args = {...}
                local strArgs = HttpService:JSONEncode(args)
                
                -- Bỏ qua mấy cái Effect, Visual rác, Particle...
                if string.find(strArgs, "VisualEffect") or string.find(strArgs, "Particle") or string.find(strArgs, "Lightning") then return end
                
                print(string.format("[GHZ Bot] ⛅ THEO DÕI Weather [%s]: %s", rem.Name, strArgs))
                
                local wNameFound = ""
                local wDurFound = 0
                
                -- Tìm theo table: {Name="Storm", Duration=100}
                for _, arg in ipairs(args) do
                    if type(arg) == "table" then
                        wNameFound = arg.Name or arg.name or arg.WeatherType or arg.Type or arg.id or arg.Id or arg.status or wNameFound
                        wDurFound = arg.Duration or arg.duration or arg.Time or arg.time or wDurFound
                    end
                end
                
                -- Tìm cứng chuỗi trong Whitelist (Rất chính xác)
                for _, arg in ipairs(args) do
                    if type(arg) == "string" then
                        for _, clean in ipairs(WEATHER_WHITELIST) do
                            if string.lower(arg) == string.lower(clean) then wNameFound = clean break end
                        end
                    elseif type(arg) == "number" and arg > 10 then
                        wDurFound = arg
                    end
                end
                
                if wNameFound ~= "" and wNameFound ~= "Unknown" then
                    currentWeather.status = wNameFound
                    currentWeather.duration = wDurFound
                    rowWeather.Text = "⛅ " .. wNameFound .. (wDurFound > 0 and (" (" .. wDurFound .. "s)") or "")
                    
                    if wDurFound == 0 and (wNameFound == "Clear" or string.lower(wNameFound) == "none") then
                        print("[GHZ Bot] ⛅ Thời tiết kết thúc (Clear)!")
                    end
                    
                    task.spawn(function()
                        sendWebhook({}, {}, currentWeather)
                        postAPI(lastSeeds, lastGear, currentWeather)
                    end)
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
        
        -- NHẮC NHỞ QUAN TRỌNG CHO NGƯỜI CHƠI (Bỏ yêu cầu tự mở shop vì đã có Memory Scraper)
        if left <= 3 and left >= 1 then
            if lastDataHash == "" then
                rowStatus.Text = "Status: 🟡 Chờ restock mới (Hoặc check F9)..."
            else
                rowStatus.Text = "Status: 🟡 Chờ Restock..."
            end
        end
        
        task.wait(1)
    end
end)

-- ══════════════════════════════════════════════════════════════════════════════
-- 🚀 KHỞI ĐỘNG
-- ══════════════════════════════════════════════════════════════════════════════
task.spawn(function()
    print("=" .. string.rep("=", 50))
    print("[GHZ Bot] 🚀 Khởi động v9 GOD-MODE")
    
    hookGameRemotes()
    hookAdminMessages()
    
    rowStatus.Text = "Status: 🧠 Đang quét thẻ nhớ RAM (GC)..."
    task.wait(0.5)
    
    -- THỰC THI SUPER MỔ NÃO GAME: THU THẬP TẤT CẢ REPLICAS HIỆN CÓ
    local gcSeeds, gcGear, gcWeather = getInstantMemoryData()
    if #gcSeeds > 0 or #gcGear > 0 then
        onRestockData(gcSeeds, gcGear, "Memory GC Scraper")
    else
        rowStatus.Text = "Status: 🟡 GC Trống - Đang chờ Remote..."
    end
    
    if gcWeather and gcWeather.status ~= "None" then
        currentWeather = gcWeather
        rowWeather.Text = "⛅ " .. gcWeather.status .. (gcWeather.duration > 0 and (" (" .. gcWeather.duration .. "s)") or "")
    end
    
    print("[GHZ Bot] ✅ Bot đã sẵn sàng nhận Replica và GC Data!")
end)
