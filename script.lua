local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local API_URL = "https://zenithghz.qzz.io/api/update"

-------------------------------------------------------------------------------
-- UI
-------------------------------------------------------------------------------
local uiLayer = (gethui and gethui()) or CoreGui

if uiLayer:FindFirstChild("GHZ_Tracker_UI") then
    uiLayer["GHZ_Tracker_UI"]:Destroy()
end

local screenGui = Instance.new("ScreenGui", uiLayer)
screenGui.Name = "GHZ_Tracker_UI"

local frame = Instance.new("Frame", screenGui)
frame.Size = UDim2.new(0, 260, 0, 110)
frame.Position = UDim2.new(0, 10, 0, 10)
frame.BackgroundColor3 = Color3.fromRGB(25,25,25)

local statusLabel = Instance.new("TextLabel", frame)
statusLabel.Size = UDim2.new(1,0,0,30)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Loading..."

local infoLabel = Instance.new("TextLabel", frame)
infoLabel.Position = UDim2.new(0,0,0,30)
infoLabel.Size = UDim2.new(1,0,1,-30)
infoLabel.BackgroundTransparency = 1

local function updateUI(status, info)
    statusLabel.Text = status
    if info then infoLabel.Text = info end
end

-------------------------------------------------------------------------------
-- CONFIG
-------------------------------------------------------------------------------
local BLACKLIST = {
    "fertile soil","soil","reward","xp","level","quest","free","bonus"
}

local function isBlacklisted(name)
    local n = string.lower(name)
    for _,b in ipairs(BLACKLIST) do
        if string.find(n,b) then
            return true
        end
    end
end

-------------------------------------------------------------------------------
-- WEATHER SCAN
-------------------------------------------------------------------------------
local function scanWeather()
    local weather = {
        status = "None",
        duration = 0
    }

    local keywords = {
        "rain","storm","sunny","cloudy","windy","snow","meteor","starfall"
    }

    for _,obj in pairs(LocalPlayer.PlayerGui:GetDescendants()) do
        if obj:IsA("TextLabel") then
            local txt = string.lower(obj.Text)

            for _,kw in ipairs(keywords) do
                if string.find(txt, kw) then
                    weather.status = kw

                    -- tìm duration
                    local m,s = string.match(obj.Text, "(%d+):(%d+)")
                    if m and s then
                        weather.duration = tonumber(m)*60 + tonumber(s)
                    end

                    return weather
                end
            end
        end
    end

    return weather
end

-------------------------------------------------------------------------------
-- SCAN SHOP (FIXED MUSHROOM)
-------------------------------------------------------------------------------
local function scan()
    local seeds, gear = {}, {}
    local seen = {}

    local function process(item)
        local texts = {}
        local name = ""
        local stock = nil

        for _,v in pairs(item:GetDescendants()) do
            if v:IsA("TextLabel") and v.Visible and v.Text ~= "" then
                table.insert(texts, v.Text)
            end
        end

        if #texts == 0 then return end

        for _,t in ipairs(texts) do
            local l = string.lower(t)

            -------------------------------------------------------------------
            -- ✅ CHỈ lấy stock khi có keyword (FIX X5)
            -------------------------------------------------------------------
            if string.find(l,"stock") 
            or string.find(l,"left") 
            or string.find(l,"remain") then

                local num = tonumber(string.match(t,"%d+"))
                if num and num > 0 and num <= 100 then
                    stock = num
                end
            end

            -------------------------------------------------------------------
            -- NAME
            -------------------------------------------------------------------
            if #t > #name 
            and not tonumber(t)
            and not string.find(l,"stock") then
                name = t
            end
        end

        -- ❌ không có stock → bỏ
        if not stock then return end

        -- ❌ chặn mushroom bug x5
        if string.find(string.lower(name),"mushroom") and stock == 5 then
            return
        end

        -- ❌ blacklist
        if isBlacklisted(name) then return end

        local key = name.."_"..stock
        if seen[key] then return end
        seen[key] = true

        local data = {
            name = name,
            quantity = stock
        }

        -- phân loại đơn giản
        if string.find(string.lower(name),"seed") then
            table.insert(seeds,data)
        else
            table.insert(gear,data)
        end
    end

    ---------------------------------------------------------------------------
    -- ✅ chỉ scan SHOP thật (có layout)
    ---------------------------------------------------------------------------
    for _,container in pairs(LocalPlayer.PlayerGui:GetDescendants()) do
        if (container:IsA("Frame") or container:IsA("ScrollingFrame")) then
            
            if container:FindFirstChildOfClass("UIGridLayout")
            or container:FindFirstChildOfClass("UIListLayout") then

                for _,child in pairs(container:GetChildren()) do
                    process(child)
                end
            end
        end
    end

    return seeds, gear
end

-------------------------------------------------------------------------------
-- API SEND
-------------------------------------------------------------------------------
local function send()
    updateUI("🔍 Scanning...")

    local seeds, gear = scan()
    local weather = scanWeather()

    if #seeds == 0 and #gear == 0 and weather.status == "None" then
        updateUI("⚠️ No data", "Open Shop!")
        return
    end

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

    updateUI("✅ Done",
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
