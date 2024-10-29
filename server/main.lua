ESX = exports['es_extended']:getSharedObject()
PlayersHarvesting  = {}
MarketPrices = {}

TriggerEvent('esx_phone:registerNumber', 'foodtruck', 'Client FoodTruck', false, false)
TriggerEvent('esx_society:registerSociety', 'foodtruck', 'Foodtruck', 'society_foodtruck', 'society_foodtruck', 'society_foodtruck', {type = 'public'})

if Config.MaxInService ~= -1 then
	TriggerEvent('esx_service:activateService', 'foodtruck', Config.MaxInService)
end

-- Initialize MarketPrices table and ready status
local MarketPrices = {}
local MarketPricesReady = false

local function fetchMarketPrices()
    -- Define the query for shops
    local shopsQuery = "SELECT * FROM `shops` WHERE `store` = 'Market'"
    -- Define the query for items
    local itemsQuery = "SELECT * FROM `items`"

    -- Check if oxmysql is available
    if MySQL then
        -- Using oxmysql
        MySQL.ready(function()
            print('onMySQLReady (oxmysql)')
            MySQL.Async.fetchAll(shopsQuery, {}, function(result)
                print("Shops Result: ", json.encode(result))  -- Debugging line

                MySQL.Async.fetchAll(itemsQuery, {}, function(result2)
                    print("Items Result: ", json.encode(result2))  -- Debugging line

                    for i=1, #result2, 1 do
                        for j=1, #result, 1 do
                            if result[j].item == result2[i].name then
                                table.insert(MarketPrices, {label = result2[i].label, item = result[j].item, price = result[j].price})
                                break
                            end
                        end
                    end
                    MarketPricesReady = true  -- Set to true once MarketPrices is populated
                    print("MarketPrices Loaded: ", json.encode(MarketPrices))  -- Debugging line
                end)
            end)
        end)

    else
        -- Fallback to mysql-async
        print('Using mysql-async')
        MySQL.Async.fetchAll(shopsQuery, {}, function(result)
            print("Shops Result: ", json.encode(result))  -- Debugging line

            MySQL.Async.fetchAll(itemsQuery, {}, function(result2)
                print("Items Result: ", json.encode(result2))  -- Debugging line

                for i=1, #result2, 1 do
                    for j=1, #result, 1 do
                        if result[j].item == result2[i].name then
                            table.insert(MarketPrices, {label = result2[i].label, item = result[j].item, price = result[j].price})
                            break
                        end
                    end
                end
                MarketPricesReady = true  -- Set to true once MarketPrices is populated
                print("MarketPrices Loaded: ", json.encode(MarketPrices))  -- Debugging line
            end)
        end)
    end
end

-- Call the fetch function to initialize the MarketPrices
fetchMarketPrices()

ESX.RegisterServerCallback('esx_foodtruck:getStock', function(source, cb)
    if MarketPricesReady then
        local xPlayer = ESX.GetPlayerFromId(source)
        local fridge = {}

        -- Check the player's inventory against the fridge configuration
        for k, v in pairs(Config.Fridge) do
            local itemFound = false
            for i = 1, #xPlayer.inventory, 1 do
                if xPlayer.inventory[i].name == k then
                    table.insert(fridge, xPlayer.inventory[i])
                    itemFound = true
                    break
                end
            end
            
            -- If no items were found in the player's inventory, return 0 for this item
            if not itemFound then
                table.insert(fridge, { name = k, count = 0 })
            end
        end
        
        -- If fridge is empty, return a zero or empty table
        if #fridge == 0 then
            cb({}, MarketPrices)  -- Return an empty fridge
        else
            cb(fridge, MarketPrices)  -- Return the populated fridge
        end
    else
        print("MarketPrices not ready. Retrying...")  -- Debugging line
        Citizen.Wait(100)  -- Wait and retry if MarketPrices isn't ready
        TriggerEvent('esx_foodtruck:getStock', source, cb)
    end
end)

RegisterServerEvent('esx_foodtruck:buyItem')
AddEventHandler('esx_foodtruck:buyItem', function(qtty, item)
	print("esx_foodtruck:buyItem", qtty, item)
    local _source = source	
    local xPlayer = ESX.GetPlayerFromId(_source)
    
    local max = 10  -- Define your maximum allowable quantity
    local stock = 100  -- Define the stock available; retrieve this based on your business logic

    for i = 1, #MarketPrices, 1 do
        if item == MarketPrices[i].item then
            if qtty == -1 then -- For 'buy max' option
                local delta = max - stock  -- Adjust based on your logic for stock retrieval
                local total = MarketPrices[i].price * delta
                
                if xPlayer.getMoney() >= total then
                    xPlayer.addInventoryItem(item, delta)
                    xPlayer.removeMoney(total)
                    TriggerClientEvent('esx:showNotification', _source, _U('purchased'))
                else
                    TriggerClientEvent('esx:showNotification', _source, _U('no_money'))
                end
            else
                local total = MarketPrices[i].price * qtty
                
                if xPlayer.getMoney() >= total then
                    xPlayer.addInventoryItem(item, qtty)
                    xPlayer.removeMoney(total)
                    TriggerClientEvent('esx:showNotification', _source, _U('purchased'))
                else
                    TriggerClientEvent('esx:showNotification', _source, _U('no_money'))
                end
            end
            break
        end
    end
	
    TriggerClientEvent('esx_foodtruck:refreshMarket', _source)
end)

RegisterServerEvent('esx_foodtruck:removeItem')
AddEventHandler('esx_foodtruck:removeItem', function(item, count)
	local _source = source
	local xPlayer = ESX.GetPlayerFromId(_source)
	xPlayer.removeInventoryItem(item, count)
end)

RegisterServerEvent('esx_foodtruck:addItem')
AddEventHandler('esx_foodtruck:addItem', function(item, count)
	local _source = source
	local xPlayer = ESX.GetPlayerFromId(_source)
	xPlayer.addInventoryItem(item, count)
end)

---------------------------- register usable item --------------------------------------------------
ESX.RegisterUsableItem('cola', function(source)
	local xPlayer = ESX.GetPlayerFromId(source)
	xPlayer.removeInventoryItem('cola', 1)
	TriggerClientEvent('esx_status:add', source, 'thirst', 300000)
	TriggerClientEvent('esx_basicneeds:onDrink', source, 'prop_ecola_can')
    TriggerClientEvent('esx:showNotification', source, _U('drank_coke'))
end)

ESX.RegisterUsableItem('burger', function(source)
	local xPlayer = ESX.GetPlayerFromId(source)
	xPlayer.removeInventoryItem('burger', 1)
	TriggerClientEvent('esx_status:add', source, 'hunger', 300000)
	TriggerClientEvent('esx_basicneeds:onEat', source, 'prop_cs_burger_01')
    TriggerClientEvent('esx:showNotification', source, _U('eat_burger'))
end)

ESX.RegisterUsableItem('tacos', function(source)
	local xPlayer = ESX.GetPlayerFromId(source)
	xPlayer.removeInventoryItem('tacos', 1)
	TriggerClientEvent('esx_status:add', source, 'hunger', 500000)
	TriggerClientEvent('esx_basicneeds:onEat', source, 'prop_taco_01')
    TriggerClientEvent('esx:showNotification', source, _U('eat_taco'))
end)
