--[[
    @author Zenith
    @description Grow a Garden stock bot script v2.4 - Optimization & Fast Debounce
    https://www.roblox.com/games/126884695634066
]]

if _G.ZenithStockBotV2_4 then return end
_G.ZenithStockBotV2_4 = true

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local VirtualUser = game:GetService("VirtualUser")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")
local TeleportService = game:GetService("TeleportService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer

-- Robust Request Function
local http_request = (request or http_request or (syn and syn.request) or (fluxus and fluxus.request) or (delta and delta.request))

-- Configuration
_G.Configuration = {
	["Enabled"] = true,
	["MainWebhook"] = "https://discordapp.com/api/webhooks/1486748590859878572/ojXDeoOHEamwlMXiqOTZ9yuLtACecFfmaoI4tV26ivbBFfyNdWDlsjI4cF6PmrpA64QW", -- Main (Seeds, Gear, Egg, Event)
	
    ["WeatherWebhooks"] = {
        "https://discordapp.com/api/webhooks/1486748889460506699/Kn0xlJ7fYiTuvZQ2ghbJmpn_vzawM_TN4kkyDKmajHxSl6fnTCDyrgGT9QR_SIqWwhrv",
        "URL_WEATHER_2", 
        "URL_WEATHER_3" 
    },
    
    ["CosmeticWebhooks"] = {
        "https://discordapp.com/api/webhooks/1486748995786248315/2icGcBd-eNa7JHq8tsctQ5j383ZkWM4AFFFkCmPx9BXMJPWTUKAgJQMXpoXC_4O2gSIk",
        "URL_COSMETIC_2", 
        "URL_COSMETIC_3" 
    },

	["Weather Reporting"] = true,
	["Anti-AFK"] = true,
	["Auto-Reconnect"] = true,
	["Rendering Enabled"] = true,

    -- Mapping Table
	["Mappings"] = {
		["ROOT/SeedStock/Stocks"] = "SEEDS STOCK",
		["ROOT/GearStock/Stocks"] = "GEAR STOCK",
		["ROOT/EventShopStock/Stocks"] = "EVENT STOCK",
		["ROOT/PetEggStock/Stocks"] = "EGG STOCK",
		["ROOT/CosmeticStock/ItemStocks"] = "COSMETIC ITEMS STOCK"
	}
}

-- UI Creation
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ZenithGAG_V2_4"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Parent = ScreenGui
MainFrame.BackgroundColor3 = Color3.fromRGB(12, 12, 15)
MainFrame.BorderSizePixel = 0
MainFrame.Position = UDim2.new(0.5, -160, 0.5, -110)
MainFrame.Size = UDim2.new(0, 320, 0, 220)

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 10)
UICorner.Parent = MainFrame

local UIStroke = Instance.new("UIStroke")
UIStroke.Color = Color3.fromRGB(60, 60, 80)
UIStroke.Thickness = 1.8
UIStroke.Parent = MainFrame

local Title = Instance.new("TextLabel")
Title.Name = "Title"
Title.Parent = MainFrame
Title.BackgroundTransparency = 1
Title.Position = UDim2.new(0.05, 0, 0.05, 0)
Title.Size = UDim2.new(0.9, 0, 0.15, 0)
Title.Font = Enum.Font.GothamBold
Title.Text = "ZENITH • FAST HUB v2.4"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 16
Title.TextXAlignment = Enum.TextXAlignment.Left

local TimerLabel = Instance.new("TextLabel")
TimerLabel.Name = "TimerLabel"
TimerLabel.Parent = MainFrame
TimerLabel.BackgroundTransparency = 1
TimerLabel.Position = UDim2.new(0.05, 0, 0.25, 0)
TimerLabel.Size = UDim2.new(0.9, 0, 0.6, 0)
TimerLabel.Font = Enum.Font.GothamMedium
TimerLabel.Text = "Initializing..."
TimerLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
TimerLabel.TextSize = 13
TimerLabel.RichText = true
TimerLabel.TextYAlignment = Enum.TextYAlignment.Top

-- Drag Logic
local dragging, dragStart, startPos
MainFrame.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = true dragStart = input.Position startPos = MainFrame.Position
	end
end)
MainFrame.InputChanged:Connect(function(input)
	if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
		local delta = input.Position - dragStart
		MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
end)

-- Webhook Logic
local function SafeRequest(url, body)
    if not http_request or not url or url == "" or url:find("REPLACE") or url:find("URL_") then return end
    task.spawn(function()
        pcall(function()
            http_request({
                Url = url,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = HttpService:JSONEncode(body)
            })
        end)
    end)
end

-- Debounce Buffers
local GlobalBuffer = {}
local CosmeticBuffer = {}
local DebounceActive = false

