type table = {
	[any]: any
}

_G.Configuration = {
	--// Reporting
	["Enabled"] = true,
	["Webhook"] = "https://discord.com/api/webhooks/1482391815024803963/6V8VLwhL7X1o9FL_n1GNxxsoRH6su1tDzhbxzT4wJe_qr_MGCVaqp1fUs8ZKdnbyyC_H", 
	["Weather Reporting"] = true,
	
	--// User
	["Anti-AFK"] = true,
	["Auto-Reconnect"] = true,
	["Rendering Enabled"] = true, 
	--// Embeds
	["AlertLayouts"] = {
		["Weather"] = {
			EmbedColor = Color3.fromRGB(42, 109, 255),
		},
		["SeedsAndGears"] = {
			EmbedColor = Color3.fromRGB(56, 238, 23),
			Layout = {
				["ROOT/SeedStock/Stocks"] = "SEEDS STOCK",
				["ROOT/GearStock/Stocks"] = "GEAR STOCK"
			}
		},
		["EventShop"] = {
			EmbedColor = Color3.fromRGB(212, 42, 255),
			Layout = {
				["ROOT/EventShopStock/Stocks"] = "EVENT STOCK"
			}
		},
		["Eggs"] = {
			EmbedColor = Color3.fromRGB(251, 255, 14),
			Layout = {
				["ROOT/PetEggStock/Stocks"] = "EGG STOCK"
			}
		},
		["CosmeticStock"] = {
			EmbedColor = Color3.fromRGB(255, 106, 42),
			Layout = {
				["ROOT/CosmeticStock/ItemStocks"] = "COSMETIC ITEMS STOCK"
			}
		}
	}
}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local VirtualUser = cloneref(game:GetService("VirtualUser"))
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local TeleportService = game:GetService("TeleportService")

local DataStream = ReplicatedStorage.GameEvents.DataStream
local WeatherEventStarted = ReplicatedStorage.GameEvents.WeatherEventStarted

local LocalPlayer = Players.LocalPlayer
local PlaceId = game.PlaceId
local JobId = game.JobId

if _G.StockBot then return end 
_G.StockBot = true

RunService:Set3dRenderingEnabled(_G.Configuration["Rendering Enabled"])

local req = (request or syn and syn.request or http and http.request)

local function ConvertColor3(Color)
    -- Exploit safe hex conversion
	return math.floor(Color.R * 255) * 65536 + math.floor(Color.G * 255) * 256 + math.floor(Color.B * 255)
end

local function WebhookSend(Type, Fields)
	if not _G.Configuration["Enabled"] or not req then return end
	
	local Layout = _G.Configuration["AlertLayouts"][Type]
	if not Layout then return end

	local Body = {
		embeds = {{
			color = ConvertColor3(Layout.EmbedColor),
			fields = Fields,
			footer = {
				text = "Created by depso | Modified by Zenith"
			},
			timestamp = DateTime.now():ToIsoDate()
		}}
	}
	
    task.spawn(function()
        pcall(function()
            req({
                Url = _G.Configuration["Webhook"],
                Method = "POST",
                Headers = {
                    ["Content-Type"] = "application/json"
                },
                Body = HttpService:JSONEncode(Body)
            })
        end)
    end)
end

local function GetDataPacket(Data, Target)
	for _, Packet in Data do
		if Packet[1] == Target then
			return Packet[2]
		end
	end
	return nil
end

local function ProcessPacket(Data, Type, Layout)
	local Fields = {}
	if not Layout.Layout then return end
	
	for Packet, Title in Layout.Layout do 
		local Stock = GetDataPacket(Data, Packet)
		if not Stock then return end

		local String = ""
        for Name, D in Stock do 
            local ActualName = D.EggName or Name
            String ..= `{ActualName} **x{D.Stock}**\n`
        end
		
		table.insert(Fields, {
			name = Title,
			value = String,
			inline = true
		})
	end
	
    if #Fields > 0 then
	    WebhookSend(Type, Fields)
    end
end

DataStream.OnClientEvent:Connect(function(Type, Profile, Data)
	if Type ~= "UpdateData" then return end
	if not Profile:find(LocalPlayer.Name) then return end

	for Name, Layout in _G.Configuration["AlertLayouts"] do
		ProcessPacket(Data, Name, Layout)
	end
end)

WeatherEventStarted.OnClientEvent:Connect(function(Event, Length)
	if not _G.Configuration["Weather Reporting"] then return end
	
	local ServerTime = math.round(workspace:GetServerTimeNow())
	WebhookSend("Weather", {
		{
			name = "WEATHER",
			value = `{Event}\nEnds:<t:{ServerTime + Length}:R>`,
			inline = true
		}
	})
end)

LocalPlayer.Idled:Connect(function()
	if _G.Configuration["Anti-AFK"] then
		VirtualUser:CaptureController()
		VirtualUser:ClickButton2(Vector2.new())
	end
end)

GuiService.ErrorMessageChanged:Connect(function()
	if not _G.Configuration["Auto-Reconnect"] then return end
    
    if queue_on_teleport then
	    queue_on_teleport('loadstring(game:HttpGet("https://raw.githubusercontent.com/depthso/Grow-a-Garden/refs/heads/main/Stock%20bot.lua"))()')
    end
    
	if #Players:GetPlayers() <= 1 then
		TeleportService:Teleport(PlaceId, LocalPlayer)
	else
		TeleportService:TeleportToPlaceInstance(PlaceId, JobId, LocalPlayer)
	end
end)

print("Webhook Bot Started successfully!")
local HttpService = game:GetService("HttpService")
local VirtualUser = cloneref(game:GetService("VirtualUser"))
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local TeleportService = game:GetService("TeleportService")

