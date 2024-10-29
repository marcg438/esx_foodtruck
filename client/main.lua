ESX = exports['es_extended']:getSharedObject()
local PlayerData, CurrentActionData = {}, {}
local LastZone, CurrentAction, CurrentActionMsg, FoodInPlace
local OnJob, Cooking, HasAlreadyEnteredMarker = false, false, false
local spawnedProps = {}

function PlaceProp(propModel)
	local playerPed = GetPlayerPed(-1)
    -- Check if the player is in any vehicle
    if IsPedInAnyVehicle(playerPed, false) then
        return
    end

	-- Get the model hash of the prop we want to spawn
	local modelHash = GetHashKey(propModel)
	
	-- Check if the prop already exists in `spawnedProps`
	for _, prop in ipairs(spawnedProps) do
		if DoesEntityExist(prop) and GetEntityModel(prop) == modelHash then
			print(("Prop already exists: %s"):format(propModel))
			return  -- Exit the function if the prop already exists
		end
	end

	-- If we reach here, the prop doesn't exist yet, so we can spawn itssa
	local playerPed = GetPlayerPed(-1)
	local playerCoords = GetEntityCoords(playerPed)

	if not HasModelLoaded(modelHash) then
		-- If the model isnt loaded we request the loading of the model and wait that the model is loaded
		RequestModel(modelHash)
	
		while not HasModelLoaded(modelHash) do
			Citizen.Wait(1)
		end
	end

	-- Calculate the offset in front of the player
	local offsetDistance = 1.0  -- Distance in front of the player
	local heading = GetEntityHeading(playerPed) + 180
	local x, y, z   = table.unpack(playerCoords)
	local xOffset = GetEntityForwardX(playerPed) * offsetDistance
	local yOffset = GetEntityForwardY(playerPed) * offsetDistance


	-- Create the new prop object
	local prop = CreateObject(modelHash, playerCoords.x + xOffset, playerCoords.y + yOffset, playerCoords.z, true, true, true)


	if prop and DoesEntityExist(prop) then
		PlaceObjectOnGroundProperly(prop)
		  -- Turn the object around by 180 degrees
		  local newHeading = heading + 180
		  if newHeading >= 360 then
			  newHeading = newHeading - 360  -- Ensure heading wraps around
		  end
		  SetEntityHeading(prop, newHeading)  -- Align the prop's heading with the player's, plus 180 degrees
		print("Prop created with handle:", prop)
		table.insert(spawnedProps, prop)
	else
		print("Error: Prop creation failed.")
	end
end

function RemoveProp(propToRemove)
	local playerPed = GetPlayerPed(-1)
	-- Make sure the player is not in a car
	if IsPedInAnyVehicle(playerPed, true) then
		return
	end
    -- Ensure the prop to remove is valid and exists
    if propToRemove and DoesEntityExist(propToRemove) then
        for i, prop in ipairs(spawnedProps) do
            if prop == propToRemove then
                print(("Removing prop: %s"):format(propToRemove))
                DeleteEntity(propToRemove)  -- Remove the prop from the game world
                table.remove(spawnedProps, i)  -- Remove the prop from the `spawnedProps` list
                ESX.ShowNotification(_U('cleaned'))  -- Confirmation notification
                return  -- Exit the function once the prop is found and deleted
            end
        end
    else
        print("Error: Invalid or nonexistent prop passed to RemoveProp function.")
    end
end

