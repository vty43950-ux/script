-------------------------------------------------------------------------------
-- 🌱 GHZ STOCK BOT  v2.0  — Garden Horizons
-- Quét UI trực tiếp (không cần DataStream remote)
-- Seeds + Gear + Weather | Discord Webhook | API POST | Anti-AFK
-------------------------------------------------------------------------------

-- ── CHỐNG CHẠY 2 LẦN ───────────────────────────────────────────────────────
if _G.GHZ_Bot_Running then return end
_G.GHZ_Bot_Running = true

-- ══════════════════════════════════════════════════════════════════════════════
-- ⚙️  CẤU HÌNH — SỬA Ở ĐÂY
-- ══════════════════════════════════════════════════════════════════════════════
local CONFIG = {
    -- 📡 API
    API_URL          = "https://zenithghz.qzz.io/api/update",
    API_ENABLED      = true,

    -- 💬 Discord Webhook (để WEBHOOK_ENABLED = false nếu không dùng)
    WEBHOOK_URL      = "https://discord.com/api/webhooks/1482391815024803963/6V8VLwhL7X1o9FL_n1GNxxsoRH6su1tDzhbxzT4wJe_qr_MGCVaqp1fUs8ZKdnbyyC_H",
    WEBHOOK_ENABLED  = true,   -- ← đổi thành true và điền URL bên trên

    -- ⚙️ Misc
    ANTI_AFK             = true,
    DISABLE_RENDERING    = false,   -- Tắt 3D render khi treo máy
    SCAN_COOLDOWN        = 3,      -- Giây đợi sau mỗi lần quét UI
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

-- Tắt rendering
if CONFIG.DISABLE_RENDERING then
    pcall(function() RunService:Set3dRenderingEnabled(false) end)
end

-- HTTP request function
local req = (syn and syn.request) or (http and http.request) or request

-- ══════════════════════════════════════════════════════════════════════════════
-- 🖥️ IN-GAME MONITORING UI
-- ══════════════════════════════════════════════════════════════════════════════
if uiLayer and uiLayer:FindFirstChild("GHZ_Bot_UI") then
    uiLayer.GHZ_Bot_UI:Destroy()
end
local uiLayer = (gethui and gethui()) or CoreGui
if uiLayer:FindFirstChild("GHZ_Bot_UI") then
    uiLayer.GHZ_Bot_UI:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "GHZ_Bot_UI"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = uiLayer

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 290, 0, 175)
frame.Position = UDim2.new(0, 12, 0, 12)
frame.BackgroundColor3 = Color3.fromRGB(15, 18, 26)
frame.BackgroundTransparency = 0.05
frame.BorderSizePixel = 0
frame.Parent = screenGui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(60, 200, 80)
stroke.Thickness = 1.5
stroke.Transparency = 0.4
stroke.Parent = frame

-- Title bar
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 30)
titleBar.BackgroundColor3 = Color3.fromRGB(22, 65, 25)
titleBar.BorderSizePixel = 0
titleBar.Parent = frame
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 10)

local titleLbl = Instance.new("TextLabel")
titleLbl.Size = UDim2.new(1, 0, 1, 0)
titleLbl.BackgroundTransparency = 1
titleLbl.Text = "🌱 GHZ Stock Bot  v2"
titleLbl.TextColor3 = Color3.fromRGB(145, 255, 145)
titleLbl.Font = Enum.Font.GothamBold
titleLbl.TextSize = 14
titleLbl.Parent = titleBar

local function mkRow(yPos, color)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, -16, 0, 20)
    l.Position = UDim2.new(0, 8, 0, yPos)
    l.BackgroundTransparency = 1
    l.TextColor3 = color or Color3.fromRGB(230, 230, 230)
    l.Font = Enum.Font.Gotham
    l.TextSize = 11
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = frame
    return l
end

local rowStatus  = mkRow(34,  Color3.fromRGB(240, 240, 100))
local rowCount   = mkRow(54,  Color3.fromRGB(180, 180, 255))
local rowSeeds   = mkRow(76,  Color3.fromRGB(100, 255, 100))
local rowGear    = mkRow(96,  Color3.fromRGB(255, 190, 80))
local rowWeather = mkRow(116, Color3.fromRGB(100, 195, 255))
local rowAPI     = mkRow(140, Color3.fromRGB(180, 180, 180))

rowStatus.Text  = "Status: 🟡 Khởi động..."
rowCount.Text   = "⏳ Restock: --:--"
rowSeeds.Text   = "🌿 Seeds: chưa quét"
rowGear.Text    = "⚙️  Gear:  chưa quét"
rowWeather.Text = "⛅ Weather: None"
rowAPI.Text     = "📡 API: -   💬 Webhook: " .. (CONFIG.WEBHOOK_ENABLED and "bật" or "tắt")

