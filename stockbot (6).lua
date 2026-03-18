-------------------------------------------------------------------------------
-- GHZ STOCK BOT — Remote Engine
-- Weather webhook only, Stock to API only
-------------------------------------------------------------------------------

if _G.GHZ_Bot_Running then return end
_G.GHZ_Bot_Running = true

-- ══════════════════════════════════════════════════════════════════════════════
-- CONFIG
-- ══════════════════════════════════════════════════════════════════════════════
local CONFIG = {
    API_URL         = "https://zenithghz.qzz.io/api/update",
    NOTIFY_URL      = "https://zenithghz.qzz.io/api/adminnotify",
    API_ENABLED     = true,

    WEBHOOK_URL     = "https://discord.com/api/webhooks/PASTE_HERE",
    WEBHOOK_ENABLED = false,

    SKIP_EMPTY        = true,
    ANTI_AFK          = true,
    DISABLE_RENDERING = true,

    WEBHOOK_COOLDOWN  = 15,   -- giay giua 2 lan gui Discord
    RESTOCK_DEBOUNCE  = 10,   -- giay debounce stock
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
-- UI
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
local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(50, 180, 255); stroke.Thickness = 1.5
stroke.Transparency = 0.35; stroke.Parent = frame

local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1,0,0,30)
titleBar.BackgroundColor3 = Color3.fromRGB(18, 50, 90)
titleBar.BorderSizePixel = 0; titleBar.Parent = frame
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 10)
local titleLbl = Instance.new("TextLabel")
titleLbl.Size = UDim2.new(1,0,1,0); titleLbl.BackgroundTransparency = 1
titleLbl.Text = "GHZ Stock Bot"
titleLbl.TextColor3 = Color3.fromRGB(180, 220, 255)
titleLbl.Font = Enum.Font.GothamBold; titleLbl.TextSize = 13; titleLbl.Parent = titleBar

local function mkRow(y, color)
    local l = Instance.new("TextLabel"); l.Size = UDim2.new(1,-14,0,20)
    l.Position = UDim2.new(0,7,0,y); l.BackgroundTransparency = 1
    l.TextColor3 = color or Color3.fromRGB(220,220,220); l.Font = Enum.Font.Gotham
    l.TextSize = 11; l.TextXAlignment = Enum.TextXAlignment.Left; l.Parent = frame; return l
end

local rowStatus  = mkRow(33,  Color3.fromRGB(255, 230, 80))
local rowCount   = mkRow(53,  Color3.fromRGB(180, 180, 255))
local rowSeeds   = mkRow(73,  Color3.fromRGB(100, 255, 100))
local rowGear    = mkRow(92,  Color3.fromRGB(255, 190, 80))
local rowWeather = mkRow(112, Color3.fromRGB(100, 205, 255))
local rowAPI     = mkRow(135, Color3.fromRGB(150, 150, 150))
local rowHook    = mkRow(155, Color3.fromRGB(150, 150, 150))
local rowTime    = mkRow(175, Color3.fromRGB(120, 120, 120))

rowStatus.Text  = "Status: cho data..."
rowCount.Text   = "Restock: --:--"
rowSeeds.Text   = "Seeds: -"
rowGear.Text    = "Gear:  -"
rowWeather.Text = "Weather: None"
rowAPI.Text     = "API: -"
rowHook.Text    = "Hook: " .. (CONFIG.WEBHOOK_ENABLED and "bat" or "tat")
rowTime.Text    = "-"

-- ══════════════════════════════════════════════════════════════════════════════
-- STATE
-- ══════════════════════════════════════════════════════════════════════════════
local currentWeather      = { status = "None", duration = 0 }
local lastSeeds, lastGear = {}, {}
local lastStockHash       = ""
local lastRestockTime     = 0
local lastWebhookTime     = 0