function OpenCookingMenu(grill)
	local elements = {
		head = {_U('recipe'), _U('ingredients'), _U('action')},
		rows = {}
	}

	for k,v in pairs(Config.Recipes) do
		local ingredients = ""

		for l,w in pairs(v.Ingredients) do
			ingredients = ingredients .. " - " .. w[1] .. " (" .. w[2] .. ")"
		end

		table.insert(elements.rows,
		{
			data = v,
			cols = {
				v.Name,
				ingredients,
				'{{' .. _U('cook') .. '|cook}}'
			}
		})
	end

	ESX.UI.Menu.Open('list', GetCurrentResourceName(), 'foodtruck',
		elements,
		function(data, menu)
			if data.value == 'cook' then
				if not Cooking then					
					ESX.TriggerServerCallback('esx_foodtruck:getStock', function(fridge)
						local enoughStock = false
						for k,v in pairs(data.data.Ingredients) do
							--TriggerServerEvent('esx:clientLog', 'in recipe looking at ' .. k)
							for i=1, #fridge, 1 do
								--TriggerServerEvent('esx:clientLog', 'in fridge looking at ' .. fridge[i].name)
								if fridge[i].name == k then
									--TriggerServerEvent('esx:clientLog', 'enough ?')
									if fridge[i].count >= v[2] then
										--TriggerServerEvent('esx:clientLog', 'enough ' .. k)
										enoughStock = true
									else
										--TriggerServerEvent('esx:clientLog', 'not enough ' .. k)
										enoughStock = false
									end
									break
								end
							end
							if not enoughStock then
								break
							end
						end
						if enoughStock then
							for k,v in pairs(data.data.Ingredients) do
								TriggerServerEvent('esx_foodtruck:removeItem', k, v[2])
							end
							Cooking = true						

							local coords  = GetEntityCoords(grill)
							local x, y, z = table.unpack(coords)

							ESX.Game.SpawnObject('prop_cs_steak', {
								x = x,
								y = y,
								z = z + 0.93
							}, function(steak)

								ESX.SetTimeout(data.data.CookingTime, function()

									DeleteEntity(steak)

									ESX.ShowNotification(_U('cooked'))

									local xF 		= GetEntityForwardX(grill) * 1.0
									local yF 		= GetEntityForwardY(grill) * 1.0

									local model = nil

									if data.data.Item == 'tacos' then
										model = 'prop_taco_01'
									elseif data.data.Item == 'burger' then
										model = 'prop_cs_burger_01'
									end

									local heading = GetEntityHeading(grill)

									local foodDistance = 0.7

									local angle = heading * math.pi / 180.0
									local theta = {
										x = math.cos(angle),
										y = math.sin(angle)
									}
									local pos = {
										x = coords.x + (foodDistance * theta.x),
										y = coords.y + (foodDistance * theta.y),
									}

									ESX.Game.SpawnObject(model, {
										x = pos.x,
										y = pos.y,
										z = z + 0.93
									}, function(food)
										local id = NetworkGetNetworkIdFromEntity(food)
										--TriggerServerEvent('esx:clientLog', 'creating entity netID: ' .. tostring(id))
										TriggerServerEvent('esx_foodtruck:placeFood', id)
										SetNetworkIdCanMigrate(id, true)
										FoodInPlace = food
									end)

									Cooking = false
								end)
							end)
							
						else
							ESX.ShowNotification(_U('missing_ingredients'))
						end
					end)
				else
					ESX.ShowNotification(_U('already_cooking'))
				end
			end
			menu.close()
			CurrentAction     = 'foodtruck_cook'
			CurrentActionMsg  = _U('start_cooking_hint')
			CurrentActionData = {}
		end, function(data, menu)

			menu.close()
			CurrentAction     = 'foodtruck_cook'
			CurrentActionMsg  = _U('start_cooking_hint')
			CurrentActionData = {}
		end)
end

function OpenFoodTruckActionsMenu()
	local elements = {
		{label = _U('vehicle_list'), 	value = 'vehicle_list'},
		{label = _U('job_clothes'), 	value = 'cloakroom'},
		{label = _U('civil'), 			value = 'cloakroom2'}
	}

	if PlayerData.job ~= nil and PlayerData.job.grade_name == 'boss' then
  		table.insert(elements, {label = _U('boss_actions'), value = 'boss_actions'})
	end

	ESX.UI.Menu.CloseAll()

	ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'foodtruck_actions', {
			title    = _U('blip_foodtruck'),
			elements = elements
		}, function(data, menu)

			if data.current.value == 'vehicle_list' then
				local elements = {
					{label = 'FoodTruck', value = 'taco'}
				}

				ESX.UI.Menu.CloseAll()

				ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'spawn_vehicle', {
						title    = _U('vehicles'),
						elements = elements
					}, function(data, menu)

						local playerPed = GetPlayerPed(-1)
						local coords    = Config.Zones.VehicleSpawnPoint.Pos
						ESX.Game.SpawnVehicle(data.current.value, coords, 230.0, function(vehicle)
							TaskWarpPedIntoVehicle(playerPed, vehicle, -1)
						end)	
						ESX.UI.Menu.CloseAll()
					end,function(data, menu)
						menu.close()
					end)
			end

			if data.current.value == 'cloakroom' then
				menu.close()
				ESX.TriggerServerCallback('esx_skin:getPlayerSkin', function(skin, jobSkin)
    				if skin.sex == 0 then
        				TriggerEvent('skinchanger:loadClothes', skin, jobSkin.skin_male)
    				else
        				TriggerEvent('skinchanger:loadClothes', skin, jobSkin.skin_female)
    				end    
				end)
			end

			if data.current.value == 'cloakroom2' then
				menu.close()
				ESX.TriggerServerCallback('esx_skin:getPlayerSkin', function(skin, jobSkin)
    				TriggerEvent('skinchanger:loadSkin', skin)    
				end)
			end

			if data.current.value == 'boss_actions' then

                TriggerEvent('esx_society:openBossMenu', 'foodtruck', function(data, menu)
                    menu.close()
                end)
            end
		end, function(data, menu)
			menu.close()
			CurrentAction     = 'foodtruck_actions_menu'
			CurrentActionMsg  = _U('foodtruck_actions_menu')
			CurrentActionData = {}
		end)
