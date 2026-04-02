-- HBS HUD: sends state to the NUI SVG body diagram

local function UpdateHud()
    SendNUIMessage({
        action    = 'updateHud',
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

-- Show HUD on load
AddEventHandler('QBCore:Client:OnPlayerLoaded',  function() SendNUIMessage({ action = 'showHud' }) end)
AddEventHandler('qbx_core:playerLoaded',          function() SendNUIMessage({ action = 'showHud' }) end)
AddEventHandler('QBCore:Client:OnPlayerUnloaded', function() SendNUIMessage({ action = 'hideHud' }) end)
AddEventHandler('qbx_core:playerUnloaded',         function() SendNUIMessage({ action = 'hideHud' }) end)
