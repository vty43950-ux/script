-------------------------------------------------------------------------------
-- 🌱 GHZ STOCK BOT  v5.0  — Garden Horizons
-- Hook trực tiếp: ReplicatedStorage.RemoteEvents.ShopRestocked
-- Data format: (tick, {SeedShop={Items={Name={Amount=N,MaxAmount=N}}}})
-- Chính xác 100% từ developer game, không cần scan UI
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
    WEBHOOK_ENABLED  = false,   -- ← đổi true + điền URL trên

    -- Lọc chỉ lấy item còn hàng (Amount > 0)
    SKIP_EMPTY       = true,

    ANTI_AFK         = true,
    DISABLE_RENDERING = false,
}

-- ══════════════════════════════════════════════════════════════════════════════
-- SERVICES
-- ══════════════════════════════════════════════════════════════════════════════
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
-- 🖥️ UI
-- ══════════════════════════════════════════════════════════════════════════════
local uiLayer = (gethui and gethui()) or CoreGui
if uiLayer:FindFirstChild("GHZ_Bot_UI") then uiLayer.GHZ_Bot_UI:Destroy() end

local sg = Instance.new("ScreenGui")
sg.Name = "GHZ_Bot_UI"; sg.ResetOnSpawn = false
sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling; sg.Parent = uiLayer

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 290, 0, 200); frame.Position = UDim2.new(0, 10, 0, 10)
frame.BackgroundColor3 = Color3.fromRGB(12, 15, 22); frame.BackgroundTransparency = 0.05
frame.BorderSizePixel = 0; frame.Parent = sg
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)
local stroke = Instance.new("UIStroke"); stroke.Color = Color3.fromRGB(50, 220, 80)
stroke.Thickness = 1.5; stroke.Transparency = 0.35; stroke.Parent = frame

local titleBar = Instance.new("Frame"); titleBar.Size = UDim2.new(1,0,0,30)
titleBar.BackgroundColor3 = Color3.fromRGB(18, 60, 22); titleBar.BorderSizePixel = 0; titleBar.Parent = frame
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0,10)
local titleLbl = Instance.new("TextLabel"); titleLbl.Size = UDim2.new(1,0,1,0)
titleLbl.BackgroundTransparency = 1; titleLbl.Text = "🌱 GHZ Stock Bot  v5  ✦ Remote Hook"
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

rowStatus.Text  = "Status: 🟡 Chờ ShopRestocked..."
rowCount.Text   = "⏳ Restock: --:--"
rowSeeds.Text   = "🌿 Seeds: chờ restock..."
rowGear.Text    = "⚙️  Gear:  chờ restock..."
rowWeather.Text = "⛅ Weather: None"
rowTime.Text    = "🕐 Lần cuối: chưa có"
rowAPI.Text     = "📡 API: -   💬 Hook: " .. (CONFIG.WEBHOOK_ENABLED and "bật" or "tắt")

-- ══════════════════════════════════════════════════════════════════════════════
-- 📦 PARSE DATA TỪ ShopRestocked
-- Format: (serverTick, {SeedShop={Items={Name={Amount=N,MaxAmount=N}}}, GearShop={...}})
-- ══════════════════════════════════════════════════════════════════════════════
local SEED_SHOPS = {"seedshop", "seed shop", "seed_shop", "seeds"}
local GEAR_SHOPS = {"gearshop", "gear shop", "gear_shop", "gears", "toolshop"}

local function shopCategory(shopName)
    local n = shopName:lower():gsub("%s+","")
    for _, k in ipairs(SEED_SHOPS) do if n:find(k) then return "seed" end end
    for _, k in ipairs(GEAR_SHOPS) do if n:find(k) then return "gear" end end
    return nil
end

local function parseShopData(dataTable)
    local seeds, gear = {}, {}
    if type(dataTable) ~= "table" then return seeds, gear end

    for shopName, shopData in pairs(dataTable) do
        local cat = shopCategory(tostring(shopName))
        if cat and type(shopData) == "table" then
            -- Tìm Items sub-table
            local items = shopData.Items or shopData.items or shopData
            if type(items) == "table" then
                for itemName, itemData in pairs(items) do
                    local amount, maxAmount
                    if type(itemData) == "table" then
                        amount    = itemData.Amount    or itemData.amount    or itemData.Stock  or itemData.stock  or 0
                        maxAmount = itemData.MaxAmount or itemData.maxAmount or itemData.Max    or itemData.max    or amount
                    elseif type(itemData) == "number" then
                        amount = itemData; maxAmount = itemData
                    end

                    if amount ~= nil then
                        local qty = tonumber(amount) or 0
                        if not CONFIG.SKIP_EMPTY or qty > 0 then
                            local entry = {
                                name      = tostring(itemName),
                                quantity  = qty,
                                max       = tonumber(maxAmount) or qty,
                                category  = cat
                            }
                            if cat == "seed" then table.insert(seeds, entry)
                            else                  table.insert(gear,  entry) end
                        end
                    end
                end
            end
        end
    end
    return seeds, gear
