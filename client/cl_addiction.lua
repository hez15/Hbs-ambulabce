-- HBS Addiction / withdrawal system

local withdrawalActive = false

local function ApplyAddictionEffects()
    local ped = cache.ped

    -- Find highest active addiction level
    local highest = 0
    for _, level in pairs(HBSState.addiction) do
        if level > highest then highest = level end
    end

    if highest == 0 then
        withdrawalActive = false
        SendNUIMessage({ action = 'withdrawalEnded' })
        return
    end

    local fx = HBSConfig.Addiction.effects[highest]
    if not fx then return end

    if fx.handTremors then
        SetPedSuffersCriticalHits(ped, false)
    end

    if fx.speedMult then
        SetRunSprintMultiplierForPlayer(PlayerId(), fx.speedMult)
    end

    if fx.visualDistortion then
        SetTimecycleModifier('drug_flying_in_sky')
        SetTimecycleModifierStrength(0.5)
    end

    if fx.healthDrain then
        local hp = GetEntityHealth(ped)
        if hp > 101 then
            SetEntityHealth(ped, hp - fx.healthDrain)
        end
    end

    if not withdrawalActive then
        withdrawalActive = true
        SendNUIMessage({ action = 'withdrawalActive' })
    end
end

-- Withdrawal tick
CreateThread(function()
    while true do
        Wait((HBSConfig.Addiction.withdrawalTickRate or 60) * 1000)
        if not IsHBSLoaded() then goto continue end

        local hasWithdrawal = false
        for _, level in pairs(HBSState.addiction) do
            if level > 0 then hasWithdrawal = true; break end
        end

        if hasWithdrawal then ApplyAddictionEffects() end
        ::continue::
    end
end)

RegisterNetEvent('hbs_ambulance:client:addictionUpdate', function(addiction)
    HBSState.addiction = addiction or {}
    HBS.SetLocal('addiction', HBSState.addiction)
    TriggerEvent('hbs:client:hudUpdate')
    ApplyAddictionEffects()
end)