-- ══════════════════════════════════════════════════════════════════════════════
-- WEATHER INFO (gardenhorizonswiki.com/weather)
-- ══════════════════════════════════════════════════════════════════════════════
local WEATHER_INFO = {
    ["Sunny"]         = { color = 0xFF8800, desc = "Clear sunny day, no special effects.",                           muts = "None" },
    ["Clear"]         = { color = 0x55FF55, desc = "Clear skies, no special effects.",                               muts = "None" },
    ["Cloudy"]        = { color = 0xCCCCCC, desc = "Overcast skies, normal growth speed.",                           muts = "None" },
    ["Windy"]         = { color = 0x88CCFF, desc = "Strong winds may carry seeds from other areas.",                 muts = "Unconfirmed" },
    ["Fog"]           = { color = 0xAAAAAA, desc = "Thick fog blankets the entire map.",                             muts = "Foggy x1.25 | Chilled x1.5 | combo Mossy x3.5" },
    ["Foggy"]         = { color = 0xAAAAAA, desc = "Thick fog blankets the entire map.",                             muts = "Foggy x1.25 | Chilled x1.5 | combo Mossy x3.5" },
    ["Rain"]          = { color = 0x55AAFF, desc = "Rainfall boosts growth speed by **+25%**.",                      muts = "Soaked x1.25 (60%) | Flooded x1.75 (40%)" },
    ["Snow"]          = { color = 0xAAEEFF, desc = "Snowfall slows growth speed by **-15%**.",                       muts = "Snowy x2 (50%) | Chilled x1.5 (33%) | Frostbit x3.5 (17%)" },
    ["Sandstorm"]     = { color = 0xDDCC99, desc = "Sandstorm boosts growth speed by **+20%**.",                     muts = "Sandy x2.5" },
    ["Storm"]         = { color = 0xAA00FF, desc = "Thunderstorm boosts growth speed by **+50%**!",                  muts = "Shocked x4.5" },
    ["Starfall"]      = { color = 0xFFD700, desc = "Stars fall from the sky — highest mutation value in the game!",  muts = "Starstruck x6.5" },
    ["Meteor"]        = { color = 0xFF4400, desc = "Meteor shower boosts growth by **+20%**.",                        muts = "Meteoric x10" },
    ["Tsunami"]       = { color = 0x0055AA, desc = "Giant waves sweep the island — crops are not destroyed (2.5% per crop).", muts = "Tidal x2.0" },
    ["Heavy Rain"]    = { color = 0x880000, desc = "Heavy rain + Cthulhu boss! Growth **+50%**. Defeat boss for Lumenbark seed.", muts = "Ancient x7.5" },
    ["Acid Rain"]     = { color = 0x88FF00, desc = "Toxic acid rain — Admin event.",                                 muts = "Special (Admin)" },
    ["Mowis"]         = { color = 0x2200FF, desc = "Mowis storm — a powerful variant of Storm.",                     muts = "Similar to Storm" },
    ["DJ Kine"]       = { color = 0xFF00FF, desc = "Music party event — growth speed **+100%**!",                    muts = "Party x11.5" },
    ["Beam Clash"]    = { color = 0xFF6688, desc = "Beams clash in the sky.",                                        muts = "Salad x10 | Banned x10" },
    ["Black Hole"]    = { color = 0x111111, desc = "A cosmic black hole appears.",                                   muts = "Nova x6.5 | Galactic (TBA)" },
    ["Strange Weather"]= { color = 0x886699, desc = "Strange weather follows a boss defeat or Admin event.",         muts = "Strange x2.0" },
    ["StrangeWeather"] = { color = 0x886699, desc = "Strange weather follows a boss defeat or Admin event.",         muts = "Strange x2.0" },
}
local WEATHER_FALLBACK = { color = 0x888888, desc = "Special weather event.", muts = "Unknown" }

