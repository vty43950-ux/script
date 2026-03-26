--[[
    @author Zenith
    @description Grow a Garden stock bot script v2.8 - ULTIMATE UI & LOGS
    https://www.roblox.com/games/126884695634066
]]

_G.ZenithActive = true 

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local VirtualUser = game:GetService("VirtualUser")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer

-- Robust Request Function
local http_request = (request or http_request or (syn and syn.request) or (fluxus and fluxus.request) or (delta and delta.request))

-- Configuration
_G.Configuration = {
	["Enabled"] = true,
	["MainWebhook"] = "https://discordapp.com/api/webhooks/1486748590859878572/ojXDeoOHEamwlMXiqOTZ9yuLtACecFfmaoI4tV26ivbBFfyNdWDlsjI4cF6PmrpA64QW",
	
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
    ["CosmeticOffset"] = -3600, 

    -- Mapping Table (Added some fuzzy variants)
	["Mappings"] = {
		["ROOT/SeedStock/Stocks"] = "SEEDS STOCK",
		["ROOT/GearStock/Stocks"] = "GEAR STOCK",
		["ROOT/EventShopStock/Stocks"] = "EVENT STOCK",
		["ROOT/PetEggStock/Stocks"] = "EGG STOCK",
        ["ROOT/EventShop/Stocks"] = "EVENT STOCK", -- Backup
		["ROOT/CosmeticStock/ItemStocks"] = "COSMETIC ITEMS STOCK"
	}
}

-- UI Creation
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ZenithGAG_V2_8"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Parent = ScreenGui
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
MainFrame.BorderSizePixel = 0
MainFrame.Position = UDim2.new(0.5, -160, 0.5, -125)
MainFrame.Size = UDim2.new(0, 320, 0, 250)

Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 8)
local Stroke = Instance.new("UIStroke", MainFrame)
Stroke.Color = Color3.fromRGB(60, 60, 80)
Stroke.Thickness = 2

-- Tab Container
local TabFrame = Instance.new("Frame", MainFrame)
TabFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
TabFrame.Size = UDim2.new(1, 0, 0, 35)
TabFrame.BorderSizePixel = 0
Instance.new("UICorner", TabFrame).CornerRadius = UDim.new(0, 8)

local Tab1 = Instance.new("TextButton", TabFrame)
Tab1.Name = "TimersTab"
Tab1.Size = UDim2.new(0.5, 0, 1, 0)
Tab1.BackgroundTransparency = 1
Tab1.Font = Enum.Font.GothamBold
Tab1.Text = "⏳ TIMERS"
Tab1.TextColor3 = Color3.fromRGB(255, 255, 255)
Tab1.TextSize = 13

local Tab2 = Instance.new("TextButton", TabFrame)
Tab2.Name = "LogsTab"
Tab2.Size = UDim2.new(0.5, 0, 1, 0)
Tab2.Position = UDim2.new(0.5, 0, 0, 0)
Tab2.BackgroundTransparency = 1
Tab2.Font = Enum.Font.GothamBold
Tab2.Text = "📜 LOGS"
Tab2.TextColor3 = Color3.fromRGB(150, 150, 150)
Tab2.TextSize = 13

-- Content Areas
local ContentFrame = Instance.new("Frame", MainFrame)
ContentFrame.Position = UDim2.new(0, 0, 0, 40)
ContentFrame.Size = UDim2.new(1, 0, 1, -40)
ContentFrame.BackgroundTransparency = 1

local TimerArea = Instance.new("Frame", ContentFrame)
TimerArea.Size = UDim2.new(1, 0, 1, 0)
TimerArea.BackgroundTransparency = 1

local LogArea = Instance.new("ScrollingFrame", ContentFrame)
LogArea.Size = UDim2.new(1, -20, 1, -10)
LogArea.Position = UDim2.new(0, 10, 0, 5)
LogArea.BackgroundTransparency = 1
LogArea.ScrollBarThickness = 2
LogArea.Visible = false
local LogList = Instance.new("UIListLayout", LogArea)
LogList.Padding = UDim.new(0, 5)