local function ProcessAndSend()
    DebounceActive = false
    
    local MainFields = {}
    for Packet, Title in _G.Configuration.Mappings do
        if Packet == "ROOT/CosmeticStock/ItemStocks" then continue end
        local Content = GlobalBuffer[Packet]
        if Content then
            local s = ""
            for k, v in Content do
                s ..= string.format("`•` %s: **x%d**\n", v.EggName or k, v.Stock)
            end
            if s ~= "" then table.insert(MainFields, { name = "⭐ " .. Title, value = s, inline = true }) end
        end
    end
    
    if #MainFields > 0 then
        SafeRequest(_G.Configuration.MainWebhook, {
            embeds = {{
                title = "🛒 GROW A GARDEN STOCK UPDATE", color = 0x38EE17,
                fields = MainFields, footer = { text = "Powered by Zenith | Ultra-Fast Report" },
                timestamp = DateTime.now():ToIsoDate()
            }}
        })
    end
    
    local CosFields = {}
    local CosContent = CosmeticBuffer["ROOT/CosmeticStock/ItemStocks"]
    if CosContent then
        local s = ""
        for k, v in CosContent do
            s ..= string.format("`•` %s: **x%d**\n", v.EggName or k, v.Stock)
        end
        if s ~= "" then
            table.insert(CosFields, { name = "💄 COSMETIC ITEMS STOCK", value = s, inline = true })
            local body = {
                embeds = {{
                    title = "✨ COSMETIC STOCK UPDATE", color = 0xFF6A2A,
                    fields = CosFields, footer = { text = "Powered by Zenith" },
                    timestamp = DateTime.now():ToIsoDate()
                }}
            }
            for _, url in _G.Configuration.CosmeticWebhooks do SafeRequest(url, body) end
        end
    end
    
    GlobalBuffer = {}
    CosmeticBuffer = {}
end

-- Timer Update
task.spawn(function()
    while task.wait(1) do
        local d = os.date("!*t", os.time())
        local sInDay = (d.hour * 3600) + (d.min * 60) + d.sec
        
        local sgRemaining = 300 - (sInDay % 300)
        local cosInterval = 4 * 3600
        local cosRemaining = cosInterval - (sInDay % cosInterval)
        
        TimerLabel.Text = string.format(
            "<font color='#00ff96'>SEED/GEAR/EGG/EVENT:</font> %02d:%02d\n" ..
            "<font color='#ff6a2a'>COSMETIC STOCK (4H):</font> %02d:%02d:%02d\n" ..
            "<font color='#7289da'>MODE:</font> ULTRA-FAST (1S Debounce)", 
            math.floor(sgRemaining / 60), sgRemaining % 60,
            math.floor(cosRemaining / 3600), math.floor((cosRemaining % 3600) / 60), cosRemaining % 60
        )
    end
end)

-- Events
DataStream.OnClientEvent:Connect(function(Type, Profile, Data)
	if Type ~= "UpdateData" or not Profile:find(LocalPlayer.Name) then return end

    for _, p in Data do
        local packName = p[1]
        local content = p[2]
        
        if _G.Configuration.Mappings[packName] then
            if packName == "ROOT/CosmeticStock/ItemStocks" then
                CosmeticBuffer[packName] = content
            else
                GlobalBuffer[packName] = content
            end
        end
    end

    if not DebounceActive then
        DebounceActive = true
        task.delay(1.0, ProcessAndSend) -- Giảm xuống 1 giây
    end
end)

WeatherEventStarted.OnClientEvent:Connect(function(Event, Length)
	if not _G.Configuration["Weather Reporting"] then return end
	local EndUnix = math.round(workspace:GetServerTimeNow()) + Length
    local body = {
		embeds = {{
			title = "🌩️ STRANGE WEATHER DETECTED", color = 0x2A6DFF,
			fields = {
				{ name = "Current Weather", value = string.format("**%s**", Event), inline = true },
				{ name = "Duration", value = string.format("Ends: <t:%d:R>", EndUnix), inline = true }
			},
			footer = { text = "Powered by Zenith" }, timestamp = DateTime.now():ToIsoDate()
		}}
	}
    for _, url in _G.Configuration.WeatherWebhooks do SafeRequest(url, body) end
end)

LocalPlayer.Idled:Connect(function()
	if _G.Configuration["Anti-AFK"] then VirtualUser:CaptureController() VirtualUser:ClickButton2(Vector2.new()) end
end)
GuiService.ErrorMessageChanged:Connect(function()
	if _G.Configuration["Auto-Reconnect"] then task.wait(5) TeleportService:Teleport(game.PlaceId, LocalPlayer) end
end)
RunService:Set3dRenderingEnabled(_G.Configuration["Rendering Enabled"])

print("Zenith Fast Hub v2.4 Loaded.")
