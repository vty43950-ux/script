--[[
    @author Zenith
    @description Grow a Garden stock bot script v2.1 - Optimized & Consolidated
    https://www.roblox.com/games/126884695634066
]]

if _G.ZenithStockBotV2 then return end
_G.ZenithStockBotV2 = true

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
        "https://discordapp.com/api/webhooks/1486748889460506699/Kn0xlJ7fYiTuvZQ2ghbJmpn_vzawM_TN4kkyDKmajHxSl6fnTCDyrgGT9QR_SIqWwhrv", -- REPLACE ME
        "URL_WEATHER_2", 
        "URL_WEATHER_3" 
    },
    
    ["CosmeticWebhooks"] = {
        "https://discordapp.com/api/webhooks/1486748995786248315/2icGcBd-eNa7JHq8tsctQ5j383ZkWM4AFFFkCmPx9BXMJPWTUKAgJQMXpoXC_4O2gSIk", -- REPLACE ME
        "URL_COSMETIC_2", -- REPLACE ME
        "URL_COSMETIC_3"  -- REPLACE ME
    },

	["Weather Reporting"] = true,
	["Anti-AFK"] = true,
	["Auto-Reconnect"] = true,
	["Rendering Enabled"] = true,

    -- Layout Mapping
	["Mappings"] = {
		["SeedsAndGears"] = {
			["ROOT/SeedStock/Stocks"] = "SEEDS STOCK",
			["ROOT/GearStock/Stocks"] = "GEAR STOCK"
		},
		["EventShop"] = {
			["ROOT/EventShopStock/Stocks"] = "EVENT STOCK"
		},
		["Eggs"] = {
			["ROOT/PetEggStock/Stocks"] = "EGG STOCK"
		},
		["CosmeticStock"] = {
			["ROOT/CosmeticStock/ItemStocks"] = "COSMETIC ITEMS STOCK"
		}
	}
}

-- UI Creation
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ZenithGAG_V2"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Parent = ScreenGui
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
MainFrame.BorderSizePixel = 0
MainFrame.Position = UDim2.new(0.5, -160, 0.5, -110)
MainFrame.Size = UDim2.new(0, 320, 0, 220)

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 10)
UICorner.Parent = MainFrame

local UIStroke = Instance.new("UIStroke")
UIStroke.Color = Color3.fromRGB(45, 45, 60)
UIStroke.Thickness = 1.5
UIStroke.Parent = MainFrame

local UIGradient = Instance.new("UIGradient")
UIGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(30, 30, 40)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(15, 15, 20))
})
UIGradient.Rotation = 90
UIGradient.Parent = MainFrame

local Title = Instance.new("TextLabel")
Title.Name = "Title"
Title.Parent = MainFrame
Title.BackgroundTransparency = 1
Title.Position = UDim2.new(0.05, 0, 0.05, 0)
Title.Size = UDim2.new(0.9, 0, 0.15, 0)
Title.Font = Enum.Font.GothamBold
Title.Text = "ZENITH • HUB V2.1"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 16
Title.TextXAlignment = Enum.TextXAlignment.Left

local StatusCircle = Instance.new("Frame")
StatusCircle.Name = "Status"
StatusCircle.Parent = MainFrame
StatusCircle.BackgroundColor3 = Color3.fromRGB(0, 255, 150)
StatusCircle.Position = UDim2.new(0.9, 0, 0.09, 0)
StatusCircle.Size = UDim2.new(0, 8, 0, 8)
Instance.new("UICorner", StatusCircle).CornerRadius = UDim.new(1, 0)

local TimerContainer = Instance.new("Frame")
TimerContainer.Name = "TimerContainer"
TimerContainer.Parent = MainFrame
TimerContainer.BackgroundTransparency = 1
TimerContainer.Position = UDim2.new(0.05, 0, 0.25, 0)
TimerContainer.Size = UDim2.new(0.9, 0, 0.6, 0)

local TimerLabel = Instance.new("TextLabel")
TimerLabel.Name = "TimerLabel"
TimerLabel.Parent = TimerContainer
TimerLabel.BackgroundTransparency = 1
TimerLabel.Size = UDim2.new(1, 0, 1, 0)
TimerLabel.Font = Enum.Font.GothamMedium
TimerLabel.Text = "Loading Timers..."
TimerLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
TimerLabel.TextSize = 13
TimerLabel.RichText = true
TimerLabel.TextYAlignment = Enum.TextYAlignment.Top

local Footnote = Instance.new("TextLabel")
Footnote.Name = "Footnote"
Footnote.Parent = MainFrame
Footnote.BackgroundTransparency = 1
Footnote.Position = UDim2.new(0.05, 0, 0.88, 0)
Footnote.Size = UDim2.new(0.9, 0, 0.08, 0)
Footnote.Font = Enum.Font.Gotham
Footnote.Text = "Optimized for Grow a Garden | Zenith"
Footnote.TextColor3 = Color3.fromRGB(120, 120, 130)
Footnote.TextSize = 10

-- Drag Logic
local dragging, dragInput, dragStart, startPos
MainFrame.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = true
		dragStart = input.Position
		startPos = MainFrame.Position
	end
