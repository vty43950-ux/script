-- CONFIG
local WEBHOOK = "https://discord.com/api/webhooks/1482391815024803963/6V8VLwhL7X1o9FL_n1GNxxsoRH6su1tDzhbxzT4wJe_qr_MGCVaqp1fUs8ZKdnbyyC_H"

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

print("Stock script started")

-- UI
local gui = Instance.new("ScreenGui")
gui.Parent = player:WaitForChild("PlayerGui")
gui.Name = "StockUI"

local frame = Instance.new("Frame")
frame.Parent = gui
frame.Size = UDim2.new(0,220,0,150)
frame.Position = UDim2.new(0,20,0,200)
frame.BackgroundColor3 = Color3.fromRGB(35,35,35)

-- TITLE
local title = Instance.new("TextLabel")
title.Parent = frame
title.Size = UDim2.new(1,0,0,30)
title.Text = "Garden Horizons Stock"
title.TextColor3 = Color3.new(1,1,1)
title.BackgroundTransparency = 1

-- CLOSE
local close = Instance.new("TextButton")
close.Parent = frame
close.Size = UDim2.new(0,30,0,30)
close.Position = UDim2.new(1,-30,0,0)
close.Text = "X"

-- HIDE
local hide = Instance.new("TextButton")
hide.Parent = frame
hide.Size = UDim2.new(0,30,0,30)
hide.Position = UDim2.new(1,-60,0,0)
hide.Text = "-"

-- TEST BUTTON
local testBtn = Instance.new("TextButton")
testBtn.Parent = frame
testBtn.Size = UDim2.new(0,180,0,40)
testBtn.Position = UDim2.new(0,20,0,50)
testBtn.Text = "Send Test"

-- STATUS
local status = Instance.new("TextLabel")
status.Parent = frame
status.Size = UDim2.new(1,0,0,30)
status.Position = UDim2.new(0,0,0,100)
status.Text = "Status: waiting"
status.TextColor3 = Color3.new(1,1,1)
status.BackgroundTransparency = 1

-- WEBHOOK SEND
local function sendWebhook(data)

    print("Sending webhook")

    pcall(function()

        HttpService:PostAsync(
            WEBHOOK,
            HttpService:JSONEncode(data),
            Enum.HttpContentType.ApplicationJson
        )

    end)

end

-- TEST
testBtn.MouseButton1Click:Connect(function()

    status.Text = "Status: sending test"

    sendWebhook({
        content = "Webhook test từ Roblox"
    })

    status.Text = "Status: test sent"

end)

-- CLOSE
close.MouseButton1Click:Connect(function()
    gui:Destroy()
end)

-- HIDE
hide.MouseButton1Click:Connect(function()
    frame.Visible = false
end)

-- GET STOCK
local function getStock()

    local data = {
        content = "",
    }

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
    local weatherObj = workspace:FindFirstChild("Weather")
    if weatherObj then
        weather = weatherObj.Value
    end

    data.content =
        "**Seed:** "..table.concat(seeds,", ")..
        "\n**Gear:** "..table.concat(gears,", ")..
        "\n**Weather:** "..weather

    return data

end

-- WAIT NEXT 5 MIN
local function waitNext()

    local now = os.time()
    local nextTick = math.ceil(now/300)*300

    wait(nextTick-now)

end

-- LOOP
spawn(function()

    while true do

        status.Text = "Status: waiting next stock"

        waitNext()

        status.Text = "Status: getting stock"

        local stock = getStock()

        sendWebhook(stock)

        status.Text = "Status: stock sent"

    end

end)
