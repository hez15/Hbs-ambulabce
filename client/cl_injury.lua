-- HBS Injury tracking: detect damage, apply movement/visual effects

local lastHealth = 200
local smallHitCount = 0   -- consecutive low-damage hits (melee/punch pattern)
local isKnockedOut  = false

-- Reset baseline health on load so first tick doesn't create false injuries
AddEventHandler('hbs:client:stateLoaded', function()
    lastHealth = GetEntityHealth(cache.ped)
    -- Suppress collision-triggered ragdoll (getting hit by cars, etc.)
    SetPedRagdollOnCollision(cache.ped, false)
end)

-- ── Ragdoll limiter ───────────────────────────────────────────────────────
-- Allows a brief 500ms stumble when shot, then forces recovery upright.
-- Never cancels ragdoll while downed (injury writhe should be preserved).

CreateThread(function()
    while true do
        Wait(0)
        local ped = cache.ped
        if IsPedRagdoll(ped) and not HBSState.isDowned then
            Wait(500)
            if IsPedRagdoll(ped) and not HBSState.isDowned then
                SetPedToRagdoll(ped, 0, 0, 0, false, false, false)
            end
        end
    end
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
                -- Track punch pattern: small repeated hits
                if dmg < 15 then
                    smallHitCount = smallHitCount + 1
                else
                    smallHitCount = 0
                end

                -- Melee knockout: health in danger zone from accumulated punches
                -- Stabilise HP above laststand floor and apply daze effect
                if not isKnockedOut and not HBSState.isDowned
                   and health > 101 and health < 115 and smallHitCount >= 3 then
                    isKnockedOut  = true
                    smallHitCount = 0
                    SetEntityHealth(ped, 108)
                    lastHealth = 108
                    TriggerEvent('hbs:client:meleeKnockout')
                    goto continue
                end

                local boneHit = GetPedLastDamageBone(ped)
                ClearPedLastDamageBone(ped)
                local part    = InjuryDefs.BoneToBodyPart(boneHit)
                local sev     = InjuryDefs.DamageToSeverity(dmg)

                HBSUtils.Debug('injury', ('damage detected: dmg=%d bone=%d part=%s sev=%s'):format(dmg, boneHit, part, sev))

                -- Only upgrade, never downgrade an existing injury
                local existing = HBSState.injuries[part]
                if not existing or InjuryDefs.IsWorse(sev, existing) then
                    HBSState.injuries[part] = sev
                    HBS.SetLocal('injuries', HBSState.injuries)
                    TriggerServerEvent('hbs_ambulance:server:saveInjury', part, sev)
                    TriggerEvent('hbs:client:hudUpdate')
                    TriggerEvent('hbs:client:applyInjuryEffects')
                    HBSUtils.Debug('injury', ('saved injury: %s=%s'):format(part, sev))
                else
                    HBSUtils.Debug('injury', ('skipped injury: %s already %s (new %s not worse)'):format(part, existing, sev))
                end
            end
        end

        lastHealth = health
        ::continue::
    end
end)

-- ── Apply injury effects ──────────────────────────────────────────────────

-- How much of the part's speed penalty to apply per severity (0 = none, 1 = full)
local SevScale = { scratch = 0.1, minor = 0.35, fracture = 0.70, critical = 1.0 }

local function ApplyInjuryEffects()
    local ped = cache.ped
    local worstSpeed = 1.0
    local hasBlur    = false

    for part, sev in pairs(HBSState.injuries) do
        local fx = HBSConfig.InjuryEffects and HBSConfig.InjuryEffects[part]
        if fx then
            if fx.speedMult then
                local scale   = SevScale[sev] or 1.0
                local penalty = (1.0 - fx.speedMult) * scale
                local scaled  = 1.0 - penalty
                if scaled < worstSpeed then worstSpeed = scaled end
            end
            if fx.blurredVision then hasBlur = true end
        end
    end

    HBSUtils.Debug('injury', ('apply effects: speedMult=%.2f blur=%s'):format(worstSpeed, tostring(hasBlur)))
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
                local newHp = math.max(101, hp - totalDrain)
                SetEntityHealth(ped, newHp)
                lastHealth = newHp  -- keep damage-detection baseline in sync so bleed isn't re-detected as new damage
                HBSUtils.Debug('injury', ('bleed drain: %d hp removed (total drain %d)'):format(totalDrain, totalDrain))
            end
        end

        ::bleedcontinue::
    end
