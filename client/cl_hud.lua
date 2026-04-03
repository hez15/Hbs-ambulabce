-- HBS HUD: sends state to the NUI SVG body diagram

local function GetHealthPct()
    -- FiveM health: 100 = dead, 200 = full. Normalize to 0-100.
    local hp = GetEntityHealth(cache.ped)
    return math.max(0, math.min(100, hp - 100))
end

local function UpdateHud()
    SendNUIMessage({
        action    = 'updateHud',
        health    = GetHealthPct(),
        injuries  = HBSState.injuries,
        stress    = HBSState.stress,
        inPain    = HBSState.inPain,
        bloodloss = HBSState.bloodloss,
        addiction = HBSState.addiction,
    })
end

AddEventHandler('hbs:client:hudUpdate', UpdateHud)
AddEventHandler('hbs:client:stateLoaded', function()
    SendNUIMessage({ action = 'showHud' })
    UpdateHud()
end)

RegisterNetEvent('hbs_ambulance:client:applyInjuryEffects', function()
    UpdateHud()
end)

-- Periodic health tick (every 2 seconds while HUD is visible)
CreateThread(function()
    while true do
        Wait(2000)
        if HBSState.loaded then
            SendNUIMessage({ action = 'updateHealth', value = GetHealthPct() })
        end
    end
end)

-- Show HUD on load
AddEventHandler('QBCore:Client:OnPlayerLoaded',  function() SendNUIMessage({ action = 'showHud' }) end)
AddEventHandler('qbx_core:playerLoaded',          function() SendNUIMessage({ action = 'showHud' }) end)
AddEventHandler('QBCore:Client:OnPlayerUnloaded', function() SendNUIMessage({ action = 'hideHud' }) end)
AddEventHandler('qbx_core:playerUnloaded',         function() SendNUIMessage({ action = 'hideHud' }) end)
