-- HBS HUD: sends state to the NUI SVG body diagram

local function GetHealthPct()
    local ped = PlayerPedId()
    if not ped or ped == 0 then return 0 end

    local hp    = GetEntityHealth(ped)    or 0
    local maxHp = GetEntityMaxHealth(ped) or 200

    -- Death floor for player peds is 100; avoid division by zero
    if maxHp <= 100 or hp <= 100 then return 0 end

    local pct = ((hp - 100) / (maxHp - 100)) * 100
    pct = math.max(0, math.min(100, pct))
    HBSUtils.Debug('hud', ('health: raw=%d max=%d pct=%.1f'):format(hp, maxHp, pct))
    return pct
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

-- Show and populate HUD only after state has fully loaded from server
AddEventHandler('hbs:client:stateLoaded', function()
    SendNUIMessage({ action = 'showHud' })
    UpdateHud()
    HBSUtils.Debug('hud', 'HUD shown and initial data sent')
end)

RegisterNetEvent('hbs_ambulance:client:applyInjuryEffects', function()
    UpdateHud()
end)

-- Periodic health tick — 500ms, only sends when value changes
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

-- Hide HUD on unload (show is handled by hbs:client:stateLoaded above)
AddEventHandler('QBCore:Client:OnPlayerUnloaded', function() SendNUIMessage({ action = 'hideHud' }) end)
AddEventHandler('qbx_core:playerUnloaded',         function() SendNUIMessage({ action = 'hideHud' }) end)