end

RegisterNetEvent('esx_foodtruck:refreshMarket')
AddEventHandler('esx_foodtruck:refreshMarket', function()
	OpenFoodTruckMarketMenu()
end)

function OpenFoodTruckMarketMenu()
	if PlayerData.job ~= nil and PlayerData.job.grade_name == 'boss' then
		ESX.TriggerServerCallback('esx_foodtruck:getStock', function(fridge, MarketPrices)
			local elements = {
				head = {_U('ingredients'), _U('price_unit'), _U('on_you'), _U('action')},
				rows = {}
			}

			for j=1, #MarketPrices, 1 do
				for i=1, #fridge, 1 do
					if fridge[i].name == MarketPrices[j].item then
						table.insert(elements.rows, {
							data = fridge[i],
							cols = {
								MarketPrices[j].label,
								MarketPrices[j].price,
								tostring(fridge[i].count),
								'{{' .. _U('buy_10') .. '|buy10}} {{' .. _U('buy_50') .. '|buy50}}'
							}
						})
						break
					end
				end
			end


			for i, item in ipairs(MarketPrices) do
				table.insert(elements.rows, {
					data = item,
					cols = {
						item.label,
						item.price
					}
				})
			end

			ESX.UI.Menu.CloseAll()
			ESX.UI.Menu.Open('list', GetCurrentResourceName(), 'foodtruck', elements,
            function(data, menu)
                if data.value == 'buy10' then
                    TriggerServerEvent('esx_foodtruck:buyItem', 10, data.data.name)
				elseif data.value == 'buy50' then
					TriggerServerEvent('esx_foodtruck:buyItem', 50, data.data.name)
				end
                end,
				function(data, menu)
					menu.close()
					CurrentAction     = 'foodtruck_market_menu'
					CurrentActionMsg  = _U('foodtruck_market_menu')
					CurrentActionData = {}
				end)
			-- ESX.UI.Menu.Open('list', GetCurrentResourceName(), 'foodtruck', elements,
			-- 	function(data, menu)
			-- 		if data.value == 'buy10' then
			-- 			TriggerServerEvent('esx_foodtruck:buyItem', 10, data.data.name)
			-- 		elseif data.value == 'buy50' then
			-- 			TriggerServerEvent('esx_foodtruck:buyItem', 50, data.data.name)
			-- 		end
			-- 		menu.close()
			-- 	end,
			-- 	function(data, menu)
			-- 		menu.close()
			-- 		CurrentAction     = 'foodtruck_market_menu'
			-- 		CurrentActionMsg  = _U('foodtruck_market_menu')
			-- 		CurrentActionData = {}
			-- 	end)
		end)
	else
		ESX.ShowNotification(_U('need_more_exp'))
	end
end


function OpenFoodTruckBilling()
	ESX.UI.Menu.Open('dialog', GetCurrentResourceName(), 'billing', {
			title = _U('bill_amount')
		}, function(data, menu)

			local amount = tonumber(data.value)

			if amount == nil then
				ESX.ShowNotification(_U('invalid_amount'))
			else							
				menu.close()							
				local closestPlayer, closestDistance = ESX.Game.GetClosestPlayer()
				if closestPlayer == -1 or closestDistance > 3.0 then
					ESX.ShowNotification(_U('no_player_nearby'))
				else
					TriggerServerEvent('esx_billing:sendBill', GetPlayerServerId(closestPlayer), 'society_foodtruck', 'RasTacos', amount)
				end
			end
		end, function(data, menu)
		menu.close()
	end)
