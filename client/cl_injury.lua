-- HBS Injury tracking: detect damage, apply movement/visual effects

local lastHealth = 200

-- Reset baseline health on load so first tick doesn't create false injuries
AddEventHandler('hbs:client:stateLoaded', function()
    lastHealth = GetEntityHealth(cache.ped)
end)

-- ── Damage detection loop ─────────────────────────────────────────────────

CreateThread(function()
    while true do
        Wait(200)
        if not IsHBSLoaded() or HBSState.isDowned then goto continue end

        local ped    = cache.ped
        local health = GetEntityHealth(ped)

        if health < lastHealth then
            local dmg = lastHealth - health
            if dmg >= 1 then
                local boneHit = GetPedLastDamageBone(ped)
                ClearPedLastDamageBone(ped)
                local part    = InjuryDefs.BoneToBodyPart(boneHit)
                local sev     = InjuryDefs.DamageToSeverity(dmg)

                -- Only upgrade, never downgrade an existing injury
                local existing = HBSState.injuries[part]
                if not existing or InjuryDefs.IsWorse(sev, existing) then
                    HBSState.injuries[part] = sev
                    HBS.SetLocal('injuries', HBSState.injuries)
                    TriggerServerEvent('hbs_ambulance:server:saveInjury', part, sev)
                    TriggerEvent('hbs:client:hudUpdate')
                    TriggerEvent('hbs:client:applyInjuryEffects')
                end
            end
        end

        lastHealth = health
        ::continue::
    end
end)

-- ── Apply injury effects ──────────────────────────────────────────────────

local function ApplyInjuryEffects()
    local ped = cache.ped
    local worstSpeed = 1.0
    local hasBlur    = false

    for part, sev in pairs(HBSState.injuries) do
        local fx = HBSConfig.InjuryEffects and HBSConfig.InjuryEffects[part]
        if fx then
            if fx.speedMult and fx.speedMult < worstSpeed then worstSpeed = fx.speedMult end
            if fx.blurredVision then hasBlur = true end
        end
    end

    SetRunSprintMultiplierForPlayer(PlayerId(), worstSpeed)

    if hasBlur then
        SetTimecycleModifier('drug_flying_in_sky')
        SetTimecycleModifierStrength(0.3)
    else
        ClearTimecycleModifier()
    end
end

-- ── Bleed drain thread (replaces qbx_medical:AddBleed) ───────────────────

CreateThread(function()
    while true do
        Wait(5000)
        if not IsHBSLoaded() or HBSState.isDowned then goto bleedcontinue end

        local totalDrain = 0
        for part, sev in pairs(HBSState.injuries) do
            local cfg = HBSConfig.InjurySeverity and HBSConfig.InjurySeverity[sev]
            if cfg and cfg.bleedRate and cfg.bleedRate > 0 then
                totalDrain = totalDrain + cfg.bleedRate
            end
        end

        if totalDrain > 0 then
            local ped = cache.ped
            local hp  = GetEntityHealth(ped)
            if hp > 101 then
                SetEntityHealth(ped, math.max(101, hp - totalDrain))
            end
        end

        ::bleedcontinue::
    end
end)

AddEventHandler('hbs:client:applyInjuryEffects',                          ApplyInjuryEffects)
RegisterNetEvent('hbs_ambulance:client:applyInjuryEffects',               ApplyInjuryEffects)

-- ── Clear injuries (on revive / respawn) ─────────────────────────────────

AddEventHandler('hbs:client:clearInjuries', function()
    HBSState.injuries = {}
    HBS.SetLocal('injuries', {})
    SetRunSprintMultiplierForPlayer(PlayerId(), 1.0)
    ClearTimecycleModifier()
    TriggerEvent('hbs:client:hudUpdate')
end)

RegisterNetEvent('hbs_ambulance:client:clearInjuries', function()
    TriggerEvent('hbs:client:clearInjuries')
end)
