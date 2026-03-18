-------------------------------------------------------------------------------
-- 🌱 GHZ STOCK BOT  v4.0  — Garden Horizons
-- Phương pháp: Hook RemoteEvent (chính xác từ game developer)
-- Nếu chưa biết remote: dùng find_remotes.lua để tìm trước
--
-- HƯỚNG DẪN:
--   1. Chạy find_remotes.lua trong game, xem Output
--   2. Mở cửa hàng → tìm log 🎯 [STOCK-RELATED]
--   3. Điền tên remote vào STOCK_REMOTE_PATH bên dưới
--   4. Chạy bot này
-------------------------------------------------------------------------------

if _G.GHZ_Bot_Running then return end
_G.GHZ_Bot_Running = true

-- ══════════════════════════════════════════════════════════════════════════════
-- ⚙️  CẤU HÌNH
-- ══════════════════════════════════════════════════════════════════════════════
local CONFIG = {
    -- 📡 API
    API_URL          = "https://zenithghz.qzz.io/api/update",
    API_ENABLED      = true,

    -- 💬 Discord Webhook
    WEBHOOK_URL      = "https://discord.com/api/webhooks/PASTE_HERE",
    WEBHOOK_ENABLED  = false,

    -- 🎯 Đường dẫn RemoteEvent của game (điền sau khi dùng find_remotes.lua)
    -- Ví dụ: "ReplicatedStorage.GameEvents.StockUpdate"
    -- Để trống "" = dùng auto-hook tất cả remotes + UI scan fallback
    STOCK_REMOTE_PATH = "",

    ANTI_AFK          = true,
    DISABLE_RENDERING = true,
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

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "GHZ_Bot_UI"; screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling; screenGui.Parent = uiLayer

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 285, 0, 200); frame.Position = UDim2.new(0, 12, 0, 12)
frame.BackgroundColor3 = Color3.fromRGB(12, 15, 22); frame.BackgroundTransparency = 0.05
frame.BorderSizePixel = 0; frame.Parent = screenGui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)
local stroke = Instance.new("UIStroke"); stroke.Color = Color3.fromRGB(60, 200, 80)
stroke.Thickness = 1.5; stroke.Transparency = 0.4; stroke.Parent = frame

local titleBar = Instance.new("Frame"); titleBar.Size = UDim2.new(1, 0, 0, 30)
titleBar.BackgroundColor3 = Color3.fromRGB(18, 58, 20); titleBar.BorderSizePixel = 0; titleBar.Parent = frame
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 10)
local titleLbl = Instance.new("TextLabel"); titleLbl.Size = UDim2.new(1,0,1,0)
titleLbl.BackgroundTransparency = 1; titleLbl.Text = "🌱 GHZ Stock Bot  v4"
titleLbl.TextColor3 = Color3.fromRGB(145,255,145); titleLbl.Font = Enum.Font.GothamBold
titleLbl.TextSize = 14; titleLbl.Parent = titleBar

local function mkRow(y, color)
    local l = Instance.new("TextLabel"); l.Size = UDim2.new(1,-14,0,19)
    l.Position = UDim2.new(0,7,0,y); l.BackgroundTransparency = 1
    l.TextColor3 = color or Color3.fromRGB(225,225,225); l.Font = Enum.Font.Gotham
    l.TextSize = 11; l.TextXAlignment = Enum.TextXAlignment.Left; l.Parent = frame; return l
end

local rowMode    = mkRow(34, Color3.fromRGB(255, 220, 80))
local rowStatus  = mkRow(54, Color3.fromRGB(240, 240, 100))
local rowCount   = mkRow(74, Color3.fromRGB(180, 180, 255))
local rowSeeds   = mkRow(96, Color3.fromRGB(100, 255, 100))
local rowGear    = mkRow(116, Color3.fromRGB(255, 190, 80))
local rowWeather = mkRow(136, Color3.fromRGB(100, 195, 255))
local rowAPI     = mkRow(160, Color3.fromRGB(170, 170, 170))

