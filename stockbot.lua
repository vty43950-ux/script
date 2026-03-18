-------------------------------------------------------------------------------
-- 🌱 GHZ STOCK BOT v14 — WIKI ADVANCED & CLEAN REMOTE ENGINE
-- Nguồn thời tiết: gardenhorizonswiki.com/weather/
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

    -- Cooldown webhook: bao nhiêu giây tối thiểu giữa 2 lần gửi Discord
    WEBHOOK_COOLDOWN = 20,
    -- Debounce nhận stock: bỏ qua nếu nhận lại trong vòng N giây
    RESTOCK_DEBOUNCE = 10,
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
-- 🖥️ UI
-- ══════════════════════════════════════════════════════════════════════════════
local uiLayer = (gethui and gethui()) or CoreGui
if uiLayer:FindFirstChild("GHZ_Bot_UI") then uiLayer.GHZ_Bot_UI:Destroy() end

local sg = Instance.new("ScreenGui")
sg.Name = "GHZ_Bot_UI"; sg.ResetOnSpawn = false
sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling; sg.Parent = uiLayer

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 310, 0, 210); frame.Position = UDim2.new(0, 10, 0, 10)
frame.BackgroundColor3 = Color3.fromRGB(15, 18, 25); frame.BackgroundTransparency = 0.05
frame.BorderSizePixel = 0; frame.Parent = sg
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)
local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(50, 180, 255); stroke.Thickness = 1.5
stroke.Transparency = 0.35; stroke.Parent = frame

local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1,0,0,30); titleBar.BackgroundColor3 = Color3.fromRGB(18, 50, 90)
titleBar.BorderSizePixel = 0; titleBar.Parent = frame
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 10)
local titleLbl = Instance.new("TextLabel")
titleLbl.Size = UDim2.new(1,0,1,0); titleLbl.BackgroundTransparency = 1
titleLbl.Text = "🔍 GHZ Bot v14 ✦ WIKI ADVANCED"
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
local rowHook    = mkRow(178, Color3.fromRGB(150, 150, 150))

rowStatus.Text  = "Status: 🟡 Chờ nhận data..."
rowCount.Text   = "⏳ Restock: --:--"
rowSeeds.Text   = "🌿 Seeds: pending..."
rowGear.Text    = "⚙️  Gear:  pending..."
rowWeather.Text = "⛅ Weather: None"
rowTime.Text    = "🕐 Cập nhật: chưa có"
rowAPI.Text     = "📡 API: -"
rowHook.Text    = "💬 Webhook: " .. (CONFIG.WEBHOOK_ENABLED and "bật" or "tắt")

-- ══════════════════════════════════════════════════════════════════════════════
-- State
-- ══════════════════════════════════════════════════════════════════════════════
local currentWeather     = { status = "None", duration = 0 }
local lastSeeds, lastGear = {}, {}
local lastDataHash        = ""
local lastRestockTime     = 0
local lastWebhookTime     = 0

