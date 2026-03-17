local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

local API_URL = "https://zenithghz.qzz.io/api/update"

-------------------------------------------------------------------------------
-- UI (GIỮ NGUYÊN)
-------------------------------------------------------------------------------
local uiLayer = (gethui and gethui()) or CoreGui:FindFirstChild("RobloxGui") or CoreGui

if uiLayer:FindFirstChild("GHZ_Tracker_UI") then
    uiLayer["GHZ_Tracker_UI"]:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "GHZ_Tracker_UI"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = uiLayer

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 250, 0, 100)
mainFrame.Position = UDim2.new(0, 10, 0, 10)
mainFrame.BackgroundColor3 = Color3.fromRGB(30,30,30)
mainFrame.BackgroundTransparency = 0.2
mainFrame.Parent = screenGui

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1,0,0,30)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "🌱 GHZ Auto-Tracker"
titleLabel.TextColor3 = Color3.fromRGB(150,255,150)
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 14
titleLabel.Parent = mainFrame

local statusLabel = Instance.new("TextLabel")
statusLabel.Position = UDim2.new(0,10,0,30)
statusLabel.Size = UDim2.new(1,-20,0,25)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Status: Loading..."
statusLabel.TextColor3 = Color3.fromRGB(255,255,255)
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 12
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Parent = mainFrame

local infoLabel = Instance.new("TextLabel")
infoLabel.Position = UDim2.new(0,10,0,55)
infoLabel.Size = UDim2.new(1,-20,0,40)
infoLabel.BackgroundTransparency = 1
infoLabel.Text = ""
infoLabel.TextColor3 = Color3.fromRGB(200,200,200)
infoLabel.Font = Enum.Font.Gotham
infoLabel.TextSize = 11
infoLabel.TextXAlignment = Enum.TextXAlignment.Left
infoLabel.TextYAlignment = Enum.TextYAlignment.Top
infoLabel.Parent = mainFrame

local function updateUI(status, info)
    statusLabel.Text = status
    if info then infoLabel.Text = info end
end

-------------------------------------------------------------------------------
-- FIX CORE
-------------------------------------------------------------------------------

local function extractSmallestNumber(text)
    local smallest = nil
    for n in string.gmatch(text, "%d+") do
        local num = tonumber(n)

        -- 🔥 FIX: loại số 5 fake
        if num and num > 0 and num <= 999 and num ~= 5 then
            if not smallest or num < smallest then
                smallest = num
            end
        end
    end
    return smallest
end

-------------------------------------------------------------------------------
-- SCAN UI (GIỮ NGUYÊN LOGIC, CHỈ FIX NHẸ)
-------------------------------------------------------------------------------
local function scanUI()
    local seeds = {}
    local gear = {}
    local found = {}

    for _,obj in pairs(LocalPlayer.PlayerGui:GetDescendants()) do
        if obj:IsA("Frame") then
            local texts = {}
            local name = ""
            local stock = -1

            for _,child in pairs(obj:GetDescendants()) do
                if child:IsA("TextLabel") and child.Text ~= "" then
                    table.insert(texts, child.Text)
                end
            end

            for _,text in ipairs(texts) do
                local lower = string.lower(text)

                -- 🔥 FIX: bỏ x5 / 5x
                local isStock = string.find(lower,"stock")
                    or string.find(lower,"left")
                    or string.find(lower,"remain")

                if isStock then
                    local num = extractSmallestNumber(text)
                    if num and num > 0 then
                        stock = num
                    end
                end

                if #text > #name and not tonumber(text) then
                    name = text
                end
            end

            if name ~= "" and stock > 0 then

                -- 🔥 FIX: chặn mushroom bug
                if string.find(string.lower(name),"mushroom") and stock == 5 then
                    continue
                end

                if not found[name] then
                    found[name] = true

                    local data = {name=name, quantity=stock}

                    if string.find(string.lower(name),"seed") then
                        table.insert(seeds,data)
                    else
                        table.insert(gear,data)
                    end
                end
            end
        end
    end

    return seeds, gear
end

-------------------------------------------------------------------------------
-- WEATHER FIX
-------------------------------------------------------------------------------
local function scanWeather()
    local weather = {status="None",duration=0}

    local keywords = {
        "starfall","meteor","storm","rain","thunder",
        "sunny","clear","cloudy","windy","snow","blizzard"
    }

    for _,obj in pairs(LocalPlayer.PlayerGui:GetDescendants()) do
        if obj:IsA("TextLabel") then
            local txt = string.lower(obj.Text)

            for _,kw in ipairs(keywords) do
                if string.find(txt, kw) then
                    weather.status = kw

                    local m,s = string.match(obj.Text,"(%d+):(%d+)")
                    if m and s then
                        weather.duration = tonumber(m)*60 + tonumber(s)
                    end

                    local sec = string.match(obj.Text,"(%d+)%s*s")
                        or string.match(obj.Text,"(%d+)%s*sec")

                    if sec then weather.duration = tonumber(sec) end

                    return weather
                end
            end
        end
    end

    return weather
end

-------------------------------------------------------------------------------
-- SEND API
-------------------------------------------------------------------------------
local function send()
    updateUI("Scanning...")

    local seeds, gear = scanUI()
    local weather = scanWeather()

    local payload = {
        seeds = seeds,
        gear = gear,
        weather = weather,
        timestamp = os.time()
    }

    local req = (syn and syn.request) or request

    if req then
        pcall(function()
            req({
                Url = API_URL,
                Method = "POST",
                Headers = {["Content-Type"]="application/json"},
                Body = HttpService:JSONEncode(payload)
            })
        end)
    end

    updateUI("Done",
        "Seeds: "..#seeds..
        " | Gear: "..#gear..
        "\nWeather: "..weather.status
    )
end

-------------------------------------------------------------------------------
-- LOOP
-------------------------------------------------------------------------------
task.spawn(function()
    while true do
        send()
        task.wait(60)
    end
end)
