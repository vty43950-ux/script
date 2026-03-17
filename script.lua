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
screenGui.ResetOnSpawn = false

local frame = Instance.new("Frame", screenGui)
frame.Size = UDim2.new(0, 250, 0, 100)
frame.Position = UDim2.new(0, 10, 0, 10)
frame.BackgroundColor3 = Color3.fromRGB(30,30,30)

local statusLabel = Instance.new("TextLabel", frame)
statusLabel.Size = UDim2.new(1,0,0,30)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Loading..."

local infoLabel = Instance.new("TextLabel", frame)
infoLabel.Position = UDim2.new(0,0,0,30)
infoLabel.Size = UDim2.new(1,0,1,-30)
infoLabel.BackgroundTransparency = 1
infoLabel.Text = ""

local function updateUI(status, info)
    statusLabel.Text = status
    if info then infoLabel.Text = info end
end

-------------------------------------------------------------------------------
-- CONFIG
-------------------------------------------------------------------------------
local SEED_NAMES = {"mushroom","carrot","corn","pumpkin","apple","bamboo"}
local GEAR_NAMES = {"shovel","sprinkler","tool"}

local function guessItemCategory(name)
    name = string.lower(name)
    for _,v in ipairs(SEED_NAMES) do
        if string.find(name,v) then return "seed" end
    end
    for _,v in ipairs(GEAR_NAMES) do
        if string.find(name,v) then return "gear" end
    end
end

-------------------------------------------------------------------------------
-- SCAN FIXED
-------------------------------------------------------------------------------
local function scan()
    local seeds, gear = {}, {}
    local seen = {}

    local function process(item)
        local texts = {}
        local stock = nil
        local name = ""

        for _,v in pairs(item:GetDescendants()) do
            if v:IsA("TextLabel") and v.Text ~= "" then
                table.insert(texts, v.Text)
            end
        end

        for _,t in ipairs(texts) do
            local l = string.lower(t)

            -- ✅ CHỈ lấy stock khi có keyword rõ ràng
            if string.find(l,"stock") or string.find(l,"left") or string.find(l,"remain")
            or string.match(t,"^%d+[xX]$") or string.match(t,"^[xX]%d+$") then

                local n = tonumber(string.match(t,"%d+"))
                if n and n > 0 then
                    stock = n
                end
            end

            -- name
            if #t > #name and not tonumber(t) then
                name = t
            end
        end

        -- ❌ nếu không có stock rõ ràng → bỏ luôn (fix lỗi 5)
        if not stock or stock <= 0 then return end

        local cat = guessItemCategory(name)
        if not cat then return end

        local key = name.."_"..stock
        if seen[key] then return end
        seen[key] = true

        local data = {name=name,quantity=stock}

        if cat=="seed" then
            table.insert(seeds,data)
        else
            table.insert(gear,data)
        end
    end

    for _,v in pairs(LocalPlayer.PlayerGui:GetDescendants()) do
        if v:IsA("Frame") then
            process(v)
        end
    end

    return seeds, gear
end

-------------------------------------------------------------------------------
-- API
-------------------------------------------------------------------------------
local function send()
    updateUI("Scanning...")

    local seeds, gear = scan()

    if #seeds==0 and #gear==0 then
        updateUI("No data","Open shop!")
        return
    end

    local data = {
        seeds = seeds,
        gear = gear,
        time = os.time()
    }

    local req = (syn and syn.request) or request

    if req then
        req({
            Url = API_URL,
            Method = "POST",
            Headers = {["Content-Type"]="application/json"},
            Body = HttpService:JSONEncode(data)
        })
    end

    updateUI("Done", "Seeds: "..#seeds.." | Gear: "..#gear)
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
