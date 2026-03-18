-------------------------------------------------------------------------------
-- 🌱 GARDEN HORIZONS STOCK BOT
-- Adapted from StockBot (Grow a Garden) for Garden Horizons
-- Gửi webhook Discord + Post lên API mỗi khi có restock
-- Chỉ theo dõi: Seeds Shop, Gear Shop, Weather
-------------------------------------------------------------------------------

_G.GHZ_StockBot_Config = {
    -- ── API ────────────────────────────────────────────────────────
    ["API_Enabled"]     = true,
    ["API_URL"]         = "https://zenithghz.qzz.io/api/update",

    -- ── Discord Webhook ─────────────────────────────────────────────
    ["Webhook_Enabled"] = true,
    ["Webhook_URL"]     = "https://discord.com/api/webhooks/1482391815024803963/6V8VLwhL7X1o9FL_n1GNxxsoRH6su1tDzhbxzT4wJe_qr_MGCVaqp1fUs8ZKdnbyyC_H",

    -- ── Embed Colors ────────────────────────────────────────────────
    ["Color_Stock"]     = Color3.fromRGB(56, 238, 23),   -- Xanh lá  – Seeds & Gear
    ["Color_Weather"]   = Color3.fromRGB(42, 109, 255),  -- Xanh dương – Weather

    -- ── Features ────────────────────────────────────────────────────
    ["Anti_AFK"]              = true,
    ["Disable_Rendering"]     = true,  -- Tắt 3D render để giảm lag khi treo
    ["Weather_Report"]        = true,  -- Webhook ngay khi thời tiết đổi
}

-------------------------------------------------------------------------------
-- SERVICES
-------------------------------------------------------------------------------
local HttpService       = game:GetService("HttpService")
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui           = game:GetService("CoreGui")
local RunService        = game:GetService("RunService")
local VirtualUser       = cloneref(game:GetService("VirtualUser"))
local LocalPlayer       = Players.LocalPlayer

-- Tắt rendering nếu được bật
if _G.GHZ_StockBot_Config["Disable_Rendering"] then
    pcall(function() RunService:Set3dRenderingEnabled(false) end)
end

-- Chống chạy 2 lần
if _G.GHZ_StockBot then return end
_G.GHZ_StockBot = true

local Config = _G.GHZ_StockBot_Config

-------------------------------------------------------------------------------
-- IN-GAME MONITORING UI
-------------------------------------------------------------------------------
local uiLayer = (gethui and gethui()) or CoreGui

-- Xóa UI cũ nếu tồn tại
if uiLayer:FindFirstChild("GHZ_Bot_UI") then
    uiLayer.GHZ_Bot_UI:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "GHZ_Bot_UI"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = uiLayer

-- Main frame
local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 280, 0, 165)
frame.Position = UDim2.new(0, 12, 0, 12)
frame.BackgroundColor3 = Color3.fromRGB(18, 18, 28)
frame.BackgroundTransparency = 0.08
frame.BorderSizePixel = 0
frame.Parent = screenGui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)

local uiStroke = Instance.new("UIStroke")
uiStroke.Color = Color3.fromRGB(80, 200, 80)
uiStroke.Thickness = 1.5
uiStroke.Transparency = 0.5
uiStroke.Parent = frame

-- Title
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 32)
titleBar.BackgroundColor3 = Color3.fromRGB(30, 80, 30)
titleBar.BorderSizePixel = 0
titleBar.Parent = frame
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 10)

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, 0, 1, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "🌱 GHZ Stock Bot"
titleLabel.TextColor3 = Color3.fromRGB(150, 255, 150)
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 14
titleLabel.Parent = titleBar

-- Status label
local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "STATUS"
statusLabel.Size = UDim2.new(1, -16, 0, 22)
statusLabel.Position = UDim2.new(0, 8, 0, 36)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Status: 🟡 Khởi động..."
statusLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
statusLabel.Font = Enum.Font.GothamMedium
statusLabel.TextSize = 12
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Parent = frame