end

-- ══════════════════════════════════════════════════════════════════════════════
-- 📨 WEBHOOK + API
-- ══════════════════════════════════════════════════════════════════════════════
local function sendWebhook(seeds, gear, weather)
    if not CONFIG.WEBHOOK_ENABLED or not req then return false end
    local url = CONFIG.WEBHOOK_URL
    if not url or url == "" or url:find("PASTE") then return false end

    local fields = {}
    if #seeds > 0 then
        local s = ""
        for _, it in ipairs(seeds) do
            s = s .. string.format("🌱 **%s** — %d/%d\n", it.name, it.quantity, it.max)
        end
        table.insert(fields, { name="🌿 SEEDS", value=s, inline=true })
    end
    if #gear > 0 then
        local g = ""
        for _, it in ipairs(gear) do
            g = g .. string.format("🔧 **%s** — %d/%d\n", it.name, it.quantity, it.max)
        end
        table.insert(fields, { name="⚙️ GEAR", value=g, inline=true })
    end
    if weather and weather.status and weather.status ~= "None" then
        table.insert(fields, {
            name  = "⛅ WEATHER",
            value = string.format("**%s** (%ds còn lại)", weather.status, weather.duration or 0),
            inline = false
        })
    end
    if #fields == 0 then return false end

    pcall(function()
        task.spawn(function()
            req({ Url=url, Method="POST", Headers={["Content-Type"]="application/json"},
                Body=HttpService:JSONEncode({
                    username = "🌱 GHZ Stock Tracker",
                    embeds   = {{
                        title     = "🌱 GHZ Restock!",
                        color     = 0x38ee17,
                        fields    = fields,
                        footer    = { text = "Garden Horizons • zenithghz.qzz.io • Remote v5" },
                        timestamp = DateTime.now():ToIsoDate()
                    }}
                })
            })
        end)
    end)
    return true
end

local function postAdminMessage(msg)
    if not CONFIG.API_ENABLED or not req or not CONFIG.NOTIFY_URL then return false end
    pcall(function()
        task.spawn(function()
            req({
                Url     = CONFIG.NOTIFY_URL,
                Method  = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body    = HttpService:JSONEncode({
                    message   = msg,
                    timestamp = os.time()
                })
            })
            
            -- Webhook (if enabled) cho admin message
            if CONFIG.WEBHOOK_ENABLED and CONFIG.WEBHOOK_URL and not CONFIG.WEBHOOK_URL:find("PASTE") then
                req({
                    Url     = CONFIG.WEBHOOK_URL,
                    Method  = "POST",
                    Headers = { ["Content-Type"] = "application/json" },
                    Body    = HttpService:JSONEncode({
                        username = "⚠️ Mệnh lệnh từ Chúa Trời (Admin)",
                        content  = "@everyone **ADMIN ANNOUNCEMENT:**\n`" .. msg .. "`"
                    })
                })
            end
        end)
    end)
end

local function postAPI(seeds, gear, weather)
    if not CONFIG.API_ENABLED or not req then return false end
    local ok, res = pcall(function()
        return req({
            Url     = CONFIG.API_URL,
            Method  = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body    = HttpService:JSONEncode({
                seeds   = seeds,
                gear    = gear,
                weather = weather or { status = "None", duration = 0 },
                timestamp = os.time()
            })
        })
    end)
    return ok and res and res.StatusCode == 200
end

-- ══════════════════════════════════════════════════════════════════════════════
-- 🎯 HOOK ShopRestocked
-- ══════════════════════════════════════════════════════════════════════════════
local currentWeather = { status = "None", duration = 0 }
local lastSeeds, lastGear = {}, {}