rowStatus.Text  = "Status: 🟡 Khởi động..."
rowCount.Text   = "⏳ Restock: --:--"
rowSeeds.Text   = "🌿 Seeds: -"
rowGear.Text    = "⚙️  Gear:  -"
rowWeather.Text = "⛅ Weather: None"
rowAPI.Text     = "📡 -   💬 " .. (CONFIG.WEBHOOK_ENABLED and "Hook bật" or "Hook tắt")

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
        for _, it in ipairs(seeds) do s = s..string.format("🌱 **%s** x%d\n", it.name, it.quantity) end
        table.insert(fields, { name="🌿 SEEDS", value=s, inline=true })
    end
    if #gear > 0 then
        local g = ""
        for _, it in ipairs(gear) do g = g..string.format("🔧 **%s** x%d\n", it.name, it.quantity) end
        table.insert(fields, { name="⚙️ GEAR", value=g, inline=true })
    end
    if weather and weather.status ~= "None" then
        table.insert(fields, { name="⛅ WEATHER", value=weather.status, inline=false })
    end
    if #fields == 0 then return false end

    pcall(function()
        task.spawn(function()
            req({ Url=url, Method="POST", Headers={["Content-Type"]="application/json"},
                Body=HttpService:JSONEncode({ username="🌱 GHZ Stock Tracker",
                    embeds={{ title="🌱 GHZ Restock Alert", color=0x38ee17, fields=fields,
                        footer={text="Garden Horizons • zenithghz.qzz.io"},
                        timestamp=DateTime.now():ToIsoDate() }} }) })
        end)
    end)
    return true
end

local function postAPI(seeds, gear, weather)
    if not CONFIG.API_ENABLED or not req then return false end
    local ok, res = pcall(function()
        return req({ Url=CONFIG.API_URL, Method="POST",
            Headers={["Content-Type"]="application/json"},
            Body=HttpService:JSONEncode({seeds=seeds,gear=gear,weather=weather,timestamp=os.time()}) })
    end)
    return ok and res and res.StatusCode == 200
end

