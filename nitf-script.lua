--[[
    @author Zenith API
    @description 99 Night In The Forest - Class Shop Tracker
    Game: https://www.roblox.com/games/99-night-in-the-forest

    • Gửi stock hiện tại NGAY KHI chạy script
    • Tự động ghi nhận Class Shop khi game cập nhật (mỗi ~24h)
    • Gửi embed đẹp lên Discord Webhook
    • POST dữ liệu lên Zenith API để web sync thời gian thực
]]

_G.NightConfiguration = {
    ["Enabled"] = true,
    ["Webhook"] = "https://discord.com/api/webhooks/YOUR_WEBHOOK_URL_HERE", -- THAY BẰNG WEBHOOK CỦA BẠN
    ["API_Url"] = "https://zenithghz.qzz.io/api/99night",
    ["Anti-AFK"] = true,
    ["Auto-Reconnect"] = true,
    ["Rendering Enabled"] = true,
    ["EmbedColor"] = Color3.fromRGB(100, 60, 220), -- Tím đậm chủ đề Night
}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local VirtualUser = cloneref(game:GetService("VirtualUser"))
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local TeleportService = game:GetService("TeleportService")

local LocalPlayer = Players.LocalPlayer
local PlaceId = game.PlaceId
local JobId = game.JobId

if _G.NightBot then return end
_G.NightBot = true

RunService:Set3dRenderingEnabled(_G.NightConfiguration["Rendering Enabled"])

local req = (request or syn and syn.request or http and http.request)

local function ConvertColor3(Color)
    return math.floor(Color.R * 255) * 65536 + math.floor(Color.G * 255) * 256 + math.floor(Color.B * 255)
end

local function SendToAPI(payload)
    if not _G.NightConfiguration["API_Url"] or not req then return end
    task.spawn(function()
        pcall(function()
            req({
                Url = _G.NightConfiguration["API_Url"],
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = HttpService:JSONEncode(payload)
            })
        end)
    end)
end

local function SendWebhook(classes, isInitial)
    if not _G.NightConfiguration["Enabled"] or not req then return end
    if not _G.NightConfiguration["Webhook"] or _G.NightConfiguration["Webhook"] == "" then return end

    local fields = {}

    if classes and #classes > 0 then
        local classStr = ""
        for _, cls in ipairs(classes) do
            local name = cls.name or "Unknown"
            local cost = cls.cost and `💎 {cls.cost}` or ""
            local extra = cls.description and `\n> _{cls.description}_` or ""
            classStr ..= `**{name}** {cost}{extra}\n`
        end
        table.insert(fields, {
            name = "🧙 Classes Available",
            value = classStr ~= "" and classStr or "_(Empty)_",
            inline = false
        })
    else
        table.insert(fields, {
            name = "⚠️ Shop Status",
            value = "No classes found in current rotation.",
            inline = false
        })
    end

    -- Footer khác giữa initial và update
    local titleText = isInitial
        and "🌙 99 Night In The Forest — Current Class Shop"
        or "🌙 99 Night In The Forest — Class Shop Updated"
    local descText = isInitial
        and "Stock hiện tại khi script khởi động."
        or "The Class Shop has refreshed! New rotation is now live."

    local Body = {
        embeds = {{
            title = titleText,
            description = descText,
            color = ConvertColor3(_G.NightConfiguration["EmbedColor"]),
            fields = fields,
            footer = { text = "Zenith API • 99 Night In The Forest Tracker" },
            timestamp = DateTime.now():ToIsoDate()
        }}
    }

    task.spawn(function()
        pcall(function()
            req({
                Url = _G.NightConfiguration["Webhook"],
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = HttpService:JSONEncode(Body)
            })
        end)
    end)
end

-- Hàm đọc Shop folder trực tiếp (lấy stock hiện tại không cần event)
local function ReadShopFolderDirectly(shopFolder)
    local classes = {}
    for _, child in ipairs(shopFolder:GetChildren()) do
        if child:IsA("Folder") or child:IsA("Model") or child:IsA("Configuration") then
            local entry = { name = child.Name }
            local ok, attrs = pcall(function() return child:GetAttributes() end)
            if ok and attrs then
                for k, v in pairs(attrs) do
                    entry[k:lower()] = v
                end
            end
            local costVal = child:FindFirstChild("Cost") or child:FindFirstChild("Price")
            if costVal and costVal.Value then
                entry.cost = costVal.Value
            end
            local descVal = child:FindFirstChild("Description")
            if descVal and descVal.Value then
                entry.description = descVal.Value
            end
            table.insert(classes, entry)
        end
    end
    return classes
end

local function ProcessClassShopUpdate(shopData, isInitial)
    local classes = {}

    if typeof(shopData) == "Instance" then
        classes = ReadShopFolderDirectly(shopData)
    elseif typeof(shopData) == "table" then
        for name, data in pairs(shopData) do
            local entry = { name = typeof(data) == "table" and (data.Name or name) or tostring(name) }
            if typeof(data) == "table" then
                if data.Cost then entry.cost = data.Cost end
                if data.Price then entry.cost = data.Price end
                if data.Description then entry.description = data.Description end
            end
            table.insert(classes, entry)
        end
    end

    SendWebhook(classes, isInitial)
    SendToAPI({ classes = classes })

    local tag = isInitial and "[99Night][Initial]" or "[99Night][Update]"
    print(`{tag} Class Shop synced! {#classes} class(es) found.`)
end

-- ────────────────────────────────────────────────
-- Gửi stock NGAY KHI chạy script (Initial Send)
-- ────────────────────────────────────────────────
local shopFolder = ReplicatedStorage:FindFirstChild("Shop")
if shopFolder then
    -- Gửi stock hiện tại ngay lập tức
    print("[99Night] Sending current class shop on startup...")
    task.defer(function()
        ProcessClassShopUpdate(shopFolder, true)
    end)

    -- Lắng nghe update tiếp theo (mỗi 24h)
    local classShopUpdated = shopFolder:FindFirstChild("ClassShopUpdated")
    if classShopUpdated then
        classShopUpdated.OnClientEvent:Connect(function(shopData)
            ProcessClassShopUpdate(shopData or shopFolder, false)
        end)
        print("[99Night] Listening for ClassShopUpdated event (24h rotation)...")
    else
        warn("[99Night] ClassShopUpdated RemoteEvent not found — reading folder directly only.")
    end
else
    warn("[99Night] Shop folder not found in ReplicatedStorage!")
end

-- Anti-AFK
LocalPlayer.Idled:Connect(function()
    if _G.NightConfiguration["Anti-AFK"] then
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end
end)

-- Auto-Reconnect
GuiService.ErrorMessageChanged:Connect(function()
    if not _G.NightConfiguration["Auto-Reconnect"] then return end
    if #Players:GetPlayers() <= 1 then
        TeleportService:Teleport(PlaceId, LocalPlayer)
    else
        TeleportService:TeleportToPlaceInstance(PlaceId, JobId, LocalPlayer)
    end
end)

print("[99Night] 99 Night In The Forest — Class Shop Tracker Started!")