-- ══════════════════════════════════════════════════════════════════════════════
-- WHITELIST CATEGORIES (Seeds / Gear)
-- ══════════════════════════════════════════════════════════════════════════════
local SEED_NAMES = {
    "onion","corn","carrot","potato","tomato","blueberry","strawberry",
    "grape","wheat","pumpkin","watermelon","mushroom","apple","orange",
    "lemon","cherry","pear","pineapple","coconut","mango","peach",
    "pepper","eggplant","sunflower","bamboo","cactus","rose","tulip",
    "lily","daisy","orchid","lavender","seed","sprout","plant","fertile soil"
}
local GEAR_NAMES = {
    "sprinkler","watering","trowel","shovel","hoe","scythe","basket",
    "reverter","favorite","tool","can","gloves","boots","hat",
    "fertilizer","pot","planter","rake","pitchfork"
}

local function guessCategory(name)
    local n = string.lower(name)
    if string.find(n, "fertile soil") then return "seed" end
    for _, kw in ipairs(SEED_NAMES) do if string.find(n,kw) then return "seed" end end
    for _, kw in ipairs(GEAR_NAMES) do if string.find(n,kw) then return "gear" end end
    return nil
end

local function isPricey(text)
    local t = string.lower(text)
    if t:find("%$") or t:find("coin") or t:find("shilling") or t:find("gem") or t:find("cash") then return true end
    local n = tonumber(text:match("^%d+$"))
    return n and n >= 500
end

local function extractSmallNum(text)
    local best
    for ns in text:gmatch("%d+") do
        local n = tonumber(ns)
        if n and n > 0 and n <= 999 then
            if not best or n < best then best = n end
        end
    end
    return best
end

-- ══════════════════════════════════════════════════════════════════════════════
-- 🔍 UI SCANNER  (scan PlayerGui trực tiếp, không dùng RemoteEvent)
-- ══════════════════════════════════════════════════════════════════════════════
local GUI_BLACKLIST = {"inventory","backpack","warehouse","storage","bank","sidebar","quest","stat","ghz_bot"}
local CARD_BLACKLIST = {"harvested","earned","playtime","shillings","total","level","xp","balance","owned","rank","prestige","v643","cash","gems"}

local function scanUIForStock(playerGui)
    local seeds, gear, tracker = {}, {}, {}

    local function processCard(card)
        if not (card:IsA("Frame") or card:IsA("ImageLabel") or card:IsA("TextButton")) then return end
        local labels, imgUrl = {}, ""
        local soldOut, foundName, bestLen = false, nil, 0

        for _, c in ipairs(card:GetDescendants()) do
            if c:IsA("TextLabel") and c.Text ~= "" and c.Visible then
                local txt = c.Text
                local lt  = txt:lower()

                -- Sold out?
                if lt:find("no stock") or lt:find("sold out") or lt:find("0 left") or lt:find("0x") then
                    soldOut = true break
                end

                -- Rác?
                local junk = false
                for _, w in ipairs(CARD_BLACKLIST) do if lt:find(w) then junk=true break end end
                if junk or isPricey(txt) then goto continue end

                table.insert(labels, txt)

                -- Whitelist name?
                local cat = guessCategory(txt)
                if cat and #txt > bestLen then bestLen = #txt; foundName = txt end
                ::continue::

            elseif c:IsA("ImageLabel") and c.Visible and c.Image ~= "" and imgUrl == "" then
                local id = c.Image:match("%d+")
                if id then imgUrl = "https://www.roblox.com/asset-thumbnail/image?assetId="..id.."&width=420&height=420&format=png" end
            end
        end

        if soldOut or not foundName then return end

        local name = foundName
        local stock = -1
        local explicit = false

        -- ① Tìm label CÓ từ khóa stock/left, KHÁC label tên
        for _, txt in ipairs(labels) do
            if txt ~= name then
                local lt = txt:lower()
                local isStockLbl = lt:find("stock") or lt:find("left") or txt:match("^%d+[xX]$") or txt:match("^[xX]%d+$")
                if isStockLbl then
                    local n = extractSmallNum(txt)
                    if n and n > 0 then stock = n; explicit = true; break end
                end
            end
        end

        -- ② Fallback: số bất kỳ KHÔNG phải trong label tên
        if not explicit then
            for _, txt in ipairs(labels) do
                if txt ~= name then
                    local n = extractSmallNum(txt)
                    if n and n > 0 and n < 1000 then stock = n; break end
                end
            end
        end

        if stock <= 0 or stock == -1 then return end
        local cat = guessCategory(name)
        if not cat then return end
        if tracker[name] then return end

        tracker[name] = true
        local item = { name=name, quantity=stock, category=cat, image=imgUrl }
        if cat == "seed" then table.insert(seeds, item)
        else                  table.insert(gear,  item) end
    end

    -- Iterasi ScreenGuis
    for _, gui in ipairs(playerGui:GetChildren()) do
        if not (gui:IsA("ScreenGui") and gui.Enabled) then goto nextGui end
        local gn = gui.Name:lower()
        local skip = false
        for _, b in ipairs(GUI_BLACKLIST) do if gn:find(b) then skip=true break end end
        if not skip then
            for _, cont in ipairs(gui:GetDescendants()) do
                if (cont:IsA("ScrollingFrame") or cont:IsA("Frame")) and
                   (cont:FindFirstChildWhichIsA("UIGridLayout") or cont:FindFirstChildWhichIsA("UIListLayout")) then
                    for _, card in ipairs(cont:GetChildren()) do
                        processCard(card)
                    end
                end
            end
        end
        ::nextGui::
    end

    return seeds, gear