local WEATHER_WHITELIST = {
    "Clear","Sunny","Cloudy","Windy","Fog","Foggy","Rain","Snow",
    "Sandstorm","Storm","Starfall","Meteor","Tsunami","Heavy Rain",
    "Acid Rain","Mowis","DJ Kine","Beam Clash","Black Hole","StrangeWeather","Strange Weather",
}

-- ══════════════════════════════════════════════════════════════════════════════
-- TIMESTAMP HELPER
-- ══════════════════════════════════════════════════════════════════════════════
local function ts()
    return os.date("[%H:%M:%S]")
end

-- ══════════════════════════════════════════════════════════════════════════════
-- API POST
-- ══════════════════════════════════════════════════════════════════════════════
local function postAPI(seeds, gear, weather)
    if not CONFIG.API_ENABLED or not req then return end
    local ok, err = pcall(req, {
        Url     = CONFIG.API_URL,
        Method  = "POST",
        Headers = { ["Content-Type"] = "application/json" },
        Body    = HttpService:JSONEncode({
            seeds     = seeds   or {},
            gear      = gear    or {},
            weather   = weather or { status = "None", duration = 0 },
            timestamp = os.time(),
        }),
    })
    if ok then
        rowAPI.Text = "API: OK " .. os.date("%H:%M:%S")
        print(ts() .. " [GHZ] API OK | seeds=" .. #(seeds or {}) .. " gear=" .. #(gear or {}) .. " weather=" .. (weather and weather.status or "None"))
    else
        rowAPI.Text = "API: ERR " .. tostring(err):sub(1, 35)
        print(ts() .. " [GHZ] API ERR: " .. tostring(err))
    end
end

-- ══════════════════════════════════════════════════════════════════════════════
-- DISCORD EMBEDS
-- Embed 1: Weather (sent when weather changes)
-- Embed 2: Stock  (sent when stock restocks)
-- ══════════════════════════════════════════════════════════════════════════════
local function webhookPost(payload, label)
    if not CONFIG.WEBHOOK_ENABLED or not req then return end
    if CONFIG.WEBHOOK_URL:find("PASTE") then return end
    task.spawn(function()
        local ok, err = pcall(req, {
            Url     = CONFIG.WEBHOOK_URL,
            Method  = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body    = HttpService:JSONEncode(payload),
        })
        if ok then
            rowHook.Text = "Hook: OK " .. os.date("%H:%M:%S")
            print(ts() .. " [GHZ] Discord OK: " .. label)
        else
            rowHook.Text = "Hook: ERR"
            print(ts() .. " [GHZ] Discord ERR (" .. label .. "): " .. tostring(err))
        end
    end)
end

-- Weather embed — fires when weather starts
local function sendWeatherWebhook(weather)
    if tick() - lastWebhookTime < CONFIG.WEBHOOK_COOLDOWN then
        print(ts() .. " [GHZ] Webhook cooldown"); return
    end
    lastWebhookTime = tick()

    local wStatus = weather and weather.status or "None"
    local wInfo   = WEATHER_INFO[wStatus] or WEATHER_FALLBACK

    webhookPost({
        ["username"]   = "Garden Horizons",
        ["avatar_url"] = "https://cdn-icons-png.flaticon.com/512/3234/3234972.png",
        ["embeds"] = {{
            ["title"]       = "Weather Update — " .. wStatus,
            ["description"] = wInfo.desc,
            ["color"]       = wInfo.color,
            ["fields"] = {
                { ["name"] = "Mutations", ["value"] = wInfo.muts, ["inline"] = true },
                { ["name"] = "Duration",  ["value"] = "5 minutes",               ["inline"] = true },
            },
            ["footer"]    = { ["text"] = "Garden Horizons | gardenhorizonswiki.com/weather",
                              ["icon_url"] = "https://cdn-icons-png.flaticon.com/512/3234/3234972.png" },
            ["timestamp"] = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        }},
    }, "weather:" .. wStatus)
end

-- Stock embed — fires when shop restocks
local function sendStockWebhook(seeds, gear, weather)
    if tick() - lastWebhookTime < CONFIG.WEBHOOK_COOLDOWN then
        print(ts() .. " [GHZ] Webhook cooldown (stock)"); return
    end
    lastWebhookTime = tick()

    local wStatus = weather and weather.status or "None"
    local wInfo   = WEATHER_INFO[wStatus] or WEATHER_FALLBACK

    local seedLines = {}
    for _, v in ipairs(seeds) do
        table.insert(seedLines, string.format("**%s** x%d", v.name, v.quantity))
    end
    local gearLines = {}
    for _, v in ipairs(gear) do
        table.insert(gearLines, string.format("**%s** x%d", v.name, v.quantity))
    end

    local seedStr = #seedLines > 0 and table.concat(seedLines, "\n") or "_Out of stock_"
    local gearStr = #gearLines > 0 and table.concat(gearLines, "\n") or "_Out of stock_"

    webhookPost({
        ["username"]   = "Garden Horizons",
        ["avatar_url"] = "https://cdn-icons-png.flaticon.com/512/3234/3234972.png",
        ["embeds"] = {{
            ["title"]       = "Shop Restocked!",
            ["description"] = "Current weather: **" .. wStatus .. "** — " .. wInfo.desc,
            ["color"]       = 0x2ECC71,
            ["fields"] = {
                { ["name"] = "Seeds (" .. #seeds .. ")", ["value"] = seedStr:sub(1,1024), ["inline"] = true },
                { ["name"] = "Gear ("  .. #gear  .. ")", ["value"] = gearStr:sub(1,1024), ["inline"] = true },
            },
            ["footer"]    = { ["text"] = "Garden Horizons",
                              ["icon_url"] = "https://cdn-icons-png.flaticon.com/512/3234/3234972.png" },
            ["timestamp"] = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        }},
    }, "stock:" .. #seeds .. "s/" .. #gear .. "g")
end

local function postAdminMessage(msg)
    if not CONFIG.API_ENABLED or not req or not CONFIG.NOTIFY_URL then return end
    task.spawn(function()
        pcall(req, {
            Url     = CONFIG.NOTIFY_URL,
            Method  = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body    = HttpService:JSONEncode({ message = msg, timestamp = os.time() }),
        })
    end)
end

-- ══════════════════════════════════════════════════════════════════════════════
-- STOCK UPDATE — API + Discord stock embed
-- Note: Game sends SeedShop and GearShop in separate RemoteEvents!
-- We must accumulate data for 1.5s before sending to avoid missing half the shop.
-- ══════════════════════════════════════════════════════════════════════════════
local pendingStockTimer = nil
local pendingSeeds      = nil
local pendingGear       = nil

local function flushStockUpdate()
    pendingStockTimer = nil
    
    -- Merge collected data
    if pendingSeeds then lastSeeds = pendingSeeds; pendingSeeds = nil end
    if pendingGear  then lastGear  = pendingGear;  pendingGear  = nil end

    -- Check if stock actually changed
    local ok2, hash = pcall(function()
        return HttpService:JSONEncode({ s = lastSeeds, g = lastGear })
    end)
    if not ok2 then hash = tostring(#lastSeeds) .. tostring(#lastGear) end

    if hash == lastStockHash then
        print(ts() .. " [GHZ] Stock duplicate, skip")
        return
    end

    lastStockHash   = hash
    lastRestockTime = tick()

    rowStatus.Text = "Status: Stock moi!"
    rowSeeds.Text  = "Seeds: " .. #lastSeeds .. " loai"
    rowGear.Text   = "Gear:  " .. #lastGear  .. " loai"
    rowTime.Text   = os.date("%H:%M:%S")

    postAPI(lastSeeds, lastGear, currentWeather)
    sendStockWebhook(lastSeeds, lastGear, currentWeather)
    print(ts() .. string.format(" [GHZ] Stock merged: %d seeds, %d gear", #lastSeeds, #lastGear))
end

local function onStockUpdate(seeds, gear, source)
    if #seeds == 0 and #gear == 0 then return end

    -- Accumulate what we found in this specific RemoteEvent
    if #seeds > 0 then pendingSeeds = seeds end
    if #gear  > 0 then pendingGear  = gear  end

    -- Start buffer timer if not already ticking
    if not pendingStockTimer then
        pendingStockTimer = task.delay(1.5, flushStockUpdate)
    end
end

-- ══════════════════════════════════════════════════════════════════════════════
-- WEATHER CHANGE
-- Only reject: empty name, "None", "Unknown"
-- Do NOT reject on duration==0 — game sometimes fires start event with 0 duration
-- To detect weather-end: game fires same name again with 0 duration OR fires a
-- special "Clear/None" name — we handle by resetting when name is invalid only
-- ══════════════════════════════════════════════════════════════════════════════
local function onWeatherChange(wName, wDuration, source)
    -- Skip completely invalid names
    if not wName or wName == "" or wName == "None" or wName == "Unknown" then
        -- If we had a weather before and now name is gone, reset state
        if currentWeather.status ~= "None" then
            print(ts() .. " [GHZ] Weather ended (no name) — reset state")
            currentWeather.status   = "None"
            currentWeather.duration = 0
            rowWeather.Text = "Weather: --"
        end
        return
    end

    -- Same weather name → just update duration, no re-send
    if wName == currentWeather.status then
        currentWeather.duration = wDuration
        return
    end

    -- New weather — accept regardless of duration value
    currentWeather.status   = wName
    currentWeather.duration = wDuration
    rowWeather.Text = wName .. " (5 min)"
    rowTime.Text    = os.date("%H:%M:%S")

    print(ts() .. string.format(" [GHZ] New weather: %s (dur=%d) src=%s", wName, wDuration, source))

    postAPI(lastSeeds, lastGear, currentWeather)
    sendWeatherWebhook(currentWeather)
end

-- ══════════════════════════════════════════════════════════════════════════════
-- PARSER — Context-aware deep scan
-- Ho tro: SeedShop.Items.TenItem.{Amount, MaxAmount}
--         hoac bat ky cau truc nested nao co Amount
-- ══════════════════════════════════════════════════════════════════════════════
local GEAR_KEYWORDS = {
    "sprinkler","trowel","shovel","scythe","hoe","watering","can","wrench",
    "basket","reverter","rake","plow","fertilizer","lantern","fence",
    "pot","planter","gear","tool","recall",
}
local function guessIsGear(name)
    local n = name:lower()
    for _, g in ipairs(GEAR_KEYWORDS) do
        if n:find(g) then return true end
    end
    return false
end

local function parseSeedGear(root)
    local seeds, gear = {}, {}
    local tracked = {}

    -- Deep recursive scan, ke thua context category tu ancestor key
    local function scan(t, depth, ctxCat)
        if depth > 12 or type(t) ~= "table" then return end

        for k, v in pairs(t) do
            if type(v) ~= "table" then
                -- Bỏ qua non-table
            else
                local ks = tostring(k):lower()

                -- Cap nhat context tu key hien tai
                local childCat = ctxCat
                if ks:find("seed") and not ks:find("gear") then
                    childCat = "seed"
                elseif ks:find("gear") or ks:find("tool") then
                    childCat = "gear"
                end

                -- Kiem tra xem v co phai la item entry khong:
                -- Item entry = table co Amount hoac MaxAmount
                -- va key la ten item (khong phai cac tu khoa cau truc)
                local isStructureKey = ks:find("shop") or ks:find("data") or ks:find("item") or ks:find("store") or ks:find("market") or ks:find("index")
                local amt = nil
                if not isStructureKey and type(k) == "string" then
                    -- Lay 1 so co the ep kieu tu v
                    local rawAmt = v.Amount or v.amount or v.Quantity or v.quantity or v.Stock or v.stock
                    if rawAmt == nil then rawAmt = v.MaxAmount or v.maxAmount end
                    if type(rawAmt) == "number" then
                        amt = rawAmt
                    elseif type(rawAmt) == "string" then
                        amt = tonumber(rawAmt)
                    end
                end

                if type(amt) == "number" and not tracked[k] then
                    -- Day la item entry, k = ten item
                    if not CONFIG.SKIP_EMPTY or amt > 0 then
                        tracked[k] = true
                        local finalCat = childCat or (guessIsGear(k) and "gear" or "seed")
                        local entry = { name = k, quantity = amt, category = finalCat }
                        if finalCat == "gear" then
                            table.insert(gear, entry)
                        else
                            table.insert(seeds, entry)
                        end
                        print("[GHZ] ITEM: [" .. finalCat .. "] " .. k .. " x" .. amt)
                    end
                else
                    -- Chua phai item -> di sau hon
                    scan(v, depth + 1, childCat)
                end
            end
        end
    end

    if type(root) == "table" then
        scan(root, 1, nil)

        -- Fallback: dang array {Name=, Amount=}
        if #seeds == 0 and #gear == 0 then
            for _, v in pairs(root) do
                if type(v) == "table" then
                    local name = v.Name or v.name or v.Item or v.item
                    local amt  = v.Amount or v.amount or v.Quantity or v.quantity or v.Stock or v.stock
                    if type(name) == "string" and type(amt) == "number" and not tracked[name] then
                        if not CONFIG.SKIP_EMPTY or amt > 0 then
                            tracked[name] = true
                            local cat = guessIsGear(name) and "gear" or "seed"
                            local entry = { name = name, quantity = amt, category = cat }
                            if cat == "gear" then table.insert(gear, entry) else table.insert(seeds, entry) end
                        end
                    end
                end
            end
        end
    end

    return seeds, gear
end

-- ══════════════════════════════════════════════════════════════════════════════
-- HOOK REMOTES
-- ══════════════════════════════════════════════════════════════════════════════
local function hookGameRemotes()
    local remotes = ReplicatedStorage:WaitForChild("RemoteEvents", 10)
    if not remotes then
        print("[GHZ] Khong tim thay RemoteEvents!")
        rowStatus.Text = "Status: ERR RemoteEvents"
        return false
    end

    local hooked = 0

    -- 1. REPLICASET -- hook truc tiep
    local replicaSet = remotes:WaitForChild("ReplicaSet", 5)
    if replicaSet then
        replicaSet.OnClientEvent:Connect(function(...)
            local args = { ... }
            -- Debug log ngan
            local ok, encoded = pcall(function() return HttpService:JSONEncode(args) end)
            if ok then
                print("[GHZ] ReplicaSet fired:", encoded:sub(1, 300))
            end

            for _, arg in ipairs(args) do
                if type(arg) == "table" then
                    -- Thu truc tiep
                    local s, g = parseSeedGear(arg)
                    if #s > 0 or #g > 0 then
                        onStockUpdate(s, g, "ReplicaSet")
                        break
                    end
                    -- Thu .Data (ReplicaService thuong wrap trong .Data)
                    if type(arg.Data) == "table" then
                        local s2, g2 = parseSeedGear(arg.Data)
                        if #s2 > 0 or #g2 > 0 then
                            onStockUpdate(s2, g2, "ReplicaSet.Data")
                            break
                        end
                    end
                end
            end
        end)
        hooked = hooked + 1
        print("[GHZ] Hooked: ReplicaSet")
    else
        print("[GHZ] WARN: Khong tim thay ReplicaSet trong RemoteEvents")
    end

    -- 2. FALLBACK: ShopRestocked va cac remote co ten lien quan
    for _, rem in pairs(remotes:GetChildren()) do
        if rem:IsA("RemoteEvent") and rem.Name ~= "ReplicaSet" then
            local nl = rem.Name:lower()
            if nl:find("restock") or nl:find("shopdata") or nl:find("replica") or nl:find("getshop") then
                rem.OnClientEvent:Connect(function(...)
                    local args = { ... }
                    local ok, encoded = pcall(function() return HttpService:JSONEncode(args) end)
                    if not ok then return end
                    -- Chi xu ly neu co tu khoa lien quan stock
                    if not (encoded:lower():find("amount") and (encoded:lower():find("seed") or encoded:lower():find("gear") or encoded:lower():find("shop"))) then return end
                    print("[GHZ] Fallback " .. rem.Name .. ":", encoded:sub(1, 200))
                    for _, arg in ipairs(args) do
                        if type(arg) == "table" then
                            local s, g = parseSeedGear(arg)
                            if #s > 0 or #g > 0 then
                                onStockUpdate(s, g, rem.Name); break
                            end
                        end
                    end
                end)
                hooked = hooked + 1
                print("[GHZ] Hooked (fallback):", rem.Name)
            end
        end
    end

    -- 3. WEATHER
    for _, rem in pairs(remotes:GetChildren()) do
        if rem:IsA("RemoteEvent") and rem.Name:lower():find("weather") then
            rem.OnClientEvent:Connect(function(...)
                local args = { ... }
                local ok, encoded = pcall(function() return HttpService:JSONEncode(args) end)
                if not ok then return end
                if encoded:find("VisualEffect") or encoded:find("Particle") or encoded:find("Lightning") then return end

                local wName = ""
                local wDur  = 0
                for _, arg in ipairs(args) do
                    if type(arg) == "table" then
                        wName = arg.Name or arg.name or arg.WeatherType or arg.Type
                               or arg.id   or arg.Id  or arg.status or wName
                        wDur  = arg.Duration or arg.duration or arg.Time or arg.time or wDur
                    elseif type(arg) == "string" then
                        for _, clean in ipairs(WEATHER_WHITELIST) do
                            if arg:lower() == clean:lower() then wName = clean; break end
                        end
                    elseif type(arg) == "number" and arg > 10 then
                        wDur = arg
                    end
                end
                onWeatherChange(wName, wDur, rem.Name)
            end)
            hooked = hooked + 1
            print("[GHZ] Hooked weather:", rem.Name)
        end
    end

    print(string.format("[GHZ] Tong cong da hook %d remotes.", hooked))
    return true
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

-- ANTI-AFK
if CONFIG.ANTI_AFK then
    LocalPlayer.Idled:Connect(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end)
end

-- Countdown
task.spawn(function()
    while sg and sg.Parent do
        local t    = os.date("!*t")
        local sec  = (t.min % 5) * 60 + t.sec
        local left = math.max(300 - sec, 1)
        rowCount.Text = string.format("Restock UTC: %02d:%02d", math.floor(left/60), left%60)
        task.wait(1)
    end
end)

-- Trigger server
local function triggerServerData()
    task.spawn(function()
        pcall(function()
            local r = ReplicatedStorage:FindFirstChild("RemoteEvents")
            if not r then return end
            if r:FindFirstChild("GetShopData") then r.GetShopData:FireServer() end
            if r:FindFirstChild("OpenShop")    then r.OpenShop:FireServer()    end
            print("[GHZ] Kich hoat GetShopData")
        end)
    end)
end

-- BOOT
task.spawn(function()
    print("=== GHZ Stock Bot ===")
    print("[GHZ] Webhook: " .. (CONFIG.WEBHOOK_ENABLED and "BAT" or "tat"))
    print("[GHZ] API:     " .. (CONFIG.API_ENABLED     and "BAT" or "tat"))

    hookGameRemotes()
    hookAdminMessages()

    task.wait(2)
    triggerServerData()

    rowStatus.Text = "Status: San sang"
    print("[GHZ] Bot san sang.")
end)