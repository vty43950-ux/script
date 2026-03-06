-- WEBHOOK
local WEBHOOK = "https://discord.com/api/webhooks/1479129651501731854/m74-VZ82k9tbeMgVeKagXiptZI9bRALGl558JPfLbk0NUrLc3FuWViEGuXc7BbuhC9ak"

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sendDiscord = true

-- GUI
local gui = Instance.new("ScreenGui", game.CoreGui)
gui.Name = "GardenTracker"

local frame = Instance.new("Frame", gui)
frame.Size = UDim2.new(0,220,0,120)
frame.Position = UDim2.new(0,20,0,100)
frame.BackgroundColor3 = Color3.fromRGB(30,30,30)

local title = Instance.new("TextLabel", frame)
title.Size = UDim2.new(1,0,0,30)
title.Text = "Garden Horizons Tracker"
title.TextColor3 = Color3.new(1,1,1)
title.BackgroundTransparency = 1
title.TextScaled = true

-- STOP BUTTON
local stopBtn = Instance.new("TextButton", frame)
stopBtn.Size = UDim2.new(1,-20,0,30)
stopBtn.Position = UDim2.new(0,10,0,40)
stopBtn.Text = "Stop Send Discord"

-- HIDE BUTTON
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

-- gửi webhook
local function sendEmbed(title,desc)

if not sendDiscord then return end

local data = {
["embeds"] = {{
["title"] = title,
["description"] = desc,
["color"] = 65280
}}
}

request({
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

-- đọc stock
local function getStock(folder,data)

local result = {}

for _,item in pairs(folder:GetChildren()) do

local stock = item:FindFirstChild("Stock")

if stock and stock.Value > 0 then

if data[item.Name] then
table.insert(result,"• "..item.Name)
end

end

end

return result

end

-- weather
local lastWeather = ""

local function checkWeather()

local weather = workspace:FindFirstChild("Weather")

if weather and weather.Value ~= lastWeather then

lastWeather = weather.Value

sendEmbed(
"🌦 Weather",
"Weather xuất hiện: **"..weather.Value.."**"
)

end

end

-- check stock
local function checkStock()

local seedShop = ReplicatedStorage:FindFirstChild("SeedShop")
local gearShop = ReplicatedStorage:FindFirstChild("GearShop")

if not seedShop or not gearShop then return end

local seeds = getStock(seedShop,Seeds)
local gears = getStock(gearShop,Gears)

if #seeds > 0 then
sendEmbed("🌱 Seed Stock",table.concat(seeds,"\n"))
end

if #gears > 0 then
sendEmbed("⚙ Gear Stock",table.concat(gears,"\n"))
end

end

-- LOOP
while true do

local minute = os.date("*t").min

if minute % 5 == 0 then
checkStock()
wait(60)
end

checkWeather()

wait(10)

end
