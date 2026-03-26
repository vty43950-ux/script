--[[
    @author Zenith
    @description Grow a Garden stock bot script with Premium UI
    https://www.roblox.com/games/126884695634066
]]

if _G.ZenithStockBot then return end
_G.ZenithStockBot = true

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local VirtualUser = game:GetService("VirtualUser")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")
local TeleportService = game:GetService("TeleportService")

local LocalPlayer = Players.LocalPlayer

-- Robust Request Function
local http_request = (request or http_request or (syn and syn.request) or (fluxus and fluxus.request) or (delta and delta.request))

-- Configuration
_G.Configuration = {
	["Enabled"] = true,
	["Webhook"] = "https://discord.com/api/webhooks/1482391815024803963/6V8VLwhL7X1o9FL_n1GNxxsoRH6su1tDzhbxzT4wJe_qr_MGCVaqp1fUs8ZKdnbyyC_H.....", -- REPLACE ME
	["Weather Reporting"] = true,
	["Anti-AFK"] = true,
	["Auto-Reconnect"] = true,
	["Rendering Enabled"] = true,

	["AlertLayouts"] = {
		["Weather"] = { EmbedColor = Color3.fromRGB(42, 109, 255) },
		["SeedsAndGears"] = {
			EmbedColor = Color3.fromRGB(56, 238, 23),
			Layout = {
				["ROOT/SeedStock/Stocks"] = "SEEDS STOCK",
				["ROOT/GearStock/Stocks"] = "GEAR STOCK"
			}
		},
		["EventShop"] = {
			EmbedColor = Color3.fromRGB(212, 42, 255),
			Layout = { ["ROOT/EventShopStock/Stocks"] = "EVENT STOCK" }
		},
		["Eggs"] = {
			EmbedColor = Color3.fromRGB(251, 255, 14),
			Layout = { ["ROOT/PetEggStock/Stocks"] = "EGG STOCK" }
		},
		["CosmeticStock"] = {
			EmbedColor = Color3.fromRGB(255, 106, 42),
			Layout = { ["ROOT/CosmeticStock/ItemStocks"] = "COSMETIC ITEMS STOCK" }
		}
	}
}

-- UI Creation (Premium Zenith UI)
local ScreenGui = Instance.new("ScreenGui")
local MainFrame = Instance.new("Frame")
local UICorner = Instance.new("UICorner")
-- UI Blur (Optional: some executors have sethiddenproperty)
-- pcall(function() sethiddenproperty(MainFrame, "Transparency", 0.5) end)

MainFrame.Name = "MainFrame"
MainFrame.Parent = ScreenGui
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
MainFrame.BackgroundTransparency = 0.1
MainFrame.Position = UDim2.new(0.5, -150, 0.5, -100)
MainFrame.Size = UDim2.new(0, 300, 0, 200)

UICorner.CornerRadius = UDim.new(0, 12)
UICorner.Parent = MainFrame

local UIGradient = Instance.new("UIGradient")
UIGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(40, 40, 50)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 20, 25))
})
UIGradient.Rotation = 45
UIGradient.Parent = MainFrame

local Title = Instance.new("TextLabel")
Title.Name = "Title"
Title.Parent = MainFrame
Title.BackgroundTransparency = 1
Title.Position = UDim2.new(0.05, 0, 0.05, 0)
Title.Size = UDim2.new(0.9, 0, 0.15, 0)
Title.Font = Enum.Font.GothamBold
Title.Text = "ZENITH • GAG STOCK BOT"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 16
Title.TextXAlignment = Enum.TextXAlignment.Left

-- Status indicator
local StatusCircle = Instance.new("Frame")
StatusCircle.Name = "Status"
StatusCircle.Parent = MainFrame
StatusCircle.BackgroundColor3 = Color3.fromRGB(0, 255, 120)
StatusCircle.Position = UDim2.new(0.9, 0, 0.08, 0)
StatusCircle.Size = UDim2.new(0, 8, 0, 8)
local SC_Corner = Instance.new("UICorner", StatusCircle)
SC_Corner.CornerRadius = UDim.new(1, 0)

local Dashboard = Instance.new("Frame")
Dashboard.Name = "Dashboard"
Dashboard.Parent = MainFrame
Dashboard.BackgroundTransparency = 1
Dashboard.Position = UDim2.new(0.05, 0, 0.25, 0)
Dashboard.Size = UDim2.new(0.9, 0, 0.6, 0)

local TimerLabel = Instance.new("TextLabel")
TimerLabel.Name = "TimerLabel"
TimerLabel.Parent = Dashboard
TimerLabel.BackgroundTransparency = 1
TimerLabel.Size = UDim2.new(1, 0, 1, 0)
TimerLabel.Font = Enum.Font.GothamMedium
TimerLabel.Text = "RESTOCK TIMERS"
TimerLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
TimerLabel.TextSize = 14
TimerLabel.RichText = true