-- Countdown label
local countLabel = Instance.new("TextLabel")
countLabel.Name = "COUNT"
countLabel.Size = UDim2.new(1, -16, 0, 22)
countLabel.Position = UDim2.new(0, 8, 0, 58)
countLabel.BackgroundTransparency = 1
countLabel.Text = "⏳ Restock: --:--"
countLabel.TextColor3 = Color3.fromRGB(180, 180, 255)
countLabel.Font = Enum.Font.GothamMedium
countLabel.TextSize = 12
countLabel.TextXAlignment = Enum.TextXAlignment.Left
countLabel.Parent = frame

-- Seeds info
local seedLabel = Instance.new("TextLabel")
seedLabel.Name = "SEEDS"
seedLabel.Size = UDim2.new(1, -16, 0, 20)
seedLabel.Position = UDim2.new(0, 8, 0, 82)
seedLabel.BackgroundTransparency = 1
seedLabel.Text = "🌿 Seeds: -"
seedLabel.TextColor3 = Color3.fromRGB(130, 255, 130)
seedLabel.Font = Enum.Font.Gotham
seedLabel.TextSize = 11
seedLabel.TextXAlignment = Enum.TextXAlignment.Left
seedLabel.Parent = frame

-- Gear info
local gearLabel = Instance.new("TextLabel")
gearLabel.Name = "GEAR"
gearLabel.Size = UDim2.new(1, -16, 0, 20)
gearLabel.Position = UDim2.new(0, 8, 0, 101)
gearLabel.BackgroundTransparency = 1
gearLabel.Text = "⚙️ Gear: -"
gearLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
gearLabel.Font = Enum.Font.Gotham
gearLabel.TextSize = 11
gearLabel.TextXAlignment = Enum.TextXAlignment.Left
gearLabel.Parent = frame

-- Weather info
local weatherLabel = Instance.new("TextLabel")
weatherLabel.Name = "WEATHER"
weatherLabel.Size = UDim2.new(1, -16, 0, 20)
weatherLabel.Position = UDim2.new(0, 8, 0, 120)
weatherLabel.BackgroundTransparency = 1
weatherLabel.Text = "⛅ Weather: None"
weatherLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
weatherLabel.Font = Enum.Font.Gotham
weatherLabel.TextSize = 11
weatherLabel.TextXAlignment = Enum.TextXAlignment.Left
weatherLabel.Parent = frame

-- API/Webhook status
local apiLabel = Instance.new("TextLabel")
apiLabel.Name = "API"
apiLabel.Size = UDim2.new(1, -16, 0, 20)
apiLabel.Position = UDim2.new(0, 8, 0, 141)
apiLabel.BackgroundTransparency = 1
apiLabel.Text = "📡 API: -  💬 Webhook: -"
apiLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
apiLabel.Font = Enum.Font.Gotham
apiLabel.TextSize = 11
apiLabel.TextXAlignment = Enum.TextXAlignment.Left
apiLabel.Parent = frame

local function updateUI(status, seeds, gear, weather, apiOk, hookOk)
    if status  then statusLabel.Text  = "Status: " .. status end
    if seeds   ~= nil then seedLabel.Text    = string.format("🌿 Seeds: %d loại", seeds) end
    if gear    ~= nil then gearLabel.Text    = string.format("⚙️ Gear:  %d loại", gear) end
    if weather ~= nil then weatherLabel.Text = "⛅ Weather: " .. tostring(weather) end

    local apiStr  = (apiOk  == true and "✅") or (apiOk  == false and "❌") or "-"
    local hookStr = (hookOk == true and "✅") or (hookOk == false and (Config["Webhook_Enabled"] and "❌" or "⏸️")) or "-"
    apiLabel.Text = "📡 API: " .. apiStr .. "  💬 Hook: " .. hookStr
end

