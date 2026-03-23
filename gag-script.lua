--[[
    @author depso (depthso)
    @modified by Zenith API
    @description Grow a Garden stock bot script (Discord Webhook and API Sync)
    https://www.roblox.com/games/126884695634066
]]

type table = {
	[any]: any
}

_G.Configuration = {
	--// Reporting
	["Enabled"] = true,
	["Webhook"] = "https://discord.com/api/webhooks/1482391815024803963/6V8VLwhL7X1o9FL_n1GNxxsoRH6su1tDzhbxzT4wJe_qr_MGCVaqp1fUs8ZKdnbyyC_H", -- THAY BẰNG WEBHOOK CỦA BẠN
	["API_Url"] = "https://zenithghz.qzz.io/api/gag", -- Mở POST lên API
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

-- Lấy chuẩn hơn State qua API
local LiveData = {
    seeds = {},
    gear = {},
    events = {},
    eggs = {},
    cosmetics = {},
    weather = "Clear"
}

local function SendToAPI(Payload)
    if not _G.Configuration["API_Url"] or _G.Configuration["API_Url"] == "" then return end
    task.spawn(function()
        pcall(function()
            req({
                Url = _G.Configuration["API_Url"],
                Method = "POST",
                Headers = {
                    ["Content-Type"] = "application/json"
                },
                Body = HttpService:JSONEncode(Payload)
            })
        end)
    end)
end

local function ConvertColor3(Color)
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

local function UpdateLiveData(Data)
    local mapping = {
        ["ROOT/SeedStock/Stocks"] = "seeds",
        ["ROOT/GearStock/Stocks"] = "gear",
        ["ROOT/EventShopStock/Stocks"] = "events",
        ["ROOT/PetEggStock/Stocks"] = "eggs",
        ["ROOT/CosmeticStock/ItemStocks"] = "cosmetics"
    }

    local updated = false
    local partialPayload = {}
    
    for PacketKey, liveDataKey in mapping do
        local Stock = GetDataPacket(Data, PacketKey)
        if Stock then
            local arr = {}
            for Name, D in Stock do
                local ActualName = D.EggName or D.ItemName or D.Name or Name
                local Qty = D.Stock or D.Quantity or D.Amount
                table.insert(arr, { name = ActualName, quantity = Qty })
            end
            LiveData[liveDataKey] = arr
            partialPayload[liveDataKey] = arr
            updated = true
        end
    end
    
    if updated then
        SendToAPI(partialPayload)
    end
end

local function ProcessPacket(Data, Type, Layout)
	local Fields = {}
	if not Layout.Layout then return end
	
	for Packet, Title in Layout.Layout do 
		local Stock = GetDataPacket(Data, Packet)
        -- FIXED: Lấy chuẩn hơn, không return khi thiếu một packet (early return bug)
		if Stock then
            local String = ""
            for Name, D in Stock do 
                local ActualName = D.EggName or D.ItemName or D.Name or Name
                local Amount = D.Stock or D.Quantity or D.Amount
                local Line = Amount and `{ActualName} **x{Amount}**\n` or `{ActualName} **∞**\n`
                
                if #String + #Line > 1000 then
                    table.insert(Fields, {
                        name = Title,
                        value = String,
                        inline = true
                    })
                    String = ""
                    Title = Title .. " (Cont.)"
                end
                String ..= Line
            end
            
            if String ~= "" then
                table.insert(Fields, {
                    name = Title,
                    value = String,
                    inline = true
                })
            end
        end
	end
	
    if #Fields > 0 then
	    WebhookSend(Type, Fields)
    end
end

DataStream.OnClientEvent:Connect(function(Type, Profile, Data)
	if Type ~= "UpdateData" then return end
	if not Profile:find(LocalPlayer.Name) then return end

    -- Update state qua API POST
    UpdateLiveData(Data)

	for Name, Layout in _G.Configuration["AlertLayouts"] do
		ProcessPacket(Data, Name, Layout)
	end
end)

WeatherEventStarted.OnClientEvent:Connect(function(Event, Length)
	if not _G.Configuration["Weather Reporting"] then return end
	
	local ServerTime = math.round(workspace:GetServerTimeNow())
    
    -- Sync qua API
    LiveData.weather = Event
    SendToAPI({ weather = Event })

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

print("Webhook & API Bot Started successfully!")

