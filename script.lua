-- SERVICES
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local player = Players.LocalPlayer

-- HTTP REQUEST
local request = request or http_request or syn and syn.request

-- WEBHOOK
local WEBHOOK = "https://discord.com/api/webhooks/1479129651501731854/m74-VZ82k9tbeMgVeKagXiptZI9bRALGl558JPfLbk0NUrLc3FuWViEGuXc7BbuhC9ak"

-- UI
local gui = Instance.new("ScreenGui")
gui.Parent = player:WaitForChild("PlayerGui")

local label = Instance.new("TextLabel")
label.Parent = gui
label.Size = UDim2.new(0,220,0,40)
label.Position = UDim2.new(0.5,-110,0,20)
label.BackgroundColor3 = Color3.fromRGB(0,0,0)
label.TextColor3 = Color3.fromRGB(0,255,0)
label.TextScaled = true
label.Text = "🟢 Garden Horizons Tracker"

-- SEND WEBHOOK
local function send(title,desc,color)

if not request then
warn("Executor không hỗ trợ HTTP")
return
end

local data = {
username = "Garden Horizons Tracker",
embeds = {{
title = title,
description = desc,
color = color,
footer = {text = "Stock & Weather Tracker"},
timestamp = DateTime.now():ToIsoDate()
}}
}

request({
Url = WEBHOOK,
Method = "POST",
Headers = {["Content-Type"] = "application/json"},
Body = HttpService:JSONEncode(data)
})

end

-- SCAN ITEMS
local function scan(keyword)

local list = {}

for _,v in pairs(workspace:GetDescendants()) do

if string.find(string.lower(v.Name),keyword) then
table.insert(list,v.Name)
end

end

return list

end

-- FORMAT
local function format(list)

if #list == 0 then
return "Không tìm thấy"
end

local text = ""

for _,v in pairs(list) do
text = text.."• "..v.."\n"
end

return text

end

-- WEATHER TRACK
local lastWeather = ""

task.spawn(function()

while true do
task.wait(3)

local weather = workspace:FindFirstChild("Weather")

if weather then

local current = tostring(weather.Value)

if current ~= lastWeather then
lastWeather = current

send(
"🌦 Weather xuất hiện",
"**"..current.."** vừa xuất hiện trong server",
16776960
)

end

end

end

end)

-- STOCK TIMER
task.spawn(function()

while true do

local t = os.date("*t")

if t.min % 5 == 0 and t.sec == 0 then

local seeds = scan("seed")
local gears = scan("gear")

send(
"🌱 Seed Stock",
format(seeds),
65280
)

send(
"⚙️ Gear Stock",
format(gears),
3447003
)

task.wait(61)

end

task.wait(1)

end

end)