end

function OpenMobileFoodTruckActionsMenu()

	ESX.UI.Menu.CloseAll()

	ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'mobile_foodtruck_actions', {
			title    = _U('blip_foodtruck'),
			align    = 'top-left',
			elements = {
				{label = _U('billing'), 	value = 'billing'},
				{label = _U('gears'), 	value = 'gears'}
			}
		}, function(data, menu)
			if data.current.value == 'billing' then
				OpenFoodTruckBilling()
			elseif data.current.value == 'cook' then
				OpenCookingMenu()
			elseif data.current.value == 'gears' then
				ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'foodtruck_gears', {
						title    = _U('gears'),
						align    = 'top-left',
						elements = {
							{label = _U('grill'), 	value = 'prop_bbq_5'},
							{label = _U('table'), 	value = 'prop_table_para_comb_02'},
							{label = _U('chair'), 	value = 'prop_table_03_chr'}, --'prop_cs_steak'prop_table_03_chr
		  					{label = _U('clean'),   value = 'clean'}
						},
					}, function(data2, menu2)
						local playerPed = GetPlayerPed(-1)
						local playerCoords = GetEntityCoords(playerPed)							
						if data2.current.value ~= 'clean' then
							local x, y, z   = table.unpack(playerCoords)
							local xF = GetEntityForwardX(playerPed) * 1.0
							local yF = GetEntityForwardY(playerPed) * 1.0
							PlaceProp(data2.current.value)
							-- ESX.Game.SpawnObject(data2.current.value, {
							-- 	x = x + xF,
							-- 	y = y + yF,
							-- 	z = z
							-- }, function(obj)
							-- end)

							menu2.close()
						else
							local objectModels = {'prop_bbq_5', 'prop_table_para_comb_02', 'prop_table_03_chr'}  -- List of object models

							local objectNames = {
								[GetHashKey('prop_bbq_5')] = 'prop_bbq_5',
								[GetHashKey('prop_table_para_comb_02')] = 'prop_table_para_comb_02',
								[GetHashKey('prop_table_03_chr')] = 'prop_table_03_chr',
							}

							local closestObject = nil
							local closestDistance = 1.5
	
								for modelHash, modelName in pairs(objectNames) do
									local object = GetClosestObjectOfType(playerCoords.x, playerCoords.y, playerCoords.z, 1.5, modelHash, false, false, false)
									if DoesEntityExist(object) then
										local objCoords = GetEntityCoords(object)
										local dist = #(playerCoords - objCoords)   -- Explicit distance calculation
										if dist < closestDistance then
											closestObject, closestDistance = object, dist
										end
									end
								end
								if closestObject and closestDistance < 1.5 then  -- Ensure proximity check
								RemoveProp(closestObject)
							else
								ESX.ShowNotification(_U('clean_too_far'))  -- Notify if no object is found nearby
							end
						end
					end, function(data3, menu3)
						menu3.close()
					end)
			end
		end, function(data, menu)
			menu.close()
		end)
end

RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function(xPlayer)
	PlayerData = xPlayer
end)

RegisterNetEvent('esx:setJob')
AddEventHandler('esx:setJob', function(job)
	PlayerData.job = job
end)

AddEventHandler('esx_foodtruck:hasEnteredMarker', function(zone)
	Citizen.Trace('zone: ' .. zone)
	if zone == 'Actions' then
		CurrentAction     = 'foodtruck_actions_menu'
		CurrentActionMsg  = _U('foodtruck_menu')
		CurrentActionData = {}
	end
	if zone == 'Market' then
		CurrentAction     = 'foodtruck_market'
		CurrentActionMsg  = _U('foodtruck_market_menu')
		CurrentActionData = {}
	end
	if zone == 'VehicleDeleter' then
		local playerPed = GetPlayerPed(-1)
		if IsPedInAnyVehicle(playerPed,  false) then
			CurrentAction     = 'delete_vehicle'
			CurrentActionMsg  = _U('store_veh')
			CurrentActionData = {}
		end
	end
end)