local TimerLabel = Instance.new("TextLabel", TimerArea)
TimerLabel.BackgroundTransparency = 1
TimerLabel.Position = UDim2.new(0.05, 0, 0.1, 0)
TimerLabel.Size = UDim2.new(0.9, 0, 0.8, 0)
TimerLabel.Font = Enum.Font.GothamMedium
TimerLabel.Text = "Waiting for data..."
TimerLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
TimerLabel.TextSize = 14
TimerLabel.RichText = true
TimerLabel.TextYAlignment = Enum.TextYAlignment.Top

-- Log System
local function AddLog(msg, color)
    local l = Instance.new("TextLabel", LogArea)
    l.Size = UDim2.new(1, 0, 0, 20)
    l.BackgroundTransparency = 1
    l.Font = Enum.Font.Gotham
    l.Text = string.format("[%s] %s", os.date("%X"), msg)
    l.TextColor3 = color or Color3.fromRGB(200, 200, 200)
    l.TextSize = 12
    l.TextXAlignment = Enum.TextXAlignment.Left
    LogArea.CanvasSize = UDim2.new(0, 0, 0, LogList.AbsoluteContentSize.Y + 20)
    if #LogArea:GetChildren() > 30 then LogArea:GetChildren()[2]:Destroy() end -- Limit logs
end

-- Tab Switch Logic
Tab1.MouseButton1Click:Connect(function()
    TimerArea.Visible = true LogArea.Visible = false
    Tab1.TextColor3 = Color3.fromRGB(255, 255, 255)
    Tab2.TextColor3 = Color3.fromRGB(150, 150, 150)
end)
Tab2.MouseButton1Click:Connect(function()
    TimerArea.Visible = false LogArea.Visible = true
    Tab1.TextColor3 = Color3.fromRGB(150, 150, 150)
    Tab2.TextColor3 = Color3.fromRGB(255, 255, 255)
end)

-- Drag Logic
local dragging, dragStart, startPos
MainFrame.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = true dragStart = input.Position startPos = MainFrame.Position
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
end)
RunService.RenderStepped:Connect(function()
	if dragging then
		local delta = UserInputService:GetMouseLocation() - Vector2.new(dragStart.X, dragStart.Y)
		MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + (UserInputService:GetMouseLocation().X - dragStart.X), startPos.Y.Scale, startPos.Y.Offset + (UserInputService:GetMouseLocation().Y - dragStart.Y))
	end
end)

-- Webhook Logic
local function SafeRequest(url, body, typeName)
    if not http_request or not url or url == "" or url:find("REPLACE") or url:find("URL_") then return end
    task.spawn(function()
        local s, err = pcall(function()
            http_request({
                Url = url,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = HttpService:JSONEncode(body)
            })
        end)
        if s then AddLog("Sent Webhook: " .. typeName, Color3.fromRGB(100, 255, 100))
        else AddLog("Webhook Error: " .. tostring(err), Color3.fromRGB(255, 100, 100)) end
    end)
end

-- Storage
local GlobalBuffer = {}
local CosmeticBuffer = {}
local DebounceActive = false

local function ProcessAndSend()
    local success, err = pcall(function()
        local MainFields = {}
        local order = {
            "ROOT/SeedStock/Stocks", 
            "ROOT/GearStock/Stocks", 
            "ROOT/PetEggStock/Stocks", 
            "ROOT/EventShopStock/Stocks",
            "ROOT/EventShop/Stocks"
        }

        local foundAny = false
        for _, Packet in order do
            local Content = GlobalBuffer[Packet]
            local TitleText = _G.Configuration.Mappings[Packet]
            if Content then
                local s = ""
                for k, v in Content do
                    s ..= string.format("`•` %s: **x%d**\n", v.EggName or k, v.Stock)
                end
                if s ~= "" then 
                    table.insert(MainFields, { name = "⭐ " .. TitleText, value = s, inline = true }) 
                    foundAny = true
                end
            end
        end
        
        if foundAny then
            SafeRequest(_G.Configuration.MainWebhook, {
                embeds = {{
                    title = "🛒 ZENITH GLOBAL UPDATER", color = 0x38EE17,
                    fields = MainFields, footer = { text = "Powered by Zenith • v2.8 Logs" },
                    timestamp = DateTime.now():ToIsoDate()
                }}
            }, "Global Stock")
        end
        
        local CosContent = CosmeticBuffer["ROOT/CosmeticStock/ItemStocks"]
        if CosContent then
            local s = ""
            for k, v in CosContent do
                s ..= string.format("`•` %s: **x%d**\n", v.EggName or k, v.Stock)
            end
            if s ~= "" then
                SafeRequest(_G.Configuration.CosmeticWebhooks[1], {
                    embeds = {{
                        title = "✨ ZENITH COSMETIC", color = 0xFF6A2A,
                        fields = {{ name = "COSMETIC ITEMS STOCK", value = s, inline = true }},
                        footer = { text = "Powered by Zenith" },
                        timestamp = DateTime.now():ToIsoDate()
                    }}
                }, "Cosmetic")
            end
        end
    end)
    
    GlobalBuffer = {}
    CosmeticBuffer = {}
    DebounceActive = false
    AddLog("Buffer cleared after send.", Color3.fromRGB(150, 150, 150))