local DataStream = ReplicatedStorage.GameEvents.DataStream
local WeatherEventStarted = ReplicatedStorage.GameEvents.WeatherEventStarted

local LocalPlayer = Players.LocalPlayer
local PlaceId = game.PlaceId
local JobId = game.JobId

if _G.StockBot then return end 
_G.StockBot = true

RunService:Set3dRenderingEnabled(_G.Configuration["Rendering Enabled"])

local req = (request or syn and syn.request or http and http.request)

-- LƯU TRẠNG THÁI WEB API
local CurrentState = { seeds = {}, gear = {}, events = {}, eggs = {}, cosmetics = {}, weather = "Clear" }

-- TÁCH DỮ LIỆU
local function GetDataPacket(Data, Target)
	for _, Packet in Data do
		if Packet[1] == Target then return Packet[2] end
	end
	return nil
end

local function ParseStock(StockData)
    local items = {}
    if not StockData then return items end
    for Name, Data in StockData do 
		local Amount = Data.Stock
		local ActualName = Data.EggName or Name
        table.insert(items, { name = ActualName, quantity = Amount })
	end
    return items
end

-- TIẾN TRÌNH POST API NGẦM
local function PostDataToAPI()
    if not _G.Configuration["Enabled"] or not req then return end
    local Body = HttpService:JSONEncode(CurrentState)
    task.spawn(function()
        pcall(req, {
            Url = _G.Configuration["ApiEndpoint"], Method = "POST",
            Headers = { ["Content-Type"] = "application/json" }, Body = Body
        })
    end)
end

-- PHẦN XỬ LÝ WEBHOOK GỐC (ĐÃ PHỤC HỒI) 
local function ConvertColor3(Color)
	return tonumber(Color:ToHex(), 16)
end

local function WebhookSend(Type, Fields)
	if not _G.Configuration["Enabled"] or not req then return end
	local Layout = _G.Configuration["AlertLayouts"][Type]
	local Body = {
		embeds = {{
			color = ConvertColor3(Layout.EmbedColor),
			fields = Fields,
			footer = { text = "Create By Zenith." },
			timestamp = DateTime.now():ToIsoDate()
		}}
	}
    task.spawn(function()
        pcall(req, {
            Url = _G.Configuration["Webhook"], Method = "POST",
            Headers = { ["Content-Type"] = "application/json" }, Body = HttpService:JSONEncode(Body)
        })
    end)
end

local function ProcessPacket(Data, Type, Layout)
	local Fields = {}
	if not Layout.Layout then return end
	for Packet, Title in Layout.Layout do 
		local Stock = GetDataPacket(Data, Packet)
		if not Stock then return end

		local String = ""
        for Name, D in Stock do 
            String ..= `{D.EggName or Name} **x{D.Stock}**\n`
        end

		table.insert(Fields, { name = Title, value = String, inline = true })
	end
	WebhookSend(Type, Fields)
end

-- LẮNG NGHE STOCK
DataStream.OnClientEvent:Connect(function(Type, Profile, Data)
	if Type ~= "UpdateData" or not Profile:find(LocalPlayer.Name) then return end

    -- 1. Xử lý bắn Webhook Discord
	for Name, Layout in _G.Configuration["AlertLayouts"] do
		ProcessPacket(Data, Name, Layout)
	end

    -- 2. Xử lý đồng bộ Web API
    CurrentState.seeds = ParseStock(GetDataPacket(Data, "ROOT/SeedStock/Stocks"))
    CurrentState.gear = ParseStock(GetDataPacket(Data, "ROOT/GearStock/Stocks"))
    CurrentState.events = ParseStock(GetDataPacket(Data, "ROOT/EventShopStock/Stocks"))
    CurrentState.eggs = ParseStock(GetDataPacket(Data, "ROOT/PetEggStock/Stocks"))
    CurrentState.cosmetics = ParseStock(GetDataPacket(Data, "ROOT/CosmeticStock/ItemStocks"))
    PostDataToAPI()
end)

-- LẮNG NGHE THỜI TIẾT
WeatherEventStarted.OnClientEvent:Connect(function(Event, Length)
    -- 1. Web API
    CurrentState.weather = Event
    PostDataToAPI()
    task.delay(Length, function()
        if CurrentState.weather == Event then
            CurrentState.weather = "Clear"
            PostDataToAPI()
        end
    end)

    -- 2. Discord Webhook
	if not _G.Configuration["Weather Reporting"] then return end
	local ServerTime = math.round(workspace:GetServerTimeNow())
	WebhookSend("Weather", {{ name = "WEATHER", value = `{Event}\nEnds:<t:{ServerTime + Length}:R>`, inline = true }})
end)

-- ANTI IDLE & RECONNECT
LocalPlayer.Idled:Connect(function()
	if _G.Configuration["Anti-AFK"] then VirtualUser:CaptureController() VirtualUser:ClickButton2(Vector2.new()) end
end)
GuiService.ErrorMessageChanged:Connect(function()
	if not _G.Configuration["Auto-Reconnect"] then return end
    if queue_on_teleport then queue_on_teleport('loadstring(game:HttpGet("https://raw.githubusercontent.com/depthso/Grow-a-Garden/refs/heads/main/Stock%20bot.lua"))()') end
	if #Players:GetPlayers() <= 1 then TeleportService:Teleport(PlaceId, LocalPlayer) else TeleportService:TeleportToPlaceInstance(PlaceId, JobId, LocalPlayer) end
end)

print("✅ Zenith GAG API & Webhook Sync Started!")
