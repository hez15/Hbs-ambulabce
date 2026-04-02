-- HBS Stress / trauma system

local stressThread = nil

local function ApplyStressEffects()
    local s = HBSState.stress
    local ped = cache.ped

    -- Clear previous
    SetRunSprintMultiplierForPlayer(PlayerId(), 1.0)
    StopGameplayCamShaking(true)

    for threshold, fx in pairs(HBSConfig.Stress.effects) do
        if s >= threshold then
            if fx.screenShake then
                SetGameplayCamShaking(fx.screenShake, fx.shakeAmp)
            end
            if fx.staminaDrain then
                SetRunSprintMultiplierForPlayer(PlayerId(), 0.8)
            end
            if fx.reducedAccuracy then
                SetPedSuffersCriticalHits(ped, false)
                SetPedShootRate(ped, 50)
            end
        end
    end
end

-- Natural decay tick
CreateThread(function()
    while true do
        Wait((HBSConfig.Stress.tickRate or 30) * 1000)
        if not IsHBSLoaded() or HBSState.isDowned then goto continue end

        if HBSState.stress > 0 then
            HBSState.stress = HBSUtils.Clamp(HBSState.stress - (HBSConfig.Stress.naturalDecay or 1), 0, 100)
            HBS.SetLocal('stress', HBSState.stress)
            TriggerServerEvent('hbs_ambulance:server:saveStress', HBSState.stress)
            TriggerEvent('hbs:client:hudUpdate')
            ApplyStressEffects()
        end
        ::continue::
    end
end)

-- Combat stress tick
CreateThread(function()
    while true do
        Wait(1000)
        if not IsHBSLoaded() or HBSState.isDowned then goto continue end
        if IsPedInCombat(cache.ped, 0) then
            HBSState.stress = HBSUtils.Clamp(HBSState.stress + (HBSConfig.Stress.sources.combat or 2), 0, 100)
            HBS.SetLocal('stress', HBSState.stress)
            ApplyStressEffects()
        end
        ::continue::
    end
end)

RegisterNetEvent('hbs_ambulance:client:addStress', function(amount)
    HBSState.stress = HBSUtils.Clamp(HBSState.stress + amount, 0, 100)
    HBS.SetLocal('stress', HBSState.stress)
    TriggerEvent('hbs:client:hudUpdate')
    ApplyStressEffects()
end)

AddEventHandler('hbs:client:setStress', function(val)
    HBSState.stress = HBSUtils.Clamp(val or 0, 0, 100)
    HBS.SetLocal('stress', HBSState.stress)
    TriggerEvent('hbs:client:hudUpdate')
    ApplyStressEffects()
end)