end)
MainFrame.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement then dragInput = input end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
end)
RunService.RenderStepped:Connect(function()
	if dragging and dragInput then
		local delta = dragInput.Position - dragStart
		MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
	end
end)

-- Webhook Logic
local function SafeRequest(url, body)
    if not http_request or not url or url == "" or url:find("REPLACE") then return end
    task.spawn(function()
        local s, e = pcall(function()
            http_request({
                Url = url,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = HttpService:JSONEncode(body)
            })
        end)
        if not s then warn("Zenith Webhook Error: " .. tostring(e)) end
    end)
end

local function SendConsolidatedStock(fields, isCosmetic)
    if not _G.Configuration.Enabled or #fields == 0 then return end
    
    local body = {
        embeds = {
            {
                title = isCosmetic and "✨ COSMETIC STOCK UPDATE" or "🛒 GLOBAL STOCK UPDATE",
                color = isCosmetic and 0xFF6A2A or 0x38EE17,
                fields = fields,
                footer = { text = "Powered by Zenith" },
                timestamp = DateTime.now():ToIsoDate()
            }
        }
    }

    if isCosmetic then
        for _, url in _G.Configuration.CosmeticWebhooks do
            SafeRequest(url, body)
        end
    else
        SafeRequest(_G.Configuration.MainWebhook, body)
    end
end

-- Timer Update
task.spawn(function()
    while task.wait(1) do
        local serverTime = workspace:GetServerTimeNow()
        
        -- Regular Shops (5 min)
        local sgRemaining = 300 - (math.floor(serverTime) % 300)
        local sgMin, sgSec = math.floor(sgRemaining / 60), sgRemaining % 60
        
        -- Cosmetic (4 hours)
        -- Logic: 4h = 14400s. Points: 0, 4, 8, 12, 16, 20 UTC
        local cosRemaining = 14400 - (math.floor(serverTime) % 14400)
        local cosHr = math.floor(cosRemaining / 3600)
        local cosMin = math.floor((cosRemaining % 3600) / 60)
        local cosSec = cosRemaining % 60

        TimerLabel.Text = string.format(
            "<font color='#00ff96'>SEED/GEAR STOCK:</font> %02d:%02d\n" ..
            "<font color='#00ff96'>EGG/EVENT STOCK:</font> %02d:%02d\n" ..
            "<font color='#ff6a2a'>COSMETIC STOCK:</font> %02d:%02d:%02d", 
            sgMin, sgSec, sgMin, sgSec, cosHr, cosMin, cosSec
        )
    end
end)

-- Events Handling
local DataStream = ReplicatedStorage:WaitForChild("GameEvents"):WaitForChild("DataStream")
local WeatherEventStarted = ReplicatedStorage:WaitForChild("GameEvents"):WaitForChild("WeatherEventStarted")

DataStream.OnClientEvent:Connect(function(Type, Profile, Data)
	if Type ~= "UpdateData" then return end
	if not Profile:find(LocalPlayer.Name) then return end

    local MainFields = {}
    local CosmeticFields = {}

    for MapType, MapData in _G.Configuration.Mappings do
        local isCosmetic = (MapType == "CosmeticStock")
        
        for Packet, Title in MapData do
            -- Find packet
            local Content = nil
            for _, p in Data do
                if p[1] == Packet then Content = p[2] break end
            end

            if Content then
                local s = ""
                for k, v in Content do
                    local name = v.EggName or k
                    s ..= string.format("• %s: **x%d**\n", name, v.Stock)
                end
                
                if s ~= "" then
                    local field = { name = Title, value = s, inline = true }
                    if isCosmetic then
                        table.insert(CosmeticFields, field)
                    else
                        table.insert(MainFields, field)
                    end
                end
            end
        end
    end

    -- Send Consolidated
    if #MainFields > 0 then SendConsolidatedStock(MainFields, false) end
    if #CosmeticFields > 0 then SendConsolidatedStock(CosmeticFields, true) end
end)

WeatherEventStarted.OnClientEvent:Connect(function(Event, Length)
	if not _G.Configuration["Weather Reporting"] then return end
	local EndUnix = math.round(workspace:GetServerTimeNow()) + Length

	local body = {
		embeds = {
			{
				title = "🌩️ STRANGE WEATHER DETECTED",
				color = 0x2A6DFF,
				fields = {
					{ name = "Current Weather", value = string.format("**%s**", Event), inline = true },
					{ name = "Duration", value = string.format("Ends: <t:%d:R>", EndUnix), inline = true }
				},
				footer = { text = "Powered by Zenith" },
				timestamp = DateTime.now():ToIsoDate()
			}
		}
	}
    
    for _, url in _G.Configuration.WeatherWebhooks do
        SafeRequest(url, body)
    end
end)

-- Utility
LocalPlayer.Idled:Connect(function()
	if _G.Configuration["Anti-AFK"] then
		VirtualUser:CaptureController()
		VirtualUser:ClickButton2(Vector2.new())
	end
end)

GuiService.ErrorMessageChanged:Connect(function()
	if _G.Configuration["Auto-Reconnect"] then
        task.wait(10)
		TeleportService:Teleport(game.PlaceId, LocalPlayer)
	end
end)

RunService:Set3dRenderingEnabled(_G.Configuration["Rendering Enabled"])

print("Zenith Hub v2.1 Activated.")