local function setCountdown(sec)
    local m = math.floor(sec / 60)
    local s = sec % 60
    countLabel.Text = string.format("⏳ Restock: %02d:%02d", m, s)
end

-------------------------------------------------------------------------------
-- HELPERS
-------------------------------------------------------------------------------
local function Color3ToInt(c)
    return tonumber(c:ToHex(), 16)
end

local req = (syn and syn.request) or (http and http.request) or request

-------------------------------------------------------------------------------
-- DISCORD WEBHOOK SENDER
-------------------------------------------------------------------------------
local function sendWebhook(color, fields, title)
    if not Config["Webhook_Enabled"] then return false end
    local url = Config["Webhook_URL"]
    if not url or url == "" or url:find("PASTE") then return false end
    if not req then return false end

    local body = {
        username = "🌱 GHZ Stock Tracker",
        embeds = {{
            title     = title or "Garden Horizons Update",
            color     = Color3ToInt(color),
            fields    = fields,
            footer    = { text = "Garden Horizons  •  zenithghz.qzz.io" },
            timestamp = DateTime.now():ToIsoDate()
        }}
    }

    local ok = pcall(function()
        task.spawn(function()
            req({
                Url     = url,
                Method  = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body    = HttpService:JSONEncode(body)
            })
        end)
    end)
    return ok
end

-------------------------------------------------------------------------------
-- API POST
-------------------------------------------------------------------------------
local function postToAPI(seeds, gear, weather)
    if not Config["API_Enabled"] then return false end
    if not req then return false end

    local payload = {
        seeds    = seeds,
        gear     = gear,
        weather  = weather,
        timestamp = os.time()
    }

    local ok, res = pcall(function()
        return req({
            Url     = Config["API_URL"],
            Method  = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body    = HttpService:JSONEncode(payload)
        })
    end)

    if ok and res and res.StatusCode == 200 then
        print("[GHZ Bot] ✅ API OK")
        return true
    end
    print("[GHZ Bot] ❌ API fail: " .. (ok and tostring(res and res.StatusCode) or "error"))
    return false
end

-------------------------------------------------------------------------------
-- DATA REMOTES (Seeds, Gear via DataStream — chỉ Seeds & Gear)
-------------------------------------------------------------------------------
local DataStream = ReplicatedStorage:WaitForChild("GameEvents"):WaitForChild("DataStream")

local latestSeeds   = {}
local latestGear    = {}
local latestWeather = { status = "None", duration = 0 }

local function makeItemList(stockTable)
    local out = {}
    if type(stockTable) ~= "table" then return out end
    for name, data in pairs(stockTable) do
        table.insert(out, {
            name     = tostring(name),
            quantity = tonumber(data.Stock) or 0,
            category = "?"
        })
    end
    return out
end