local Footnote = Instance.new("TextLabel")
Footnote.Name = "Footnote"
Footnote.Parent = MainFrame
Footnote.BackgroundTransparency = 1
Footnote.Position = UDim2.new(0.05, 0, 0.85, 0)
Footnote.Size = UDim2.new(0.9, 0, 0.1, 0)
Footnote.Font = Enum.Font.Gotham
Footnote.Text = "Zenith Hub | Grow a Garden"
Footnote.TextColor3 = Color3.fromRGB(100, 100, 100)
Footnote.TextSize = 10

-- Dragging logic
local dragging, dragInput, dragStart, startPos
MainFrame.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = true
		dragStart = input.Position
		startPos = MainFrame.Position
	end
end)
MainFrame.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement then
		dragInput = input
	end
end)
game:GetService("UserInputService").InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = false
	end
end)

RunService.RenderStepped:Connect(function()
	if dragging and dragInput then
		local delta = dragInput.Position - dragStart
		MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
	end
end)

ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

-- Functions
local function WebhookSend(Type: string, Fields: table)
	if not _G.Configuration.Enabled then return end
    if not http_request then 
        warn("Zenith: HTTP Request not supported.")
        return 
    end

	local Layout = _G.Configuration.AlertLayouts[Type]
	local Color = tonumber(Layout.EmbedColor:ToHex(), 16)

	local Body = {
		embeds = {
			{
				color = Color,
				fields = Fields,
				footer = { text = "Powered by Zenith" },
				timestamp = DateTime.now():ToIsoDate()
			}
		}
	}

	task.spawn(function()
        local Success, Error = pcall(function()
            http_request({
                Url = _G.Configuration.Webhook,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = HttpService:JSONEncode(Body)
            })
        end)
        if not Success then warn("Zenith Webhook Error: " .. tostring(Error)) end
    end)
end

-- Timer Update
task.spawn(function()
    while task.wait(1) do
        local serverTime = workspace:GetServerTimeNow()
        
        local sgRemaining = 300 - (math.floor(serverTime) % 300)
        local sgMin = math.floor(sgRemaining / 60)
        local sgSec = sgRemaining % 60
        
        local eggRemaining = 1800 - (math.floor(serverTime) % 1800)
        local eggMin = math.floor(eggRemaining / 60)
        local eggSec = eggRemaining % 60

        TimerLabel.Text = string.format(
            "<font color='#00ff78'>SEED/GEAR RESTOCK:</font> %02d:%02d\n\n" ..
            "<font color='#ffe600'>EGG RESTOCK:</font> %02d:%02d\n\n" ..
            "<font color='#ff6a2a'>COSMETIC RESTOCK:</font> Hourly", 
            sgMin, sgSec, eggMin, eggSec
        )
    end
end)

-- Events
local DataStream = ReplicatedStorage:WaitForChild("GameEvents"):WaitForChild("DataStream")
local WeatherEventStarted = ReplicatedStorage:WaitForChild("GameEvents"):WaitForChild("WeatherEventStarted")

DataStream.OnClientEvent:Connect(function(Type, Profile, Data)
	if Type ~= "UpdateData" then return end
	if not Profile:find(LocalPlayer.Name) then return end

	for Name, Layout in _G.Configuration.AlertLayouts do
        if Name == "Weather" then continue end
        
        local FieldsLayout = Layout.Layout
        if not FieldsLayout then continue end

        local Fields = {}
        for Packet, Title in FieldsLayout do 
            local Content = nil
            for _, p in Data do
                if p[1] == Packet then Content = p[2] break end
            end

            if Content then
                local s = ""
                for k, v in Content do 
                    local name = v.EggName or k
                    s ..= `{name} **x{v.Stock}**\n`
                end
                if s ~= "" then
                    table.insert(Fields, { name = Title, value = s, inline = true })
                end
            end
        end

        if #Fields > 0 then WebhookSend(Name, Fields) end
	end
end)

WeatherEventStarted.OnClientEvent:Connect(function(Event, Length)
	if not _G.Configuration["Weather Reporting"] then return end
	local EndUnix = math.round(workspace:GetServerTimeNow()) + Length

	WebhookSend("Weather", {
		{ name = "WEATHER EVENT", value = `{Event}\nEnds: <t:{EndUnix}:R>`, inline = true }
	})
end)

-- Anti-Idle & Reconnect
LocalPlayer.Idled:Connect(function()
	if _G.Configuration["Anti-AFK"] then
		VirtualUser:CaptureController()
		VirtualUser:ClickButton2(Vector2.new())
	end
end)

GuiService.ErrorMessageChanged:Connect(function()
	if _G.Configuration["Auto-Reconnect"] then
        task.wait(5)
		TeleportService:Teleport(game.PlaceId, LocalPlayer)
	end
end)

RunService:Set3dRenderingEnabled(_G.Configuration["Rendering Enabled"])

print("Zenith GAG Stock Bot v2 Loaded.")