-- ══════════════════════════════════════════════════════════════════════════════
-- 📖 TỪ ĐIỂN THỜI TIẾT — lấy từ gardenhorizonswiki.com/weather/
-- ══════════════════════════════════════════════════════════════════════════════
local WEATHER_INFO = {

    -- ── Thời tiết thường ──────────────────────────────────────────────────────
    ["Sunny"] = {
        emoji = "🌞",
        color = 0xFF8800,
        desc  = "Ngày nắng bình thường, không có hiệu ứng đặc biệt.",
        muts  = "_Không có đột biến_",
        grow  = "±0% tốc độ sinh trưởng",
    },
    ["Clear"] = {
        emoji = "☀️",
        color = 0x55FF55,
        desc  = "Trời quang đãng, không có hiệu ứng đặc biệt.",
        muts  = "_Không có đột biến_",
        grow  = "±0% tốc độ sinh trưởng",
    },
    ["Cloudy"] = {
        emoji = "☁️",
        color = 0xCCCCCC,
        desc  = "Trời nhiều mây, ánh sáng yếu nhưng cây vẫn phát triển bình thường.",
        muts  = "_Không có đột biến_",
        grow  = "±0% tốc độ sinh trưởng",
    },
    ["Windy"] = {
        emoji = "💨",
        color = 0x88CCFF,
        desc  = "Gió lớn có thể mang hạt giống từ vùng đất khác tới.",
        muts  = "_Không có đột biến được xác nhận_",
        grow  = "±0% tốc độ sinh trưởng",
    },
    ["Fog"] = {
        emoji = "🌫️",
        color = 0xAAAAAA,
        desc  = "Sương mù dày đặc bao phủ toàn bản đồ. Tầm nhìn giảm mạnh.",
        muts  = "**Foggy** (×1.25) · **Chilled** (×1.5) · Combo **Mossy** (×3.5)",
        grow  = "±0% tốc độ sinh trưởng",
    },
    ["Foggy"] = {  -- alias cho Fog
        emoji = "🌫️",
        color = 0xAAAAAA,
        desc  = "Sương mù dày đặc bao phủ toàn bản đồ. Tầm nhìn giảm mạnh.",
        muts  = "**Foggy** (×1.25) · **Chilled** (×1.5) · Combo **Mossy** (×3.5)",
        grow  = "±0% tốc độ sinh trưởng",
    },
    ["Rain"] = {
        emoji = "🌧️",
        color = 0x55AAFF,
        desc  = "Mưa rơi! Cây sinh trưởng nhanh hơn đáng kể.",
        muts  = "**Soaked** ×1.25 (60%) · **Flooded** ×1.75 (40%)",
        grow  = "**+25% tốc độ sinh trưởng**",
    },
    ["Snow"] = {
        emoji = "❄️",
        color = 0xAAEEFF,
        desc  = "Tuyết rơi! Làm chậm sinh trưởng nhưng tạo đột biến hiếm.",
        muts  = "**Snowy** ×2.0 (50%) · **Chilled** ×1.5 (33%) · **Frostbit** ×3.5 (17%)\n_Frostbit yêu cầu cây đã có Soaked từ Rain_",
        grow  = "**-15% tốc độ sinh trưởng**",
    },
    ["Sandstorm"] = {
        emoji = "🏜️",
        color = 0xDDCC99,
        desc  = "Bão cát quét qua, thúc đẩy cây lớn nhanh.",
        muts  = "**Sandy** ×2.5",
        grow  = "**+20% tốc độ sinh trưởng**",
    },
    ["Storm"] = {
        emoji = "⛈️",
        color = 0xAA00FF,
        desc  = "Bão sấm sét dữ dội! Tốc độ sinh trưởng tăng mạnh, đột biến siêu hiếm.",
        muts  = "**Shocked** ×4.5 ⚡",
        grow  = "**+50% tốc độ sinh trưởng**",
    },

    -- ── Sự kiện đặc biệt ──────────────────────────────────────────────────────
    ["Starfall"] = {
        emoji = "🌠",
        color = 0xFFD700,
        desc  = "Bầu trời xanh với những ngôi sao băng! Đột biến có giá trị cao nhất trong game.",
        muts  = "**Starstruck** ×6.5 ⭐",
        grow  = "±0% tốc độ sinh trưởng",
    },
    ["Meteor"] = {
        emoji = "☄️",
        color = 0xFF4400,
        desc  = "Mưa thiên thạch rơi xuống đảo! Nguy hiểm nhưng tạo đột biến quý.",
        muts  = "**Meteoric** ×10.0 ☄️",
        grow  = "**+20% tốc độ sinh trưởng**",
    },
    ["Tsunami"] = {
        emoji = "🌊",
        color = 0x0055AA,
        desc  = "Sóng thần khổng lồ quét qua đảo — không phá hủy cây trồng.",
        muts  = "**Tidal** ×2.0 (2.5% mỗi cây khi sóng qua)",
        grow  = "±0% tốc độ sinh trưởng",
    },
    ["Heavy Rain"] = {
        emoji = "🌧️⚠️",
        color = 0x880000,
        desc  = "Mưa lớn bất thường — xuất hiện boss Cthulhu! Tiêu diệt để nhận hạt Lumenbark.",
        muts  = "**Ancient** ×7.5",
        grow  = "**+50% tốc độ sinh trưởng**",
    },
    ["Acid Rain"] = {
        emoji = "🧪",
        color = 0x88FF00,
        desc  = "Mưa Axit độc hại! Kích thích đột biến cực lạ cho cây trồng.",
        muts  = "_Đột biến đặc biệt (Admin event)_",
        grow  = "±0% tốc độ sinh trưởng",
    },
    ["Mowis"] = {
        emoji = "🌀",
        color = 0x2200FF,
        desc  = "Bão Mowis — biến thể cực mạnh của Storm!",
        muts  = "_Tương tự Storm_",
        grow  = "**+50% tốc độ sinh trưởng**",
    },

    -- ── Admin-only events ──────────────────────────────────────────────────────
    ["DJ Kine"] = {
        emoji = "🎵",
        color = 0xFF00FF,
        desc  = "Bữa tiệc âm nhạc sôi động của DJ Kine! Tốc độ sinh trưởng x2.",
        muts  = "**Party** ×11.5 🎉",
        grow  = "**+100% tốc độ sinh trưởng**",
    },
    ["Beam Clash"] = {
        emoji = "⚡🌈",
        color = 0xFF6688,
        desc  = "Các tia sáng va chạm trên bầu trời, hiện tượng vũ trụ kỳ lạ.",
        muts  = "**Salad** ×10.0 · **Banned** ×10.0",
        grow  = "±0% tốc độ sinh trưởng",
    },
    ["Black Hole"] = {
        emoji = "🕳️",
        color = 0x111111,
        desc  = "Hố đen vũ trụ xuất hiện — sự cố thiên văn cực hiếm.",
        muts  = "**Nova** ×6.5 · **Galactic** (TBA)",
        grow  = "TBA",
    },
    ["Manny's Mishap"] = {
        emoji = "🍎",
        color = 0xFF4488,
        desc  = "Sự kiện thu thập trái cây rơi vãi để lấy điểm thưởng (mỗi giờ 1 lần).",
        muts  = "_Không có đột biến_",
        grow  = "**+100% tốc độ sinh trưởng**",
    },
    ["Lucky Block Seed Rain"] = {
        emoji = "🟨",
        color = 0xFFD700,
        desc  = "Các khối may mắn rơi từ trên trời chứa hạt giống bên trong.",
        muts  = "_Không có đột biến_",
        grow  = "±0% tốc độ sinh trưởng",
    },
    ["Strange Weather"] = {
        emoji = "🔮",
        color = 0x886699,
        desc  = "Thời tiết kỳ lạ xuất hiện sau khi tiêu diệt boss hoặc qua sự kiện admin.",
        muts  = "**Strange** ×2.0",
        grow  = "±0% tốc độ sinh trưởng",
    },
}