AddEventHandler('esx_foodtruck:hasExitedMarker', function(zone)
	CurrentAction = nil
	ESX.UI.Menu.CloseAll()
end)

RegisterNetEvent('esx_phone:loaded')
AddEventHandler('esx_phone:loaded', function(phoneNumber, contacts)
	local specialContact = {
		name       = _U('blip_foodtruck'),
		number     = 'foodtruck',
		base64Icon = 'data:image/png;base64,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'
	}
	TriggerEvent('esx_phone:addSpecialContact', specialContact.name, specialContact.number, specialContact.base64Icon)
end)

-- Create Blips
Citizen.CreateThread(function()		
	local blip = AddBlipForCoord(Config.Zones.Actions.Pos.x, Config.Zones.Actions.Pos.y, Config.Zones.Actions.Pos.z)
	SetBlipSprite (blip, 479)
	SetBlipDisplay(blip, 4)
	SetBlipScale  (blip, 1.0)
	SetBlipColour (blip, 5)
	SetBlipAsShortRange(blip, true)
	BeginTextCommandSetBlipName("STRING")
	AddTextComponentString(_U('blip_foodtruck'))
	EndTextCommandSetBlipName(blip)

	blip = AddBlipForCoord(Config.Zones.Market.Pos.x, Config.Zones.Market.Pos.y, Config.Zones.Market.Pos.z)
	SetBlipSprite (blip, 52)
	SetBlipDisplay(blip, 4)
	SetBlipScale  (blip, 1.0)
	SetBlipColour (blip, 5)
	SetBlipAsShortRange(blip, true)
	BeginTextCommandSetBlipName("STRING")
	AddTextComponentString(_U('blip_market'))
	EndTextCommandSetBlipName(blip)
end)

-- Display markers
Citizen.CreateThread(function()
	while true do
		Wait(0)
		if PlayerData.job ~= nil and PlayerData.job.name == 'foodtruck' then
			local coords = GetEntityCoords(GetPlayerPed(-1))

			for k,v in pairs(Config.Zones) do
				if(v.Type ~= -1 and GetDistanceBetweenCoords(coords, v.Pos.x, v.Pos.y, v.Pos.z, true) < Config.DrawDistance) then
					DrawMarker(v.Type, v.Pos.x, v.Pos.y, v.Pos.z, 0.0, 0.0, 0.0, 0, 0.0, 0.0, v.Size.x, v.Size.y, v.Size.z, v.Color.r, v.Color.g, v.Color.b, 100, false, true, 2, false, false, false, false)
				end
			end
		end
	end
end)

-- Enter / Exit marker events
Citizen.CreateThread(function()
	while true do
		Wait(0)
		if PlayerData.job ~= nil and PlayerData.job.name == 'foodtruck' then
			local coords      = GetEntityCoords(GetPlayerPed(-1))
			local isInMarker  = false
			local currentZone = nil
			for k,v in pairs(Config.Zones) do
				if(GetDistanceBetweenCoords(coords, v.Pos.x, v.Pos.y, v.Pos.z, true) < v.Size.x) then
					isInMarker  = true
					currentZone = k
				end
			end
			if (isInMarker and not HasAlreadyEnteredMarker) or (isInMarker and LastZone ~= currentZone) then
				HasAlreadyEnteredMarker = true
				LastZone                = currentZone
				TriggerEvent('esx_foodtruck:hasEnteredMarker', currentZone)
			end
			if not isInMarker and HasAlreadyEnteredMarker then
				HasAlreadyEnteredMarker = false
				TriggerEvent('esx_foodtruck:hasExitedMarker', LastZone)
			end
		end
	end
end)

AddEventHandler('esx_foodtruck:hasEnteredEntityZone', function(entity)

	if PlayerData.job ~= nil and PlayerData.job.name == 'foodtruck' then

		if GetEntityModel(entity) == GetHashKey('prop_bbq_5') then
			CurrentAction     = 'foodtruck_cook'
			CurrentActionMsg  = _U('start_cooking_hint')
			CurrentActionData = {entity = entity}
		end

		if GetEntityModel(entity) == GetHashKey('prop_cs_burger_01') then
			CurrentAction     = 'foodtruck_client_burger'
			CurrentActionMsg  = _U('take') .. ' ' .. _U('burger')
			CurrentActionData = {entity = entity, item = 'burger'}
		end

		if GetEntityModel(entity) == GetHashKey('prop_taco_01') then
			CurrentAction     = 'foodtruck_client_tacos'
			CurrentActionMsg  = _U('take') .. ' ' .. _U('tacos')
			CurrentActionData = {entity = entity, item = 'tacos'}
		end

	end

end)