end

-- Weather scan
local WEATHER_KW = {"starfall","storm","clear","rain","sunny","meteor","mowis","cloudy","windy","snow","acid"}
local function scanWeather(playerGui)
    local status, duration = "None", 0
    for _, kw in ipairs(WEATHER_KW) do
        for _, obj in ipairs(playerGui:GetDescendants()) do
            if (obj:IsA("TextLabel") or obj:IsA("TextButton")) and obj.Text then
                if obj.Text:lower():find(kw) and obj.Visible then
                    status = kw:gsub("^%l", string.upper)
                    -- Find mm:ss nearby
                    local function findDur(root)
                        for _, ch in ipairs(root:GetDescendants()) do
                            if ch:IsA("TextLabel") then
                                local m,s = ch.Text:match("(%d+):(%d+)")
                                if m and s then return tonumber(m)*60+tonumber(s) end
                                local sec = ch.Text:match("(%d+)s")
                                if sec then return tonumber(sec) end
                            end
                        end
                    end
                    duration = findDur(obj.Parent) or findDur(obj.Parent.Parent) or 0
                    return status, duration
                end
            end
        end
    end
    return status, duration
end

-- ══════════════════════════════════════════════════════════════════════════════
-- 📨 DISCORD WEBHOOK
-- ══════════════════════════════════════════════════════════════════════════════
local function sendWebhook(isWeather, seeds, gear, weatherStatus, weatherDur)
    if not CONFIG.WEBHOOK_ENABLED then return false end
    if not req then return false end
    local url = CONFIG.WEBHOOK_URL
    if not url or url == "" or url:find("PASTE") then return false end

    local fields = {}

    if not isWeather then
        if #seeds > 0 then
            local s = ""
            for _, it in ipairs(seeds) do s = s .. string.format("🌱 **%s** x%d\n", it.name, it.quantity) end
            table.insert(fields, { name="🌿 SEEDS", value=s, inline=true })
        end
        if #gear > 0 then
            local g = ""
            for _, it in ipairs(gear) do g = g .. string.format("🔧 **%s** x%d\n", it.name, it.quantity) end
            table.insert(fields, { name="⚙️ GEAR", value=g, inline=true })
        end
        if #fields == 0 then return false end
    else
        local serverTime = math.round(workspace:GetServerTimeNow())
        local endUnix    = serverTime + (weatherDur or 0)
        table.insert(fields, {
            name   = "⛅ WEATHER EVENT",
            value  = string.format("**%s**\nKết thúc: <t:%d:R>", weatherStatus, endUnix),
            inline = false
        })
    end

    local title = isWeather and "⛅ GHZ Weather Alert" or "🌱 GHZ Restock Alert"
    local color = isWeather and 0x2a6dff or 0x38ee17

    local ok = pcall(function()
        task.spawn(function()
            req({
                Url     = url,
                Method  = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body    = HttpService:JSONEncode({
                    username = "🌱 GHZ Stock Tracker",
                    embeds   = {{ title=title, color=color, fields=fields,
                        footer={ text="Garden Horizons • zenithghz.qzz.io" },
                        timestamp=DateTime.now():ToIsoDate()
                    }}
                })
            })
        end)
    end)
    return ok
end