-- Fallback cho thời tiết chưa được map
local WEATHER_FALLBACK = {
    emoji = "🌡️",
    color = 0x888888,
    desc  = "Sự kiện thời tiết đặc biệt chưa được xác nhận.",
    muts  = "_Chưa có thông tin_",
    grow  = "Không rõ",
}

-- Danh sách tên thời tiết hợp lệ (để kiểm tra khi nhận event)
local WEATHER_WHITELIST = {
    "Clear", "Sunny", "Cloudy", "Windy",
    "Fog", "Foggy", "Rain", "Snow", "Sandstorm", "Storm",
    "Starfall", "Meteor", "Tsunami", "Heavy Rain", "Acid Rain", "Mowis",
    "DJ Kine", "Beam Clash", "Black Hole", "Manny's Mishap",
    "Lucky Block Seed Rain", "Strange Weather",
}

-- ══════════════════════════════════════════════════════════════════════════════
-- 📬 GỬI DISCORD EMBED ĐẸP
-- ══════════════════════════════════════════════════════════════════════════════
local function buildSeedStr(seeds)
    if #seeds == 0 then return "_Đã hết hạt giống._" end
    local lines = {}
    for _, v in ipairs(seeds) do
        table.insert(lines, string.format("**%s** — `×%d`", v.name, v.quantity))
    end
    return table.concat(lines, "\n")
end

