--// CONFIG
local WEBHOOK = "https://discord.com/api/webhooks/1482391815024803963/6V8VLwhL7X1o9FL_n1GNxxsoRH6su1tDzhbxzT4wJe_qr_MGCVaqp1fUs8ZKdnbyyC_H"
local API_URL = ""
local SEND_API = false

--// SERVICES
local HttpService = game:GetService("HttpService")
local JobId = game.JobId

--// GET STOCK
local function getStock()

    local data = {
        server = JobId,
        timestamp = os.time(),
        seed_shop = {},
        gear_shop = {},
        weather = "Unknown"
    }

    -- Seed Shop
    local seedShop = workspace:FindFirstChild("SeedShop")
    if seedShop then
        for _,v in pairs(seedShop:GetChildren()) do
            table.insert(data.seed_shop, v.Name)
        end
    end

    -- Gear Shop
    local gearShop = workspace:FindFirstChild("GearShop")
    if gearShop then
        for _,v in pairs(gearShop:GetChildren()) do
            table.insert(data.gear_shop, v.Name)
        end
    end

    -- Weather
    local weather = workspace:FindFirstChild("Weather")
    if weather then
        data.weather = weather.Value
    end

    return data
end


--// DISCORD WEBHOOK
local function sendWebhook(stock)

    local embed = {
        title = "Garden Horizons Stock",
        color = 5763719,
        fields = {
            {
                name = "Seed Shop",
                value = (#stock.seed_shop > 0 and table.concat(stock.seed_shop,", ")) or "None",
                inline = false
            },
            {
                name = "Gear Shop",
                value = (#stock.gear_shop > 0 and table.concat(stock.gear_shop,", ")) or "None",
                inline = false
            },
            {
                name = "Weather",
                value = stock.weather,
                inline = true
            }
        },
        footer = {
            text = "Server: "..stock.server
        },
        timestamp = DateTime.now():ToIsoDate()
    }

    local payload = {
        embeds = {embed}
    }

    task.spawn(function()
        pcall(function()
            HttpService:PostAsync(
                WEBHOOK,
                HttpService:JSONEncode(payload),
                Enum.HttpContentType.ApplicationJson
            )
        end)
    end)

end


--// SEND API
local function sendAPI(stock)

    task.spawn(function()
        pcall(function()
            HttpService:PostAsync(
                API_URL,
                HttpService:JSONEncode(stock),
                Enum.HttpContentType.ApplicationJson
            )
        end)
    end)

end


--// SYNC TO EXACT 5 MINUTE
local function waitNext()

    local now = os.time()
    local nextTick = math.ceil(now / 300) * 300
    task.wait(nextTick - now)

end


--// LOOP
while true do

    waitNext()

    local stock = getStock()

    sendWebhook(stock)

    if SEND_API then
        sendAPI(stock)
    end

end
