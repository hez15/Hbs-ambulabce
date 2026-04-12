-- HBS Addiction / withdrawal system

local withdrawalActive = false
local vomitCooldown    = false

local function GetHighestAddictionLevel()
    local highest = 0
    for _, level in pairs(HBSState.addiction) do
        if level > highest then highest = level end
    end
    return highest
end

local function ApplyAddictionEffects()
    local ped = cache.ped
    local highest = GetHighestAddictionLevel()

    HBSUtils.Debug('addiction', 'tick — highest level=' .. tostring(highest))

    if highest == 0 then
        if withdrawalActive then
            withdrawalActive = false
            -- Reset any lingering modifiers
            SetRunSprintMultiplierForPlayer(PlayerId(), 1.0)
            ClearTimecycleModifier()
            SendNUIMessage({ action = 'setIcon', icon = 'withdrawal', visible = false })
            HBSUtils.Debug('addiction', 'withdrawal cleared — no active addiction')
        end
        return
    end

    local fx = HBSConfig.Addiction.effects[highest]
    if not fx then return end

    -- Mood swing (level 1): random screen flash
    if fx.moodSwing and math.random(1, 4) == 1 then
        AnimpostfxPlay('DrugsMichaelAliensFight', 800, false)
    end

    -- Hand tremors: weapon accuracy penalty via cam shake
    if fx.handTremors then
        ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', 0.04)
    end

    -- Movement speed reduction
    if fx.speedMult then
        SetRunSprintMultiplierForPlayer(PlayerId(), fx.speedMult)
    end

    -- Visual distortion
    if fx.visualDistortion then
        SetTimecycleModifier('drug_flying_in_sky')
        SetTimecycleModifierStrength(0.4)
    end

    -- Health drain
    if fx.healthDrain then
        local hp = GetEntityHealth(ped)
        if hp > 101 then
            SetEntityHealth(ped, hp - fx.healthDrain)
        end
    end

    -- Vomit (level 4): play scenario periodically
    if fx.vomit and not vomitCooldown then
        vomitCooldown = true
        -- Run vomit + cooldown in its own thread so the withdrawal tick isn't blocked
        CreateThread(function()
            HBSUtils.Debug('addiction', 'vomit triggered')
            TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_SICK', 0, true)
            Wait(4000)
            ClearPedTasks(ped)
            Wait(120000) -- 2 min cooldown
            vomitCooldown = false
            HBSUtils.Debug('addiction', 'vomit cooldown cleared')
        end)
    end

    -- RP Emotes addict emote (level 2+)
    -- Skipped if the vomit scenario is already playing (they would conflict).
    local rpCfg = HBSConfig.Addiction.rpEmotes
    if rpCfg and rpCfg.enabled and highest >= 2 and not vomitCooldown then
        local chance = rpCfg.chance and rpCfg.chance[highest] or 0.40
        if math.random() < chance then
            CreateThread(function()
                HBSUtils.Debug('addiction', ('addict emote: level=%d emote=%s'):format(highest, rpCfg.emote))
                TriggerEvent(rpCfg.event, { rpCfg.emote })
                Wait(rpCfg.duration or 6000)
                TriggerEvent(rpCfg.event, { false })  -- stop emote
            end)
        end
    end

    if not withdrawalActive then
        withdrawalActive = true
        SendNUIMessage({ action = 'setIcon', icon = 'withdrawal', visible = true })
        HBSNotify(('Withdrawal: %s'):format(
            HBSConfig.Addiction.levelLabels[highest] or 'Unknown'), 'warning')
        HBSUtils.Debug('addiction', 'withdrawal active, level=' .. tostring(highest))
    end
end

-- Withdrawal tick
CreateThread(function()
    -- Initial delay before first withdrawal check
    Wait((HBSConfig.Addiction.withdrawalDelay or 30) * 60 * 1000)
    while true do
        if IsHBSLoaded() then
            local hasWithdrawal = false
            for _, level in pairs(HBSState.addiction) do
                if level > 0 then hasWithdrawal = true; break end
            end
            if hasWithdrawal then ApplyAddictionEffects() end
        end
        Wait((HBSConfig.Addiction.withdrawalTickRate or 60) * 1000)
    end
end)

RegisterNetEvent('hbs_ambulance:client:addictionUpdate', function(addiction)
    HBSState.addiction = addiction or {}
    HBS.SetLocal('addiction', HBSState.addiction)
    HBSUtils.Debug('addiction', 'addiction state updated from server')
    TriggerEvent('hbs:client:hudUpdate')

    -- If all cleared, reset effects immediately
    if GetHighestAddictionLevel() == 0 and withdrawalActive then
        withdrawalActive = false
        SetRunSprintMultiplierForPlayer(PlayerId(), 1.0)
        ClearTimecycleModifier()
        SendNUIMessage({ action = 'setIcon', icon = 'withdrawal', visible = false })
    end
end)