local function buildGearStr(gear)
    if #gear == 0 then return "_Đã hết công cụ._" end
    local lines = {}
    for _, v in ipairs(gear) do
        table.insert(lines, string.format("**%s** — `×%d`", v.name, v.quantity))
    end
    return table.concat(lines, "\n")
end

local function canSendWebhook()
    return tick() - lastWebhookTime >= CONFIG.WEBHOOK_COOLDOWN
end

local function sendWebhook(seeds, gear, weather, isWeatherOnly)
    if not CONFIG.WEBHOOK_ENABLED then return false end
    if not req then return false end
    if CONFIG.WEBHOOK_URL:find("PASTE") then return false end

    if not canSendWebhook() then
        print("[GHZ Bot] 🔕 Webhook cooldown, bỏ qua. Còn " .. math.ceil(CONFIG.WEBHOOK_COOLDOWN - (tick() - lastWebhookTime)) .. "s")
        return false
    end

    local wStatus   = (weather and weather.status) or "Clear"
    local wDuration = (weather and weather.duration) or 0
    local wInfo     = WEATHER_INFO[wStatus] or WEATHER_FALLBACK

    local fields
    if isWeatherOnly then
        -- Weather-only: embed gọn
        fields = {{
            ["name"]   = wInfo.emoji .. " Thời tiết thay đổi: **" .. wStatus .. "**",
            ["value"]  = wInfo.desc
                .. "\n\n🌱 **Đột biến:** " .. wInfo.muts
                .. "\n📈 **Sinh trưởng:** " .. wInfo.grow
                .. "\n⏳ **Thời gian còn lại:** " .. (wDuration > 0 and (wDuration .. " giây") or "~5 phút"),
            ["inline"] = false
        }}
    else
        -- Full stock + weather embed
        local sStr = buildSeedStr(seeds)
        local gStr = buildGearStr(gear)
        fields = {
            {
                ["name"]   = wInfo.emoji .. " Thời tiết: **" .. wStatus .. "**",
                ["value"]  = wInfo.desc
                    .. "\n🌱 **Đột biến:** " .. wInfo.muts
                    .. "\n📈 **Sinh trưởng:** " .. wInfo.grow
                    .. "\n⏳ **Còn lại:** " .. (wDuration > 0 and (wDuration .. "s") or "~5 phút"),
                ["inline"] = false
            },
            {
                ["name"]   = "🌿 Hạt Giống (" .. #seeds .. " loại)",
                ["value"]  = sStr:sub(1, 1024),
                ["inline"] = true
            },
            {
                ["name"]   = "🛠️ Công Cụ (" .. #gear .. " loại)",
                ["value"]  = gStr:sub(1, 1024),
                ["inline"] = true
            }
        }
    end

    local title, description
    if isWeatherOnly then
        title       = wInfo.emoji .. "  THỜI TIẾT MỚI — " .. wStatus:upper()
        description = "Thời tiết vừa thay đổi trong **Garden Horizons**!"
    else
        title       = "🌍 GARDEN HORIZONS — CẬP NHẬT THỊ TRƯỜNG"
        description = "Hàng mới vừa được nhập kho! Thời tiết hiện tại: **" .. wInfo.emoji .. " " .. wStatus .. "**"
    end

    local payload = {
        ["username"]   = "Garden Horizons BOT",
        ["avatar_url"] = "https://cdn-icons-png.flaticon.com/512/3234/3234972.png",
        ["embeds"]     = {{
            ["title"]       = title,
            ["description"] = description,
            ["color"]       = wInfo.color,
            ["fields"]      = fields,
            ["footer"] = {
                ["text"]     = "Zenith GHZ • v14 Wiki Engine · gardenhorizonswiki.com/weather",
                ["icon_url"] = "https://cdn-icons-png.flaticon.com/512/3234/3234972.png"
            },
            ["timestamp"] = os.date("!%Y-%m-%dT%H:%M:%SZ")
        }}
    }

    lastWebhookTime = tick()
    pcall(function()
        task.spawn(function()
            local ok, err = pcall(function()
                req({
                    Url     = CONFIG.WEBHOOK_URL,
                    Method  = "POST",
                    Headers = { ["Content-Type"] = "application/json" },
                    Body    = HttpService:JSONEncode(payload)
                })
            end)
            if ok then
                print("[GHZ Bot] ✅ Discord gửi OK — " .. (isWeatherOnly and "weather" or "stock+weather"))
                rowHook.Text = "💬 Webhook: ✅ " .. os.date("%H:%M:%S")
            else
                print("[GHZ Bot] ❌ Discord lỗi:", err)
                rowHook.Text = "💬 Webhook: ❌ Lỗi"
            end
        end)
    end)
    return true