AddEventHandler('esx_foodtruck:hasExitedEntityZone', function(entity)
	CurrentAction = nil
end)

-- Enter / Exit entity zone events
Citizen.CreateThread(function()

	local trackedEntities = {
		'prop_bbq_5',
		'prop_table_para_comb_02',
		'prop_table_03_chr',
		'prop_cs_burger_01',
		'prop_taco_01'
	}

	while true do

		Citizen.Wait(0)

		local playerPed = GetPlayerPed(-1)
		local coords    = GetEntityCoords(playerPed)

		local closestDistance = -1
		local closestEntity   = nil

		for i=1, #trackedEntities, 1 do

			local object = GetClosestObjectOfType(coords.x,  coords.y,  coords.z,  3.0,  GetHashKey(trackedEntities[i]), false, false, false)

			if DoesEntityExist(object) then

				local objCoords = GetEntityCoords(object)
				local distance  = GetDistanceBetweenCoords(coords.x,  coords.y,  coords.z,  objCoords.x,  objCoords.y,  objCoords.z,  true)

				if closestDistance == -1 or closestDistance > distance then
					closestDistance = distance
					closestEntity   = object
				end
			end
		end

		if closestDistance ~= -1 and closestDistance <= 3.0 then

 			if LastEntity ~= closestEntity then
 				TriggerEvent('esx_basicneeds:isEating', function(isEating)
 					if not isEating then
						TriggerEvent('esx_foodtruck:hasEnteredEntityZone', closestEntity)
					end
				end)
				LastEntity = closestEntity
			end

		else

			if LastEntity ~= nil then
				TriggerEvent('esx_foodtruck:hasExitedEntityZone', LastEntity)
				LastEntity = nil
			end
		end
	end
end)

-- Key Controls
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        if CurrentAction ~= nil then
            SetTextComponentFormat('STRING')
            AddTextComponentString(CurrentActionMsg)
            DisplayHelpTextFromStringLabel(0, 0, 1, -1)
            
            if IsControlJustReleased(0, 38) and PlayerData.job ~= nil and PlayerData.job.name == 'foodtruck' then

            	--TriggerServerEvent('esx:clientLog', 'PUSHING E')
                if CurrentAction == 'foodtruck_actions_menu' then
                    OpenFoodTruckActionsMenu()
                elseif CurrentAction == 'foodtruck_market' then
                    OpenFoodTruckMarketMenu()
                elseif CurrentAction == 'foodtruck_cook' then
                    OpenCookingMenu(CurrentActionData.entity)
                elseif CurrentAction == 'delete_vehicle' then
                    local playerPed = GetPlayerPed(-1)
                    local vehicle   = GetVehiclePedIsIn(playerPed,  false)
                    local hash      = GetEntityModel(vehicle)
                    if hash == GetHashKey('taco') then
                        if Config.MaxInService ~= -1 then
                            TriggerServerEvent('esx_service:disableService', 'foodtruck')
                        end
                        DeleteVehicle(vehicle)
                    else
                        ESX.ShowNotification(_U('wrong_veh'))
                    end
                elseif CurrentAction == 'foodtruck_client_burger' or CurrentAction == 'foodtruck_client_tacos' or CurrentAction == 'foodtruck_client_makiriime' then
                    --TriggerServerEvent('esx_foodtruck:removeFood', CurrentActionData.item)
                    TriggerServerEvent('esx_foodtruck:addItem', CurrentActionData.item, 1)
                    ESX.Game.DeleteObject(FoodInPlace)
                    FoodInPlace = nil
                end

                CurrentAction = nil
            end
        end

        if IsControlJustReleased(0, 167) and PlayerData.job ~= nil and PlayerData.job.name == 'foodtruck' then
            OpenMobileFoodTruckActionsMenu()
        end
    end
end)
