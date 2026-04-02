-- Injury detection, persistent effects, bloodloss

local blurActive    = false
local limpActive    = false
local lastDmgHealth = 200

-- ── Apply all injury effects based on LocalState.injuries ─────────────────

local function ApplyInjuryEffects()
    local ped        = PlayerPedId()
    local injuries   = LocalState.injuries
    local hasLimp    = false
    local hasSlow    = false
    local hasSway    = false
    local hasBlur    = false
    local hasBloodloss = false

    for part, severity in pairs(injuries) do
        local fx = Config.InjuryEffects[part]
        if fx then
            if fx.limp     then hasLimp    = true end
            if fx.slowMovement then hasSlow = true end
            if fx.weaponHandling then hasSway = true end
            if fx.blurredVision  then hasBlur = true end
        end
        if severity == 'critical' then
            hasBloodloss = true
        end
    end

    -- Limp / slow movement
    if hasLimp or hasSlow then
        local mult = hasLimp and Config.FractureSpeedMult or
                     (Config.InjuryEffects.torso and Config.InjuryEffects.torso.slowMovement or 0.8)
        SetPedMoveRateOverride(ped, mult)
        RequestAnimSet('move_m@injured')
        while not HasAnimSetLoaded('move_m@injured') do Wait(10) end
        SetPedMovementClipset(ped, 'move_m@injured', 1.0)
        limpActive = true
    elseif limpActive then
        SetPedMoveRateOverride(ped, 1.0)
        ResetPedMovementClipset(ped, 0.0)
        limpActive = false
    end

    -- Weapon sway
    if hasSway then
        SetPedShootRate(ped, 50)
    else
        SetPedShootRate(ped, 100)
    end

    -- Head blur
    if hasBlur and not blurActive then
        blurActive = true
    elseif not hasBlur and blurActive then
        blurActive = false
        ClearTimecycleModifier()
    end

    -- Bloodloss flag
    LocalState.bloodloss = hasBloodloss
    SB.SetLocal('bloodloss', hasBloodloss)

    TriggerEvent('hbs_ambulance:client:hudUpdate')
end

-- ── Head blur thread ───────────────────────────────────────────────────────

CreateThread(function()
    while true do
        Wait(0)
        if blurActive then
            SetTimecycleModifier('damage')
            SetTimecycleModifierStrength(0.35)
        end
    end
end)

-- ── Bloodloss drain ────────────────────────────────────────────────────────

CreateThread(function()
    while true do
        Wait(4000)
        if not IsPlayerLoaded() then goto continue end
        if LocalState.bloodloss and not LocalState.isDowned and not LocalState.inPain then
            local ped = PlayerPedId()
            local hp  = GetEntityHealth(ped)
            SetEntityHealth(ped, math.max(101, hp - 3))
        end
        ::continue::
    end
end)

-- ── Damage detection ───────────────────────────────────────────────────────

CreateThread(function()
    while true do
        Wait(200)
        if not IsPlayerLoaded() then goto continue end

        local ped    = PlayerPedId()
        local health = GetEntityHealth(ped)
        local dmg    = lastDmgHealth - health

        if dmg >= 5 then
            local boneHash = GetPedLastDamageBone(ped)
            local part     = InjuryDefs.BoneToBodyPart(boneHash)
            local severity = InjuryDefs.DamageToSeverity(dmg)
            local existing = LocalState.injuries[part]

            if not existing or InjuryDefs.IsWorse(severity, existing) then
                LocalState.injuries[part] = severity
                SB.SetLocal('injuries', LocalState.injuries)
                TriggerServerEvent('hbs_ambulance:server:saveInjury', part, severity)
                ApplyInjuryEffects()
                TriggerEvent('hbs_ambulance:client:addStress',
                    Config.Stress.sources.injury or 10)
            end
            lastDmgHealth = health
        elseif health > lastDmgHealth then
            -- health went up (heal) — update tracker
            lastDmgHealth = health
        end
        ::continue::
    end
end)

-- ── Public API ─────────────────────────────────────────────────────────────

-- Heal a specific body part (optionally only for certain severities)
function HealBodyPart(part, severities)
    if not LocalState.injuries[part] then return end
    if severities then
        if not Utils.TableContains(severities, LocalState.injuries[part]) then return end
    end
    LocalState.injuries[part] = nil
    SB.SetLocal('injuries', LocalState.injuries)
    TriggerServerEvent('hbs_ambulance:server:saveInjury', part, nil)
    ApplyInjuryEffects()
end

function ClearAllInjuries()
    LocalState.injuries  = {}
    LocalState.bloodloss = false
    SB.SetLocal('injuries',  {})
    SB.SetLocal('bloodloss', false)
    TriggerServerEvent('hbs_ambulance:server:clearAllInjuries')
    ApplyInjuryEffects()
end

-- ── Event hooks ────────────────────────────────────────────────────────────

AddEventHandler('hbs_ambulance:client:applyInjuryEffects', ApplyInjuryEffects)
AddEventHandler('hbs_ambulance:client:clearInjuries',      ClearAllInjuries)

-- Sync injuries pushed from server via state bags
AddStateBagChangeHandler(SB.Keys.injuries, nil, function(bagName, _, value)
    local myBag = 'player:' .. GetPlayerServerId(PlayerId())
    if bagName ~= myBag then return end
    LocalState.injuries = value or {}
    ApplyInjuryEffects()
end)