end

-- ══════════════════════════════════════════════════════════════════════════════
-- 📡 GỬI API
-- ══════════════════════════════════════════════════════════════════════════════
local function postAPI(seeds, gear, weather)
    if not CONFIG.API_ENABLED or not req then return false end
    local ok, err = pcall(function()
        req({
            Url     = CONFIG.API_URL,
            Method  = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body    = HttpService:JSONEncode({
                seeds     = seeds   or {},
                gear      = gear    or {},
                weather   = weather or { status = "None", duration = 0 },
                timestamp = os.time()
            })
        })
    end)
    if ok then
        rowAPI.Text = "📡 API: ✅ " .. os.date("%H:%M:%S")
        print("[GHZ Bot] 📡 API OK — " .. #seeds .. " seeds, " .. #gear .. " gear, weather=" .. (weather and weather.status or "None"))
    else
        rowAPI.Text = "📡 API: ❌ Lỗi"
        print("[GHZ Bot] ❌ API lỗi:", tostring(err))
    end
    return ok
end

local function postAdminMessage(msg)
    if not CONFIG.API_ENABLED or not req or not CONFIG.NOTIFY_URL then return false end
    pcall(function()
        task.spawn(function()
            req({
                Url     = CONFIG.NOTIFY_URL,
                Method  = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body    = HttpService:JSONEncode({ message = msg, timestamp = os.time() })
            })
            if CONFIG.WEBHOOK_ENABLED and not CONFIG.WEBHOOK_URL:find("PASTE") then
                req({
                    Url     = CONFIG.WEBHOOK_URL,
                    Method  = "POST",
                    Headers = { ["Content-Type"] = "application/json" },
                    Body    = HttpService:JSONEncode({
                        username = "⚠️ Admin Alert",
                        content  = "@everyone **[ADMIN]:** `" .. msg .. "`"
                    })
                })
            end
        end)
    end)
end

-- ══════════════════════════════════════════════════════════════════════════════
-- 🧠 XỬ LÝ STOCK MỚI
-- ══════════════════════════════════════════════════════════════════════════════
local function onRestockData(seeds, gear, source)
    if #seeds == 0 and #gear == 0 then return end

    if tick() - lastRestockTime < CONFIG.RESTOCK_DEBOUNCE then
        print("[GHZ Bot] ⏳ Debounce stock: bỏ qua.")
        return
    end

    local hash = HttpService:JSONEncode({ seeds = seeds, gear = gear })
    if hash == lastDataHash then
        print("[GHZ Bot] 🚫 Stock trùng lặp, bỏ qua.")
        return
    end

    lastDataHash    = hash
    lastRestockTime = tick()
    lastSeeds       = seeds
    lastGear        = gear

    rowStatus.Text = "Status: ✅ Stock mới!"
    rowSeeds.Text  = "🌿 Seeds: " .. #seeds .. " loại"
    rowGear.Text   = "⚙️  Gear: " .. #gear .. " loại"
    rowTime.Text   = "🕐 " .. os.date("%H:%M:%S")

    task.spawn(function()
        postAPI(seeds, gear, currentWeather)
        sendWebhook(seeds, gear, currentWeather, false)
    end)

    print(string.format("[GHZ Bot] ✨ Stock mới từ [%s]: %d seeds, %d gear | weather=%s",
        source, #seeds, #gear, currentWeather.status))
end

-- ══════════════════════════════════════════════════════════════════════════════
-- 🌦️ XỬ LÝ WEATHER THAY ĐỔI
-- ══════════════════════════════════════════════════════════════════════════════
local function onWeatherChange(wName, wDuration, source)
    -- ❌ KHÔNG xử lý nếu tên rỗng, Unknown, None hoặc duration = 0 (weather hết)
    -- Điều này fix lỗi spam 3 cái khi thời tiết kết thúc
    if not wName or wName == "" or wName == "Unknown" or wName == "None" then
        print("[GHZ Bot] ⏭ Weather hết / không hợp lệ → bỏ qua, không gửi.")
        return
    end

    -- Thêm kiểm tra duration: nếu duration = 0 THÌ chỉ reset state, KHÔNG gửi
    -- (vì đây là signal "weather vừa kết thúc", không phải weather mới)
    if wDuration == 0 and wName == currentWeather.status then
        print("[GHZ Bot] ⏭ Weather " .. wName .. " hết thời gian → reset state, không gửi.")
        currentWeather.status   = "None"
        currentWeather.duration = 0
        rowWeather.Text = "⛅ Weather: hết / chờ mới"
        return
    end

    -- Nếu thời tiết không đổi → bỏ qua
    if wName == currentWeather.status then return end

    -- Cập nhật state
    currentWeather.status   = wName
    currentWeather.duration = wDuration
    rowWeather.Text = "⛅ " .. wName .. (wDuration > 0 and (" (" .. wDuration .. "s)") or "")

    print(string.format("[GHZ Bot] ⛅ Weather mới: %s (%ds) | nguồn: %s", wName, wDuration, source))

    task.spawn(function()
        -- Gửi API cập nhật weather (kèm stock hiện tại)
        postAPI(lastSeeds, lastGear, currentWeather)
        -- Gửi Discord embed kiểu weather-only (KHÔNG gửi lại list stock)
        sendWebhook(lastSeeds, lastGear, currentWeather, true)
    end)
end

-- ══════════════════════════════════════════════════════════════════════════════
-- PARSER
-- ══════════════════════════════════════════════════════════════════════════════
local SEED_SHOPS = { "seed", "seedshop", "seeds" }
local GEAR_SHOPS = { "gear", "gearshop", "gears", "tool", "toolshop" }

local function getCat(text)
    local n = tostring(text):lower():gsub("%s+", "")
    for _, k in ipairs(SEED_SHOPS) do if n:find(k) then return "seed" end end
    for _, k in ipairs(GEAR_SHOPS) do if n:find(k) then return "gear" end end
end

local function parseRemoteTable(dataTable)
    local seeds, gear = {}, {}
    local tracked = {}

    local function search(t, depth)
        if depth > 10 then return end
        for k, v in pairs(t) do
            local cat = type(k) == "string" and getCat(k) or nil
            if cat and type(v) == "table" then
                local items = v.Items or v.items or v
                if type(items) == "table" then
                    for itemName, itemData in pairs(items) do
                        if type(itemName) == "string" then
                            local amt
                            if type(itemData) == "table" then
                                amt = itemData.Amount or itemData.amount or itemData.Stock or itemData.stock
                            elseif type(itemData) == "number" then
                                amt = itemData
                            end
                            if amt and type(amt) == "number" then
                                if not CONFIG.SKIP_EMPTY or amt > 0 then
                                    if not tracked[itemName] then
                                        tracked[itemName] = true
                                        local e = { name = itemName, quantity = amt, category = cat }
                                        if cat == "seed" then table.insert(seeds, e) else table.insert(gear, e) end
                                    end
                                end
                            end
                        end
                    end
                end
            end
            if type(v) == "table" then
                local eName = v.Name or v.name or v.Item or v.item
                local eAmt  = v.Amount or v.amount or v.Stock or v.stock or v.Quantity or v.quantity
                if eName and eAmt and type(eName) == "string" and type(eAmt) == "number" then
                    local realCat = getCat(eName) or "seed"
                    if not tracked[eName] then
                        tracked[eName] = true
                        local e = { name = eName, quantity = eAmt, category = realCat }
                        if realCat == "seed" then table.insert(seeds, e) else table.insert(gear, e) end
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
-- 🎯 HOOK GAME REMOTES
-- ══════════════════════════════════════════════════════════════════════════════
local function hookGameRemotes()
    local remotes = ReplicatedStorage:WaitForChild("RemoteEvents", 10)
    if not remotes then
        print("[GHZ Bot] ❌ Không tìm thấy RemoteEvents!")
        return false
    end

    -- 1. STOCK (ShopRestocked / Replica)
    for _, rem in pairs(remotes:GetChildren()) do
        if rem:IsA("RemoteEvent") then
            if rem.Name == "ShopRestocked" or rem.Name:find("Replica") then
                rem.OnClientEvent:Connect(function(...)
                    local args = { ... }
                    local ok, strArgs = pcall(function() return HttpService:JSONEncode(args) end)
                    if not ok then return end
                    if strArgs:find("Amount") and (strArgs:find("SeedShop") or strArgs:find("GearShop") or strArgs:find("Items")) then
                        print("[GHZ Bot] 🎯 Stock event từ [" .. rem.Name .. "]")
                        for _, arg in ipairs(args) do
                            local s, g = parseRemoteTable(arg)
                            if #s > 0 or #g > 0 then
                                onRestockData(s, g, rem.Name)
                                break
                            end
                        end
                    end
                end)
            end
        end
    end

    -- 2. WEATHER — chỉ cập nhật state + gửi weather embed, KHÔNG gửi stock lại
    for _, rem in pairs(remotes:GetChildren()) do
        if rem:IsA("RemoteEvent") and string.lower(rem.Name):find("weather") then
            rem.OnClientEvent:Connect(function(...)
                local args = { ... }
                local ok, strArgs = pcall(function() return HttpService:JSONEncode(args) end)
                if not ok then return end

                -- Bỏ qua visual effects
                if strArgs:find("VisualEffect") or strArgs:find("Particle") or strArgs:find("Lightning") then return end

                local wName = ""
                local wDur  = 0

                for _, arg in ipairs(args) do
                    if type(arg) == "table" then
                        wName = arg.Name or arg.name or arg.WeatherType or arg.Type
                               or arg.id   or arg.Id  or arg.status or wName
                        wDur  = arg.Duration or arg.duration or arg.Time or arg.time or wDur
                    elseif type(arg) == "string" then
                        for _, clean in ipairs(WEATHER_WHITELIST) do
                            if string.lower(arg) == string.lower(clean) then
                                wName = clean; break
                            end
                        end
                    elseif type(arg) == "number" and arg > 10 then
                        wDur = arg
                    end
                end

                onWeatherChange(wName, wDur, rem.Name)
            end)
        end
    end

    print("[GHZ Bot] ✅ Đã hook remotes (" .. #remotes:GetChildren() .. " items)")
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
                if type(m) == "table" and m.Message
                and (m.MessageType == "System" or m.Message:match("^%[Admin%]")) then
                    postAdminMessage(m.Message)
                end
            end)
        end
    end)
end

-- 🛡️ ANTI-AFK
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
        rowCount.Text = string.format("⏳ Restock UTC: %02d:%02d", math.floor(left / 60), left % 60)
        task.wait(1)
    end
end)

-- Trigger server
local function triggerServerData()
    task.spawn(function()
        pcall(function()
            local r = ReplicatedStorage:FindFirstChild("RemoteEvents")
            if r then
                if r:FindFirstChild("GetShopData") then r.GetShopData:FireServer() end
                if r:FindFirstChild("OpenShop")    then r.OpenShop:FireServer()    end
                print("[GHZ Bot] ⚡ Đã kích hoạt GetShopData")
            end
        end)
    end)
end

-- 🚀 KHỞI ĐỘNG
task.spawn(function()
    print("=" .. string.rep("=", 50))
    print("[GHZ Bot] 🚀 Khởi động v14 WIKI ADVANCED")
    print("[GHZ Bot] 📋 Webhook: " .. (CONFIG.WEBHOOK_ENABLED and "BẬT" or "tắt"))
    print("[GHZ Bot] 📡 API:     " .. (CONFIG.API_ENABLED     and "BẬT" or "tắt"))

    hookGameRemotes()
    hookAdminMessages()

    rowStatus.Text = "Status: ⚡ Đang gọi Server nhả data..."
    task.wait(2)
    triggerServerData()

    rowStatus.Text = "Status: 🟢 Bot đã sẵn sàng"
    print("[GHZ Bot] ✅ Bot sẵn sàng — Remote Engine Only.")
end)