end)

AddEventHandler('hbs:client:applyInjuryEffects', ApplyInjuryEffects)

-- Server passes updated injuries so we sync HBSState before recalculating effects.
-- Without this, ApplyInjuryEffects reads stale local data and the heal has no visual effect.
RegisterNetEvent('hbs_ambulance:client:applyInjuryEffects', function(injuries)
    if injuries ~= nil then
        HBSState.injuries = injuries
        HBS.SetLocal('injuries', injuries)
        TriggerEvent('hbs:client:hudUpdate')
    end
    ApplyInjuryEffects()
end)

-- ── Clear injuries (on revive / respawn) ─────────────────────────────────

AddEventHandler('hbs:client:clearInjuries', function()
    isKnockedOut  = false
    smallHitCount = 0
    HBSUtils.Debug('injury', 'injuries cleared')
    HBSState.injuries = {}
    HBS.SetLocal('injuries', {})
    SetRunSprintMultiplierForPlayer(PlayerId(), 1.0)
    ClearTimecycleModifier()
    TriggerEvent('hbs:client:hudUpdate')
end)

RegisterNetEvent('hbs_ambulance:client:clearInjuries', function()
    TriggerEvent('hbs:client:clearInjuries')
end)

-- ── Health setter (server cannot reliably set player ped health in OAL mode) ──

RegisterNetEvent('hbs_ambulance:client:setHealth', function(hp)
    local ped = cache.ped
    if not ped or ped == 0 then return end
    local maxHp = GetEntityMaxHealth(ped)
    SetEntityHealth(ped, math.max(101, math.min(maxHp, math.floor(hp))))
end)

-- Delta-based HP change: positive = heal, negative = damage penalty.
-- Reads current HP client-side (accurate in OAL mode), clamps between 101 and maxHp.
RegisterNetEvent('hbs_ambulance:client:addHealth', function(amount)
    local ped = cache.ped
    if not ped or ped == 0 then return end
    local maxHp = GetEntityMaxHealth(ped)
    SetEntityHealth(ped, math.max(101, math.min(maxHp, GetEntityHealth(ped) + math.floor(amount))))
end)

-- Server asks this client to report its own HP so the server can relay it to an EMS.
-- requestingSrc is the server ID of the EMS who triggered checkVitals.
RegisterNetEvent('hbs_ambulance:client:reportVitals', function(requestingSrc)
    local ped = cache.ped
    if not ped or ped == 0 then return end
    TriggerServerEvent('hbs_ambulance:server:vitalsReport',
        requestingSrc, GetEntityHealth(ped), GetEntityMaxHealth(ped))
end)

-- ── Melee knockout effect ─────────────────────────────────────────────────

AddEventHandler('hbs:client:meleeKnockout', function()
    local ped = cache.ped
    HBSUtils.Debug('injury', 'melee knockout triggered')

    DoScreenFadeOut(200)
    SetPedToRagdoll(ped, 3500, 3500, 0, false, false, false)
    Wait(300)
    DoScreenFadeIn(900)

    ShakeGameplayCam('MEDIUM_EXPLOSION_SHAKE', 0.35)
    SetTimecycleModifier('drug_flying_in_sky')
    SetTimecycleModifierStrength(0.5)
    HBSNotify('You\'re dazed from the hit...', 'error')

    Wait(1500)
    ShakeGameplayCam('MEDIUM_EXPLOSION_SHAKE', 0.0)

    Wait(3500)
    ClearTimecycleModifier()
    isKnockedOut = false
    HBSUtils.Debug('injury', 'knockout recovered')
end)