-- ══════════════════════════════════════════════════════════════════════════════
-- 📡 API POST
-- ══════════════════════════════════════════════════════════════════════════════
local function postAPI(seeds, gear, weather)
    if not CONFIG.API_ENABLED or not req then return false end
    local ok, res = pcall(function()
        return req({
            Url     = CONFIG.API_URL,
            Method  = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body    = HttpService:JSONEncode({
                seeds    = seeds,
                gear     = gear,
                weather  = weather,
                timestamp = os.time()
            })
        })
    end)
    return ok and res and res.StatusCode == 200
end

-- ══════════════════════════════════════════════════════════════════════════════
-- ⛅ WEATHER EVENT HOOK (tức thì)
-- ══════════════════════════════════════════════════════════════════════════════
local curWeather = { status = "None", duration = 0 }

task.spawn(function()
    local ok, remote = pcall(function()
        return ReplicatedStorage:WaitForChild("GameEvents", 8):WaitForChild("WeatherEventStarted", 8)
    end)
    if not ok or not remote then
        print("[GHZ Bot] ⚠️ Weather remote không tìm thấy — dùng scan fallback")
        return
    end

    remote.OnClientEvent:Connect(function(evName, evLen)
        curWeather = { status = tostring(evName), duration = tonumber(evLen) or 0 }
        rowWeather.Text = "⛅ Weather: " .. curWeather.status
        sendWebhook(true, {}, {}, curWeather.status, curWeather.duration)
        print("[GHZ Bot] ⛅ Weather: " .. curWeather.status)
    end)
    print("[GHZ Bot] ⛅ Weather hook đã kết nối")
end)

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
-- ⏳ COUNTDOWN (chạy độc lập, luôn cập nhật)
-- ══════════════════════════════════════════════════════════════════════════════
task.spawn(function()
    while screenGui and screenGui.Parent do
        local t    = os.date("!*t")
        local sec  = (t.min % 5) * 60 + t.sec
        local left = math.max(300 - sec, 1)
        local m    = math.floor(left / 60)
        local s    = left % 60
        rowCount.Text = string.format("⏳ Restock UTC: %02d:%02d", m, s)
        task.wait(1)
    end
end)

-- ══════════════════════════════════════════════════════════════════════════════
-- 🔄 VÒNG LẶP CHÍNH — QUÉT SAU TỪNG MỐC RESTOCK 5 PHÚT
-- ══════════════════════════════════════════════════════════════════════════════
local function getWaitSec()
    local t   = os.date("!*t")
    local sec = (t.min % 5) * 60 + t.sec
    local left = 300 - sec - 1
    return left <= 0 and 300 or left
end

task.spawn(function()
    local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

    local function doScan()
        rowStatus.Text = "Status: 🔍 Đang quét..."
        local seeds, gear = scanUIForStock(PlayerGui)
        local wStatus, wDur = scanWeather(PlayerGui)
        curWeather = { status = wStatus, duration = wDur }

        rowSeeds.Text   = string.format("🌿 Seeds: %d loại", #seeds)
        rowGear.Text    = string.format("⚙️  Gear:  %d loại", #gear)
        rowWeather.Text = "⛅ Weather: " .. wStatus

        if #seeds == 0 and #gear == 0 then
            rowStatus.Text = "Status: ⚠️ Không thấy Shop UI"
            print("[GHZ Bot] ⚠️ Không thấy dữ liệu. Mở seed/gear shop!")
            return
        end

        -- API + Webhook song song
        local apiOk, hookOk
        task.spawn(function()
            apiOk  = postAPI(seeds, gear, curWeather)
            hookOk = sendWebhook(false, seeds, gear, nil, nil)

            local aStr = apiOk  and "✅" or (CONFIG.API_ENABLED and "❌" or "⏸")
            local hStr = hookOk and "✅" or (CONFIG.WEBHOOK_ENABLED and "❌" or "⏸")
            rowAPI.Text    = "📡 API: " .. aStr .. "   💬 Hook: " .. hStr
            rowStatus.Text = "Status: ✅ Đã cập nhật xong"

            print(string.format("[GHZ Bot] 📦 Seeds:%d Gear:%d Weather:%s API:%s Hook:%s",
                #seeds, #gear, wStatus,
                apiOk  and "OK" or "FAIL",
                hookOk and "OK" or (CONFIG.WEBHOOK_ENABLED and "FAIL" or "OFF")))
        end)
    end

    print("[GHZ Bot] 🚀 Khởi động — API: " .. CONFIG.API_URL)

    doScan()  -- Quét ngay lần đầu

    while screenGui and screenGui.Parent do
        local wait = getWaitSec()
        task.wait(wait)
        doScan()
    end
end)
