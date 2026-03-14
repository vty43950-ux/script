-- CONFIG
local WEBHOOK = "https://discord.com/api/webhooks/1482391815024803963/6V8VLwhL7X1o9FL_n1GNxxsoRH6su1tDzhbxzT4wJe_qr_MGCVaqp1fUs8ZKdnbyyC_H"

-- SERVICES
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local player = Players.LocalPlayer

-- UI
local gui = Instance.new("ScreenGui")
gui.Name = "VanTyStockUI"
gui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Parent = gui
frame.Size = UDim2.new(0,260,0,170)
frame.Position = UDim2.new(0.02,0,0.3,0)
frame.BackgroundColor3 = Color3.fromRGB(25,25,25)

local title = Instance.new("TextLabel")
title.Parent = frame
title.Size = UDim2.new(1,0,0,30)
title.Text = "Garden Horizons Stock"
title.TextColor3 = Color3.new(1,1,1)
title.BackgroundTransparency = 1

-- DRAG UI
frame.Active = true
frame.Draggable = true

-- BUTTON CLOSE
local close = Instance.new("TextButton")
close.Parent = frame
close.Text = "X"
close.Size = UDim2.new(0,30,0,30)
close.Position = UDim2.new(1,-30,0,0)

-- BUTTON MINIMIZE
local mini = Instance.new("TextButton")
mini.Parent = frame
mini.Text = "-"
mini.Size = UDim2.new(0,30,0,30)
mini.Position = UDim2.new(1,-60,0,0)

-- STATUS
local status = Instance.new("TextLabel")
status.Parent = frame
status.Size = UDim2.new(1,0,0,30)
status.Position = UDim2.new(0,0,0,120)
status.Text = "Status: Ready"
status.TextColor3 = Color3.new(1,1,1)
status.BackgroundTransparency = 1

-- SEND TEST
local testBtn = Instance.new("TextButton")
testBtn.Parent = frame
testBtn.Size = UDim2.new(0,220,0,30)
testBtn.Position = UDim2.new(0,20,0,50)
testBtn.Text = "Send Test Webhook"

-- FORCE SEND
local forceBtn = Instance.new("TextButton")
forceBtn.Parent = frame
forceBtn.Size = UDim2.new(0,220,0,30)
forceBtn.Position = UDim2.new(0,20,0,85)
forceBtn.Text = "Force Send Stock"

-- MINIMIZED BUTTON
local openBtn = Instance.new("TextButton")
openBtn.Parent = gui
openBtn.Size = UDim2.new(0,120,0,30)
openBtn.Position = UDim2.new(0,20,0,200)
openBtn.Text = "Open Stock UI"
openBtn.Visible = false

-- FUNCTIONS

local function sendWebhook(data)

    status.Text = "Status: Sending..."

    local payload = HttpService:JSONEncode(data)

    local success,err = pcall(function()
        HttpService:PostAsync(
            WEBHOOK,
            payload,
            Enum.HttpContentType.ApplicationJson
        )
    end)

    if success then
        status.Text = "Status: Sent ✔"
    else
        status.Text = "HTTP Error"
        warn(err)
    end

end

local function getStock()

    local seeds = {}
    local gears = {}

    local seedShop = workspace:FindFirstChild("SeedShop")
    if seedShop then
        for _,v in pairs(seedShop:GetChildren()) do
            table.insert(seeds,v.Name)
        end
    end

    local gearShop = workspace:FindFirstChild("GearShop")
    if gearShop then
        for _,v in pairs(gearShop:GetChildren()) do
            table.insert(gears,v.Name)
        end
    end

    local weather = "Unknown"
    local w = workspace:FindFirstChild("Weather")
    if w then
        weather = w.Value
    end

    return {
        content =
        "**Seed:** "..table.concat(seeds,", ")..
        "\n**Gear:** "..table.concat(gears,", ")..
        "\n**Weather:** "..weather
    }

end

local function sendStock()
    local data = getStock()
    sendWebhook(data)
end

-- BUTTON EVENTS

testBtn.MouseButton1Click:Connect(function()
    sendWebhook({
        content = "Webhook Test ✔"
    })
end)

forceBtn.MouseButton1Click:Connect(sendStock)

mini.MouseButton1Click:Connect(function()
    frame.Visible = false
    openBtn.Visible = true
end)

openBtn.MouseButton1Click:Connect(function()
    frame.Visible = true
    openBtn.Visible = false
end)

close.MouseButton1Click:Connect(function()
    gui:Destroy()
end)

-- AUTO STOCK LOOP

task.spawn(function()

    while true