DataStream.OnClientEvent:Connect(function(evType, profile, data)
    if evType ~= "UpdateData" then return end
    if not profile:find(LocalPlayer.Name) then return end

    -- Duyệt packet: chỉ lấy SeedStock và GearStock
    -- BỎ QUA: EventShopStock, PetEggStock, CosmeticStock
    local newSeeds = {}
    local newGear  = {}

    for _, packet in ipairs(data) do
        local name    = packet[1]
        local content = packet[2]

        if name == "ROOT/SeedStock/Stocks" then
            newSeeds = makeItemList(content)
            for _, item in ipairs(newSeeds) do item.category = "seed" end

        elseif name == "ROOT/GearStock/Stocks" then
            newGear = makeItemList(content)
            for _, item in ipairs(newGear) do item.category = "gear" end
        end
        -- ❌ ROOT/EventShopStock, ROOT/PetEggStock, ROOT/CosmeticStock → bỏ qua
    end

    latestSeeds = newSeeds
    latestGear  = newGear

    -- Build discord fields
    local fields = {}

    if #newSeeds > 0 then
        local s = ""
        for _, item in ipairs(newSeeds) do
            s = s .. string.format("🌱 **%s** x%d\n", item.name, item.quantity)
        end
        table.insert(fields, { name = "🌿 SEEDS STOCK", value = s, inline = true })
    end

    if #newGear > 0 then
        local g = ""
        for _, item in ipairs(newGear) do
            g = g .. string.format("🔧 **%s** x%d\n", item.name, item.quantity)
        end
        table.insert(fields, { name = "⚙️ GEAR STOCK", value = g, inline = true })
    end

    -- Post API + Discord concurrently
    local apiOk, hookOk

    task.spawn(function()
        apiOk  = postToAPI(newSeeds, newGear, latestWeather)
        hookOk = sendWebhook(Config["Color_Stock"], fields, "🌱 GHZ Restock Alert")
        updateUI("✅ Đã cập nhật", #newSeeds, #newGear, latestWeather.status, apiOk, hookOk)
        print(string.format("[GHZ Bot] 📦 Seeds: %d | Gear: %d | API: %s | Hook: %s",
            #newSeeds, #newGear,
            apiOk  and "OK" or "FAIL",
            hookOk and "OK" or (Config["Webhook_Enabled"] and "FAIL" or "OFF")))
    end)
end)

-------------------------------------------------------------------------------
-- WEATHER EVENT — hook tức thì
-------------------------------------------------------------------------------
local weatherEventOk, WeatherEvent = pcall(function()
    return ReplicatedStorage:WaitForChild("GameEvents", 5):WaitForChild("WeatherEventStarted", 5)
end)

if weatherEventOk and WeatherEvent then
    WeatherEvent.OnClientEvent:Connect(function(eventName, length)
        if not Config["Weather_Report"] then return end

        latestWeather = { status = tostring(eventName), duration = tonumber(length) or 0 }
        weatherLabel.Text = "⛅ Weather: " .. tostring(eventName)

        local serverTime = math.round(workspace:GetServerTimeNow())
        local endUnix    = serverTime + (tonumber(length) or 0)

        local hookOk = sendWebhook(Config["Color_Weather"], {
            {
                name   = "⛅ WEATHER EVENT",
                value  = string.format("**%s**\nKết thúc: <t:%d:R>", tostring(eventName), endUnix),
                inline = false
            }
        }, "⛅ GHZ Weather Alert")

        print(string.format("[GHZ Bot] ⛅ Weather: %s (%ds) | Hook: %s",
            tostring(eventName), tonumber(length) or 0,
            hookOk and "OK" or "FAIL/OFF"))
    end)
    print("[GHZ Bot] ⛅ Weather hook đã kết nối")
else
    print("[GHZ Bot] ⚠️ Không tìm thấy WeatherEventStarted remote")
end

-------------------------------------------------------------------------------
-- ANTI-AFK
-------------------------------------------------------------------------------
LocalPlayer.Idled:Connect(function()
    if not Config["Anti_AFK"] then return end
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
    print("[GHZ Bot] 🛡️ Anti-AFK kích hoạt")
end)

-------------------------------------------------------------------------------
-- COUNTDOWN (cập nhật mỗi giây)
-------------------------------------------------------------------------------
task.spawn(function()
    while true do
        local t    = os.date("!*t")
        local sec  = (t.min % 5) * 60 + t.sec
        local left = 300 - sec
        if left <= 0 then left = 300 end
        setCountdown(left)
        task.wait(1)
    end
end)

-------------------------------------------------------------------------------
-- READY
-------------------------------------------------------------------------------
updateUI("🟢 Đang chờ restock...", nil, nil, nil, nil, nil)
print("[GHZ Bot] 🚀 Garden Horizons Stock Bot đã khởi động!")
print("[GHZ Bot] 📡 API URL : " .. Config["API_URL"])
print("[GHZ Bot] 💬 Webhook : " .. (Config["Webhook_Enabled"] and Config["Webhook_URL"] or "OFF"))