end

-- Timer Loop
task.spawn(function()
    while task.wait(1) do
        local now = os.time()
        local baseTime = now + (_G.Configuration.CosmeticOffset or 0)
        local d = os.date("!*t", baseTime)
        local sInDay = (d.hour * 3600) + (d.min * 60) + d.sec
        local sgRemaining = 300 - (sInDay % 300)
        local cosRemaining = 14400 - (sInDay % 14400)
        
        TimerLabel.Text = string.format(
            "<font color='#00ff96'>GLOBAL STOCK:</font> %02d:%02d\n" ..
            "<font color='#ff6a2a'>COSMETIC STOCK:</font> %02d:%02d:%02d\n\n" ..
            "<font color='#888888'>Script Status: Running</font>", 
            math.floor(sgRemaining / 60), sgRemaining % 60,
            math.floor(cosRemaining / 3600), math.floor((cosRemaining % 3600) / 60), cosRemaining % 60
        )
    end
end)

-- Events
local GameEvents = ReplicatedStorage:WaitForChild("GameEvents")
local DataStream = GameEvents:WaitForChild("DataStream")
local WeatherEventStarted = GameEvents:WaitForChild("WeatherEventStarted")

DataStream.OnClientEvent:Connect(function(Type, Profile, Data)
    if Type ~= "UpdateData" or not Profile:find(LocalPlayer.Name) then return end

    local receivedCount = 0
    for _, p in Data do
        local packName = p[1]
        local content = p[2]
        
        if _G.Configuration.Mappings[packName] then
            if packName == "ROOT/CosmeticStock/ItemStocks" then
                CosmeticBuffer[packName] = content
            else
                GlobalBuffer[packName] = content
                AddLog("Received: " .. _G.Configuration.Mappings[packName], Color3.fromRGB(255, 200, 100))
            end
            receivedCount += 1
        end
    end

    if receivedCount > 0 then
        if not DebounceActive then
            DebounceActive = true
            AddLog("Debouncing 3s for full rollup...", Color3.fromRGB(100, 200, 255))
            task.delay(3.0, ProcessAndSend) -- Tăng 3s để chắc chắn gom đủ
        end
    end
end)

WeatherEventStarted.OnClientEvent:Connect(function(Event, Length)
    AddLog("Weather Event: " .. Event, Color3.fromRGB(150, 150, 255))
    if not _G.Configuration["Weather Reporting"] then return end
    local body = {
        embeds = {{
            title = "🌩️ ZENITH WEATHER", color = 0x2A6DFF,
            fields = {
                { name = "Current Weather", value = string.format("**%s**", Event), inline = true },
                { name = "Duration", value = string.format("Ends: <t:%d:R>", os.time() + Length), inline = true }
            },
            footer = { text = "Powered by Zenith" }, timestamp = DateTime.now():ToIsoDate()
        }}
    }
    for _, url in _G.Configuration.WeatherWebhooks do SafeRequest(url, body, "Weather") end
end)

RunService:Set3dRenderingEnabled(_G.Configuration["Rendering Enabled"])
LocalPlayer.Idled:Connect(function()
    if _G.Configuration["Anti-AFK"] then VirtualUser:CaptureController() VirtualUser:ClickButton2(Vector2.new()) end
end)
AddLog("Zenith v2.8 Ultimate Loaded.", Color3.fromRGB(255, 255, 255))