local function onDataReceived(seeds, gear, weather, source)
    rowSeeds.Text   = string.format("🌿 Seeds: %d loại", #seeds)
    rowGear.Text    = string.format("⚙️  Gear:  %d loại", #gear)
    rowWeather.Text = "⛅ Weather: " .. tostring((weather and weather.status) or "None")

    task.spawn(function()
        local apiOk  = postAPI(seeds, gear, weather or {status="None",duration=0})
        local hookOk = sendWebhook(seeds, gear, weather)
        local aStr   = apiOk  and "✅" or (CONFIG.API_ENABLED and "❌" or "⏸")
        local hStr   = hookOk and "✅" or (CONFIG.WEBHOOK_ENABLED and "❌" or "⏸")
        rowAPI.Text    = string.format("📡 API:%s  💬 Hook:%s  [%s]", aStr, hStr, source)
        rowStatus.Text = "Status: ✅ Đã cập nhật"
        print(string.format("[GHZ Bot] 📦 Seeds:%d Gear:%d | API:%s | Source:%s",
            #seeds, #gear, apiOk and "OK" or "FAIL", source))
    end)
end

-- ══════════════════════════════════════════════════════════════════════════════
-- 🎯 PHƯƠNG PHÁP 1: Hook từng RemoteEvent (tự động tìm stock)
-- ══════════════════════════════════════════════════════════════════════════════
local SEED_SET = {onion=1,corn=1,carrot=1,potato=1,tomato=1,blueberry=1,strawberry=1,
    grape=1,wheat=1,pumpkin=1,watermelon=1,mushroom=1,apple=1,orange=1,lemon=1,
    cherry=1,pear=1,pineapple=1,coconut=1,mango=1,peach=1,pepper=1,eggplant=1,
    sunflower=1,bamboo=1,cactus=1,rose=1,tulip=1,lily=1,daisy=1,orchid=1,lavender=1}
local GEAR_SET = {sprinkler=1,watering=1,trowel=1,shovel=1,hoe=1,scythe=1,basket=1,
    reverter=1,can=1,gloves=1,boots=1,hat=1,fertilizer=1,pot=1,planter=1,rake=1,pitchfork=1}
local WEATHER_SET = {starfall=1,storm=1,heatwave=1,rain=1,meteor=1,mowis=1,acid=1,snow=1,blizzard=1}

local function guessCategory(name)
    local n = name:lower()
    if n:find("fertile soil") then return "seed" end
    for kw in pairs(SEED_SET) do if n:find(kw) then return "seed" end end
    for kw in pairs(GEAR_SET) do if n:find(kw) then return "gear" end end
    return nil
end

-- Parse một table Roblox từ remote args
local function tryParseStockTable(data)
    if type(data) ~= "table" then return nil, nil end
    local seeds, gear = {}, {}

    local function processItem(name, qty)
        if type(name) ~= "string" or type(qty) ~= "number" then return end
        local cat = guessCategory(name)
        if cat == "seed" then
            table.insert(seeds, {name=name, quantity=math.floor(qty), category="seed"})
        elseif cat == "gear" then
            table.insert(gear, {name=name, quantity=math.floor(qty), category="gear"})
        end
    end

    -- Pattern 1: {itemName, quantity} pairs
    for k, v in pairs(data) do
        if type(k) == "string" and type(v) == "number" then
            processItem(k, v)
        elseif type(v) == "table" then
            -- Pattern 2: {name="X", quantity=N} or {Name="X", Stock=N}
            local name = v.name or v.Name or v.item or v.Item
            local qty  = v.quantity or v.Quantity or v.stock or v.Stock or v.amount or v.Amount
            if name and qty then processItem(tostring(name), tonumber(qty) or 0) end
        end
    end

    return seeds, gear
end

-- Hook tất cả RemoteEvents và tự nhận diện stock data
local hooksActive = false
local function hookAllRemotes()
    if hooksActive then return end
    hooksActive = true
    local count = 0
    for _, v in pairs(game:GetDescendants()) do
        if v:IsA("RemoteEvent") then
            local path = v:GetFullName():lower()
            -- Bỏ qua remotes không liên quan
            local skip = path:find("gui") or path:find("input") or path:find("mouse") or
                         path:find("chat") or path:find("audio") or path:find("camera")
            if not skip then
                count = count + 1
                v.OnClientEvent:Connect(function(...)
                    local args = {...}
                    for _, arg in ipairs(args) do
                        if type(arg) == "table" then
                            local seeds, gear = tryParseStockTable(arg)
                            if seeds and (#seeds > 0 or #gear > 0) then
                                print("[GHZ Bot] 🎯 Stock từ Remote: " .. v:GetFullName())
                                onDataReceived(seeds, gear, {status="None",duration=0}, "Remote:"..v.Name)
                            end
                        end
                        -- Check weather string
                        if type(arg) == "string" then
                            local al = arg:lower()
                            for kw in pairs(WEATHER_SET) do
                                if al == kw or al:find(kw) then
                                    print("[GHZ Bot] ⛅ Weather từ Remote: " .. v:GetFullName() .. " = " .. arg)
                                    rowWeather.Text = "⛅ Weather: " .. arg
                                    break
                                end
                            end
                        end
                    end
                end)
            end
        end
    end
    print(string.format("[GHZ Bot] 🎯 Đã hook %d RemoteEvents", count))
    rowMode.Text = "Mode: 🎯 Remote Hook (" .. count .. " remotes)"
end

-- ══════════════════════════════════════════════════════════════════════════════
-- 🔍 PHƯƠNG PHÁP 2: UI Scan (fallback nếu remote không có data)
-- ══════════════════════════════════════════════════════════════════════════════
local function findTextLabelWithKeyword(parent, keyword)
    for _, obj in pairs(parent:GetDescendants()) do
        if (obj:IsA("TextLabel") or obj:IsA("TextBox") or obj:IsA("TextButton")) and obj.Text then
            if string.match(string.lower(obj.Text), string.lower(keyword)) then return obj end
        end
    end
    return nil
end

local SEED_NAMES = {"onion","corn","carrot","potato","tomato","blueberry","strawberry",
    "grape","wheat","pumpkin","watermelon","mushroom","apple","orange","lemon",
    "cherry","pear","pineapple","coconut","mango","peach","pepper","eggplant",
    "sunflower","bamboo","cactus","rose","tulip","lily","daisy","orchid","lavender","seed","sprout","plant","fertile soil"}
local GEAR_NAMES = {"sprinkler","watering","trowel","shovel","hoe","scythe","basket",
    "reverter","can","gloves","boots","hat","fertilizer","pot","planter","rake","pitchfork"}

local function guessUI(itemName)
    local name = itemName:lower()
    if name:find("fertile soil") then return "seed" end
    for _, kw in ipairs(SEED_NAMES) do if name:find(kw) then return "seed" end end
    for _, kw in ipairs(GEAR_NAMES) do if name:find(kw) then return "gear" end end
    return nil
end

local function isPricey(text)
    local t = text:lower()
    if t:match("%$") or t:find("coin") or t:find("cash") or t:find("gem") or t:find("shilling") then return true end
    local n = tonumber(text:match("^%d+$")); return n and n >= 500
end

local function extractSmall(text)
    local best
    for n in text:gmatch("%d+") do
        local num = tonumber(n)
        if num and num > 0 and num <= 999 then if not best or num < best then best = num end end
    end
    return best
end

local function uiScan()
    local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
    local seeds, gear, tracker = {}, {}, {}
    local weather = { status="None", duration=0 }
    local BL_GUI  = {"inventory","backpack","warehouse","storage","bank","sidebar","quest","stat","ghz_bot"}
    local BL_WORD = {"harvested","earned","playtime","shillings","total","level","xp","balance","owned","rank","confirm","back","next","v643","money","cash","gems"}

    -- Weather
    for _, kw in ipairs({"starfall","storm","clear","rain","sunny","meteor","mowis","cloudy","windy","snow","acid"}) do
        local lb = findTextLabelWithKeyword(PlayerGui, kw)
        if lb then
            weather.status = kw:gsub("^%l", string.upper)
            local function dDur(root)
                for _, c in pairs(root:GetDescendants()) do
                    if c:IsA("TextLabel") then
                        local m,s = c.Text:match("(%d+):(%d+)")
                        if m and s then return tonumber(m)*60+tonumber(s) end
                        local sec = c.Text:match("(%d+)s"); if sec then return tonumber(sec) end
                    end
                end
            end
            weather.duration = dDur(lb.Parent) or dDur(lb.Parent.Parent) or 0; break
        end
    end

    -- Items
    local function processCard(card)
        if not (card:IsA("Frame") or card:IsA("ImageLabel") or card:IsA("TextButton")) then return end
        local labels, img, soldOut, bestName = {}, "", false, nil
        for _, c in ipairs(card:GetDescendants()) do
            if c:IsA("TextLabel") and c.Text ~= "" and c.Visible then
                local txt, lt = c.Text, c.Text:lower()
                if lt:find("no stock") or lt:find("sold out") then soldOut=true; break end
                local junk = false
                for _, w in ipairs(BL_WORD) do if lt:find(w) then junk=true; break end end
                if not junk and not isPricey(txt) then
                    table.insert(labels, txt)
                    local cat = guessUI(txt)
                    if cat and (not bestName or #txt > #bestName) then bestName = txt end
                end
            elseif c:IsA("ImageLabel") and c.Visible and c.Image ~= "" and img == "" then
                local id = c.Image:match("%d+")
                if id then img = "https://www.roblox.com/asset-thumbnail/image?assetId="..id.."&width=420&height=420&format=png" end
            end
        end
        if soldOut or not bestName then return end
        local stock = -1
        for _, txt in ipairs(labels) do
            if txt ~= bestName then
                local lt = txt:lower()
                if lt:find("stock") or lt:find("left") or txt:match("^%d+[xX]$") or txt:match("^[xX]%d+$") then
                    local n = extractSmall(txt); if n and n > 0 then stock=n; break end
                end
            end
        end
        if stock == -1 then for _, txt in ipairs(labels) do if txt ~= bestName then local n = extractSmall(txt); if n then stock=n; break end end end end
        if stock <= 0 then return end
        local cat = guessUI(bestName); if not cat or tracker[bestName] then return end
        tracker[bestName] = true
        local item = {name=bestName, quantity=stock, category=cat, image=img}
        if cat == "seed" then table.insert(seeds, item) else table.insert(gear, item) end
    end

    for _, gui in ipairs(PlayerGui:GetChildren()) do
        if gui:IsA("ScreenGui") and gui.Enabled then
            local gn = gui.Name:lower(); local skip = false
            for _, b in ipairs(BL_GUI) do if gn:find(b) then skip=true; break end end
            if not skip then
                for _, cont in ipairs(gui:GetDescendants()) do
                    if (cont:IsA("ScrollingFrame") or cont:IsA("Frame")) and
                       (cont:FindFirstChildWhichIsA("UIGridLayout") or cont:FindFirstChildWhichIsA("UIListLayout")) then
                        for _, card in ipairs(cont:GetChildren()) do processCard(card) end
                    end
                end
            end
        end
    end
    return seeds, gear, weather
end

-- ══════════════════════════════════════════════════════════════════════════════
-- 🛡️ ANTI-AFK
-- ══════════════════════════════════════════════════════════════════════════════
if CONFIG.ANTI_AFK then
    LocalPlayer.Idled:Connect(function()
        VirtualUser:CaptureController(); VirtualUser:ClickButton2(Vector2.new())
        print("[GHZ Bot] 🛡️ Anti-AFK")
    end)
end

-- ══════════════════════════════════════════════════════════════════════════════
-- ⏳ COUNTDOWN
-- ══════════════════════════════════════════════════════════════════════════════
task.spawn(function()
    while screenGui and screenGui.Parent do
        local t = os.date("!*t"); local sec = (t.min%5)*60 + t.sec
        local left = math.max(300-sec, 1)
        rowCount.Text = string.format("⏳ Restock UTC: %02d:%02d", math.floor(left/60), left%60)
        task.wait(1)
    end
end)

-- ══════════════════════════════════════════════════════════════════════════════
-- 🚀 KHỞI ĐỘNG
-- ══════════════════════════════════════════════════════════════════════════════
task.spawn(function()
    task.wait(2)

    -- Kích hoạt Remote Hook (ưu tiên)
    hookAllRemotes()

    -- Fallback: UI scan mỗi 5 phút
    local function getWait()
        local t = os.date("!*t"); local s = (t.min%5)*60 + t.sec
        local left = 300-s-1; return left<=0 and 300 or left
    end

    print("[GHZ Bot] 🚀 v4 sẵn sàng")
    print("[GHZ Bot] 🎯 Remote hook đang active — sẽ tự bắt data khi shop restock")
    print("[GHZ Bot] 📋 Nếu remote không fire, UI scan sẽ chạy mỗi 5 phút")

    -- Fallback UI scan vòng lặp
    task.wait(3)
    rowStatus.Text = "Status: 🎯 Remote listening + UI fallback"
    rowMode.Text   = "Mode: 🎯 Remote Hook + 🖥️ UI Fallback"

    while screenGui and screenGui.Parent do
        local waitSec = getWait()
        for i = waitSec, 1, -1 do
            if not (screenGui and screenGui.Parent) then return end
            task.wait(1)
        end
        -- UI scan fallback
        rowStatus.Text = "Status: 🔍 UI Scan fallback..."
        local seeds, gear, weather = uiScan()
        if #seeds > 0 or #gear > 0 then
            print(string.format("[GHZ Bot] 🖥️ UI Scan: Seeds:%d Gear:%d", #seeds, #gear))
            onDataReceived(seeds, gear, weather, "UIFallback")
        else
            rowStatus.Text = "Status: ⚠️ UI: không thấy shop"
            print("[GHZ Bot] ⚠️ UI Scan không thấy shop. Mở seed/gear shop!")
        end
    end
end)