local function onRestock(seeds, gear)
    if #seeds == 0 and #gear == 0 then
        rowStatus.Text = "Status: ⚠️ Nhận data nhưng trống"
        return
    end

    lastSeeds, lastGear = seeds, gear

    rowSeeds.Text  = string.format("🌿 Seeds: %d loại", #seeds)
    rowGear.Text   = string.format("⚙️  Gear:  %d loại", #gear)
    rowTime.Text   = "🕐 Lần cuối: " .. os.date("%H:%M:%S")
    rowStatus.Text = "Status: ✅ Đã nhận restock!"

    -- Log seeds
    print("[GHZ Bot] 🌱 SEEDS:")
    for _, it in ipairs(seeds) do print(string.format("   %s × %d (max %d)", it.name, it.quantity, it.max)) end
    print("[GHZ Bot] ⚙️ GEAR:")
    for _, it in ipairs(gear) do print(string.format("   %s × %d (max %d)", it.name, it.quantity, it.max)) end

    task.spawn(function()
        local apiOk  = postAPI(seeds, gear, currentWeather)
        local hookOk = sendWebhook(seeds, gear, currentWeather)
        local aStr   = apiOk  and "✅" or (CONFIG.API_ENABLED and "❌" or "⏸")
        local hStr   = hookOk and "✅" or (CONFIG.WEBHOOK_ENABLED and "❌" or "⏸")
        rowAPI.Text  = "📡 API:" .. aStr .. "  💬 Hook:" .. hStr
        print(string.format("[GHZ Bot] 📡 API:%s | 💬 Hook:%s", aStr, hStr))
    end)
end

-- Hook ShopRestocked
local function hookShopRestocked()
    local remotes = ReplicatedStorage:WaitForChild("RemoteEvents", 10)
    if not remotes then
        rowStatus.Text = "Status: ❌ Không tìm thấy RemoteEvents!"
        print("[GHZ Bot] ❌ Không tìm thấy ReplicatedStorage.RemoteEvents")
        return false
    end

    local shopRE = remotes:WaitForChild("ShopRestocked", 10)
    if not shopRE then
        rowStatus.Text = "Status: ❌ Không tìm thấy ShopRestocked!"
        print("[GHZ Bot] ❌ Không tìm thấy ShopRestocked remote")
        return false
    end

    shopRE.OnClientEvent:Connect(function(serverTick, shopData)
        print(string.format("[GHZ Bot] 🔔 ShopRestocked fired! tick=%s", tostring(serverTick)))

        -- shopData có thể là arg 1 hoặc arg 2
        local dataToProcess = shopData
        if type(serverTick) == "table" then
            dataToProcess = serverTick  -- trường hợp chỉ 1 arg
        end

        local seeds, gear = parseShopData(dataToProcess)
        onRestock(seeds, gear)
    end)

    print("[GHZ Bot] ✅ Đã hook ShopRestocked thành công!")
    rowStatus.Text = "Status: 🎯 Đang lắng nghe ShopRestocked..."
    return true
end

-- Hook WeatherEvent (nếu có)
local function hookWeather()
    local remotes = ReplicatedStorage:FindFirstChild("RemoteEvents")
    if not remotes then return end

    -- Thử các tên remote weather phổ biến
    local weatherNames = {"WeatherEvent", "WeatherStarted", "WeatherEventStarted", "WeatherUpdate", "Weather"}
    for _, wName in ipairs(weatherNames) do
        local wRE = remotes:FindFirstChild(wName)
        if wRE and wRE:IsA("RemoteEvent") then
            wRE.OnClientEvent:Connect(function(...)
                local args = {...}
                for _, arg in ipairs(args) do
                    if type(arg) == "string" then
                        currentWeather.status = arg
                        rowWeather.Text = "⛅ Weather: " .. arg
                        print("[GHZ Bot] ⛅ Weather event: " .. arg)
                        -- Gửi webhook weather ngay lập tức
                        task.spawn(function() sendWebhook({}, {}, currentWeather) end)
                    elseif type(arg) == "table" then
                        currentWeather.status = arg.name or arg.Name or arg.status or arg.event or "Unknown"
                        currentWeather.duration = arg.duration or arg.Duration or arg.time or 0
                        rowWeather.Text = "⛅ Weather: " .. currentWeather.status
                        print("[GHZ Bot] ⛅ Weather: " .. currentWeather.status)
                        task.spawn(function() sendWebhook({}, {}, currentWeather) end)
                    end
                end
            end)
            print("[GHZ Bot] ✅ Hook weather: " .. wName)
            break
        end
    end
end

-- ══════════════════════════════════════════════════════════════════════════════
-- 🚨 HOOK ADMIN MESSAGES
-- ══════════════════════════════════════════════════════════════════════════════
local function hookAdminMessages()
    -- Cách 1: Bắt tin nhắn hệ thống qua TextChatService
    local TextChatService = game:GetService("TextChatService")
    pcall(function()
        TextChatService.MessageReceived:Connect(function(textChatMessage)
            -- Phân loại admin message (thường là Server message hoặc message có màu đặc biệt)
            local txt = textChatMessage.Text
            if textChatMessage.Metadata == "Roblox.SystemMessage" or txt:match("^%[Server%]") or txt:match("^%[Admin%]") or txt:match("^Shutdown") or txt:match("^Update") then
                print("[GHZ Bot] 🚨 Admin TxtChat: " .. txt)
                postAdminMessage(txt)
            end
        end)
    end)

    -- Cách 2: Lắng nghe UI Notification hoặc Server Message cũ (ReplicatedStorage.DefaultChatSystemChatEvents)
    pcall(function()
        local chatEvts = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
        if chatEvts and chatEvts:FindFirstChild("OnMessageDoneFiltering") then
            chatEvts.OnMessageDoneFiltering.OnClientEvent:Connect(function(msgData)
                if type(msgData) == "table" and msgData.Message then
                    local txt = msgData.Message
                    if msgData.MessageType == "System" or txt:match("^%[System%]") or txt:match("^%[Server%]") or txt:match("^%[Admin%]") then
                        print("[GHZ Bot] 🚨 Admin SysChat: " .. txt)
                        postAdminMessage(txt)
                    end
                end
            end)
        end
    end)
    
    -- Cách 3: Hook custom game notification remote (nếu có)
    pcall(function()
        local remotes = ReplicatedStorage:FindFirstChild("RemoteEvents")
        if remotes then
            -- Bắt các remote thông báo tên chung chung
            local notifNames = {"Notification", "SendNotification", "ServerMessage", "Announce", "Announcement"}
            for _, nm in ipairs(notifNames) do
                local rem = remotes:FindFirstChild(nm)
                if rem and rem:IsA("RemoteEvent") then
                    rem.OnClientEvent:Connect(function(title, text)
                        -- Thông báo của game thường gửi (text) hoặc (title, text)
                        local msg = type(text) == "string" and text or (type(title) == "string" and title or "")
                        if msg ~= "" then
                            -- Filter các thông báo rác (tiền, lvl)
                            if not msg:lower():find("harvested") and not msg:lower():find("earned") and not msg:lower():find("shillings") then
                                print("[GHZ Bot] 🚨 Admin Notif: " .. msg)
                                postAdminMessage(msg)
                            end
                        end
                    end)
                end
            end
        end
    end)
end

-- ══════════════════════════════════════════════════════════════════════════════
-- 🛡️ ANTI-AFK
-- ══════════════════════════════════════════════════════════════════════════════
if CONFIG.ANTI_AFK then
    LocalPlayer.Idled:Connect(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
        print("[GHZ Bot] 🛡️ Anti-AFK kích hoạt")
    end)
end

-- ══════════════════════════════════════════════════════════════════════════════
-- ⏳ COUNTDOWN
-- ══════════════════════════════════════════════════════════════════════════════
task.spawn(function()
    while sg and sg.Parent do
        local t   = os.date("!*t")
        local sec = (t.min % 5) * 60 + t.sec
        local left = math.max(300 - sec, 1)
        rowCount.Text = string.format("⏳ Restock UTC: %02d:%02d", math.floor(left/60), left%60)
        task.wait(1)
    end
end)

-- ══════════════════════════════════════════════════════════════════════════════
-- 🚀 KHỞI ĐỘNG
-- ══════════════════════════════════════════════════════════════════════════════
task.spawn(function()
    print("=" .. string.rep("=", 50))
    print("[GHZ Bot] 🚀 v5 — Remote Hook")
    print("[GHZ Bot] 🎯 Target: ReplicatedStorage.RemoteEvents.ShopRestocked")
    print("=" .. string.rep("=", 50))

    task.wait(2)

    local ok = hookShopRestocked()
    if not ok then
        rowStatus.Text = "Status: ❌ Hook thất bại! Xem console"
        return
    end

    hookWeather()
    hookAdminMessages()
    print("[GHZ Bot] ✅ Bot sẵn sàng — Sẽ tự nhận data khi shop restock!")
    print("[GHZ Bot] 💡 Không cần mở shop, data tự đến từ server!")
end)
