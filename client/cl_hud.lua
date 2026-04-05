-- HBS HUD: sends state to the NUI SVG body diagram

local function GetHealthPct()
    -- Use PlayerPedId() directly — cache.ped can be 0 during early ticks
    local ped = PlayerPedId()
    if not ped or ped == 0 then return 0 end

    local hp    = GetEntityHealth(ped)
    local maxHp = GetEntityMaxHealth(ped)
    -- GTA player death floor is 100; max health varies per server config
    if maxHp <= 100 then return 0 end

    local pct = ((hp - 100) / (maxHp - 100)) * 100
    HBSUtils.Debug('hud', ('health: raw=%d max=%d pct=%.1f'):format(hp, maxHp, pct))
    return math.max(0, math.min(100, pct))
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

-- Periodic health tick — 500ms so the bar responds quickly to damage
CreateThread(function()
    local lastPct = -1
    while true do
        Wait(500)
        if HBSState.loaded then
            local pct = GetHealthPct()
            if pct ~= lastPct then
                lastPct = pct
                SendNUIMessage({ action = 'updateHealth', value = pct })
            end
        end
    end
end)

-- Show HUD on load
AddEventHandler('QBCore:Client:OnPlayerLoaded',  function() SendNUIMessage({ action = 'showHud' }) end)
AddEventHandler('qbx_core:playerLoaded',          function() SendNUIMessage({ action = 'showHud' }) end)
AddEventHandler('QBCore:Client:OnPlayerUnloaded', function() SendNUIMessage({ action = 'hideHud' }) end)
AddEventHandler('qbx_core:playerUnloaded',         function() SendNUIMessage({ action = 'hideHud' }) end)
