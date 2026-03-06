-- VanTy Engine V10
-- Garden Horizons Tracker

local WEBHOOK = "https://discord.com/api/webhooks/1479129651501731854/m74-VZ82k9tbeMgVeKagXiptZI9bRALGl558JPfLbk0NUrLc3FuWViEGuXc7BbuhC9ak"

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- request compatibility
local req =
syn and syn.request or
http_request or
request or
(fluxus and fluxus.request)

-- state
local sendDiscord = true
local lastWeather = ""
local lastStockHash = ""

-- GUI
local gui = Instance.new("ScreenGui", game.CoreGui)
gui.Name = "VanTyTracker"

local frame = Instance.new("Frame", gui)
frame.Size = UDim2.new(0,230,0,130)
frame.Position = UDim2.new(0,20,0,120)
frame.BackgroundColor3 = Color3.fromRGB(25,25,25)

local title = Instance.new("TextLabel", frame)
title.Size = UDim2.new(1,0,0,30)
title.Text = "Garden Horizons Tracker"
title.TextColor3 = Color3.new(1,1,1)
title.BackgroundTransparency = 1
title.TextScaled = true

local stopBtn = Instance.new("TextButton", frame)
stopBtn.Size = UDim2.new(1,-20,0,30)
stopBtn.Position = UDim2.new(0,10,0,40)
stopBtn.Text = "Stop Send Discord"

local hideBtn = Instance.new("TextButton", frame)
hideBtn.Size = UDim2.new(1,-20,0,30)
hideBtn.Position = UDim2.new(0,10,0,80)
hideBtn.Text = "Hide GUI"

stopBtn.MouseButton1Click:Connect(function()
sendDiscord = false
stopBtn.Text = "Discord Stopped"
end)

hideBtn.MouseButton1Click:Connect(function()
frame.Visible = false
end)

-- send webhook
local function sendEmbed(title,desc,color)

if not sendDiscord then return end
if not req then warn("Request not supported") return end

local data = {
embeds = {{
title = title,
description = desc,
color = color or 65280
}}
}

req({
Url = WEBHOOK,
Method = "POST",
Headers = {["Content-Type"]="application/json"},
Body = HttpService:JSONEncode(data)
})

end

-- seed list
local Seeds = {
Carrot=true,
Corn=true,
Onion=true,
Strawberry=true,
Mushroom=true,
Beetroot=true,
Tomato=true,
Apple=true,
Rose=true,
Wheat=true,
Banana=true,
Plum=true,
Potato=true,
Cabbage=true,
Bamboo=true,
Cherry=true,
Mango=true
}

-- gear list
local Gears = {
["Watering Can"]=true,
["Basic Sprinkler"]=true,
["Harvest Bell"]=true,
["Turbo Sprinkler"]=true,
["Super Sprinkler"]=true
}

-- read stock
local function readStock(folder,data)

local list = {}

for _,v in pairs(folder:GetChildren()) do

local stock = v:FindFirstChild("Stock")

if stock and stock.Value > 0 then

if data[v.Name] then
table.insert(list,"• "..v.Name)
end

end

end

return list

end

-- stock check
local function checkStock()

local seedShop = ReplicatedStorage:FindFirstChild("SeedShop")
local gearShop = ReplicatedStorage:FindFirstChild("GearShop")

if not seedShop or not gearShop then return end

local seeds = readStock(seedShop,Seeds)
local gears = readStock(gearShop,Gears)

local hash = HttpService:JSONEncode(seeds)..HttpService:JSONEncode(gears)

if hash ~= lastStockHash then

lastStockHash = hash

if #seeds > 0 then
sendEmbed("🌱 Seed Stock",table.concat(seeds,"\n"))
end

if #gears > 0 then
sendEmbed("⚙ Gear Stock",table.concat(gears,"\n"))
end

end

end

-- weather
local function checkWeather()

local weather = workspace:FindFirstChild("Weather")

if weather and weather.Value ~= lastWeather then

lastWeather = weather.Value

sendEmbed(
"🌦 Weather Appeared",
"Weather hiện tại: **"..weather.Value.."**",
16776960
)

end

end

-- engine loop
while true do

checkStock()
checkWeather()

wait(30)

end
