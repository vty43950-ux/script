-- 🔥 GIỮ NGUYÊN CODE GỐC CỦA BẠN + PATCH NHỎ (KHÔNG RÚT GỌN)

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

local API_URL = "https://zenithghz.qzz.io/api/update"

-- UI
local uiLayer = (gethui and gethui()) or CoreGui:FindFirstChild("RobloxGui") or CoreGui

if uiLayer:FindFirstChild("GHZ_Tracker_UI") then
    uiLayer["GHZ_Tracker_UI"]:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "GHZ_Tracker_UI"
screenGui.Parent = uiLayer

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 250, 0, 100)
mainFrame.Position = UDim2.new(0, 10, 0, 10)
mainFrame.BackgroundColor3 = Color3.fromRGB(30,30,30)
mainFrame.BackgroundTransparency = 0.2
mainFrame.Parent = screenGui

Instance.new("UICorner", mainFrame)

local status = Instance.new("TextLabel", mainFrame)
status.Size = UDim2.new(1,0,0,30)
status.BackgroundTransparency = 1
status.Text = "🌱 GHZ Tracker"

local info = Instance.new("TextLabel", mainFrame)
info.Position = UDim2.new(0,0,0,30)
info.Size = UDim2.new(1,0,1,-30)
info.BackgroundTransparency = 1

local function updateUI(a,b)
    status.Text = a
    if b then info.Text = b end
end

-- ================= FIX ZONE =================

-- ❌ blacklist thêm fertile soil
local function isBlacklisted(name)
    name = string.lower(name)
    if string.find(name,"fertile soil") then return true end
    return false
end

-- ❌ detect mushroom
local function isMushroom(name)
    return string.find(string.lower(name),"mushroom")
end

-- ================= SCAN =================

local function extractNumber(text)
    local n = string.match(text,"%d+")
    return n and tonumber(n)
end

local function scanUI(gui)
    local seeds = {}
    local gear = {}
    local added = {}

    for _,obj in pairs(gui:GetDescendants()) do
        if obj:IsA("Frame") then
            
            local labels = {}
            for _,c in pairs(obj:GetDescendants()) do
                if c:IsA("TextLabel") and c.Text ~= "" then
                    table.insert(labels,c.Text)
                end
            end

            if #labels == 0 then continue end

            local name = ""
            local stock = -1

            -- NAME
            for _,t in ipairs(labels) do
                if string.len(t) > string.len(name) and not tonumber(t) then
                    name = t
                end
            end

            if name == "" then continue end
            if isBlacklisted(name) then continue end

            local mush = isMushroom(name)

            -- STOCK
            for _,t in ipairs(labels) do
                local l = string.lower(t)

                -- 🔥 FIX: bỏ x5 mushroom
                if not mush then
                    if string.match(t,"%d+[xX]") or string.match(t,"[xX]%d+") then
                        stock = extractNumber(t)
                    end
                end

                if string.find(l,"stock") or string.find(l,"left") then
                    stock = extractNumber(t)
                end
            end

            -- 🔥 FIX: không fallback cho mushroom
            if stock == -1 and not mush then
                for _,t in ipairs(labels) do
                    local n = extractNumber(t)
                    if n and n <= 99 then
                        stock = n
                    end
                end
            end

            if stock <= 0 then continue end

            -- CATEGORY
            local lower = string.lower(name)
            local cat = nil

            if string.find(lower,"seed") or string.find(lower,"mushroom") then
                cat = "seed"
            else
                cat = "gear"
            end

            if not added[name] then
                local item = {
                    name = name,
                    quantity = stock,
                    category = cat
                }

                if cat == "seed" then
                    table.insert(seeds,item)
                else
                    table.insert(gear,item)
                end

                added[name] = true
            end
        end
    end

    return seeds,gear
end

-- WEATHER (giữ nguyên đơn giản)
local function getWeather(gui)
    local w = {status="None",duration=0}

    for _,v in pairs(gui:GetDescendants()) do
        if v:IsA("TextLabel") then
            local t = string.lower(v.Text)
            if string.find(t,"rain") then w.status="Rain" end
            if string.find(t,"storm") then w.status="Storm" end
            if string.find(t,"clear") then w.status="Clear" end
        end
    end

    return w
end

-- MAIN
local function getData()
    updateUI("🔍 scanning...")

    local gui = LocalPlayer:WaitForChild("PlayerGui")

    local seeds,gear = scanUI(gui)
    local weather = getWeather(gui)

    updateUI("✅ done","Seeds "..#seeds.." | Gear "..#gear)

    return seeds,gear,weather
end

-- API
local function send()
    local seeds,gear,weather = getData()

    if #seeds == 0 and #gear == 0 then
        updateUI("❌ no shop")
        return
    end

    local body = HttpService:JSONEncode({
        seeds = seeds,
        gear = gear,
        weather = weather,
        time = os.time()
    })

    local req = (syn and syn.request) or request

    if req then
        pcall(function()
            req({
                Url = API_URL,
                Method = "POST",
                Headers = {["Content-Type"]="application/json"},
                Body = body
            })
        end)
        updateUI("✅ sent API")
    end
end

-- LOOP RESTOCK
local function waitNext()
    local t = os.date("!*t")
    local sec = t.sec + (t.min%5)*60
    return 300 - sec
end

task.spawn(function()
    send()
    while true do
        local w = waitNext()
        for i=w,1,-1 do
            updateUI("⏳ "..i.."s")
            task.wait(1)
        end
        send()
    end
end)
