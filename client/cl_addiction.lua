-- Addiction system: per-substance levels, withdrawal effects, rehab

-- LocalState.addiction = { morphine = 2, painkiller = 0 }

local withdrawalActive  = {}   -- { [substance] = bool }
local rehabActive       = false

-- ── Helpers ───────────────────────────────────────────────────────────────

local function GetHighestAddiction()
    local highest = 0
    for _, level in pairs(LocalState.addiction) do
        if level > highest then highest = level end
    end
    return highest
end

-- ── Apply withdrawal/addiction effects ────────────────────────────────────

local function ApplyAddictionEffects()
    local ped     = PlayerPedId()
    local highest = GetHighestAddiction()
    local fx      = Config.Addiction.effects[highest]

    if not fx then
        -- No active effects
        SetPedShootRate(ped, 100)
        SetPedMoveRateOverride(ped, 1.0)
        return
    end

    if fx.handTremors then
        -- Weapon sway via reduced shoot rate
        SetPedShootRate(ped, 40)
    end

    if fx.speedMult then
        SetPedMoveRateOverride(ped, fx.speedMult)
    end

    if fx.healthDrain then
        -- Handled in drain thread
    end
end

-- ── Withdrawal visual effects ─────────────────────────────────────────────

local withdrawalBlurActive = false

CreateThread(function()
    while true do
        Wait(0)
        if withdrawalBlurActive then
            -- Nausea-style colour distortion
            SetTimecycleModifier('drug_flying_base')
            SetTimecycleModifierStrength(0.3)
        end
    end
end)

local function StartWithdrawalVisuals(level)
    if level >= 3 then
        withdrawalBlurActive = true
    end
    -- Vomit animation for level 4
    if level >= 4 then
        local dict = 'missfbi4_fin'
        local clip = 'sick_loop'
        RequestAnimDict(dict)
        while not HasAnimDictLoaded(dict) do Wait(10) end
        TaskPlayAnim(PlayerPedId(), dict, clip, 8.0, -8.0, 4000, 1, 0, false, false, false)
    end
end

local function StopWithdrawalVisuals()
    withdrawalBlurActive = false
    ClearTimecycleModifier()
end

-- ── Withdrawal health drain ────────────────────────────────────────────────

CreateThread(function()
    while true do
        Wait(5000)
        if not IsPlayerLoaded() then goto continue end
        local highest = GetHighestAddiction()
        local fx      = Config.Addiction.effects[highest]
        if fx and fx.healthDrain and not LocalState.isDowned then
            local ped = PlayerPedId()
            SetEntityHealth(ped, math.max(101, GetEntityHealth(ped) - math.floor(fx.healthDrain * 5)))
        end
        ::continue::
    end
end)

-- ── Periodic addiction effects loop ───────────────────────────────────────

CreateThread(function()
    while true do
        Wait(Config.Addiction.withdrawalTickRate * 1000)
        if not IsPlayerLoaded() then goto continue end
        -- Re-apply effects each tick
        ApplyAddictionEffects()
        ::continue::
    end
end)

-- ── Withdrawal notify loop ─────────────────────────────────────────────────

CreateThread(function()
    while true do
        Wait(60000)   -- check every minute
        if not IsPlayerLoaded() then goto continue end
        for substance, level in pairs(LocalState.addiction) do
            if level > 0 and withdrawalActive[substance] then
                if level >= 3 then
                    Notify(Locale('withdrawal_severe'), 'error', 6000)
                else
                    Notify(Locale('withdrawal_starting'), 'warning', 5000)
                end
                StartWithdrawalVisuals(level)
            end
        end
        ::continue::
    end
end)

-- ── Rehab progress ────────────────────────────────────────────────────────

RegisterNetEvent('hbs_ambulance:client:startRehabProgress', function()
    if rehabActive then return end
    rehabActive = true

    lib.progressBar({
        duration     = Config.Addiction.treatment.duration * 60 * 1000,
        label        = Locale('hospital_rehab_progress'),
        useWhileDead = false,
        canCancel    = false,
    }, function(done)
        rehabActive = false
        if done then
            TriggerServerEvent('hbs_ambulance:server:completeRehab')
        end
    end)
end)

-- ── Net events ────────────────────────────────────────────────────────────

-- Server tells client addiction level changed
RegisterNetEvent('hbs_ambulance:client:addictionUpdated', function(substance, level)
    LocalState.addiction[substance] = level
    SB.SetLocal('addiction', LocalState.addiction)
    TriggerEvent('hbs_ambulance:client:hudUpdate')
    ApplyAddictionEffects()

    if level > (LocalState.addiction[substance] or 0) then
        Notify(Locale('addiction_increased', substance), 'warning', 5000)
    elseif level < (LocalState.addiction[substance] or 0) then
        Notify(Locale('addiction_reduced'), 'success', 4000)
    end
end)

-- Server tells client withdrawal started
RegisterNetEvent('hbs_ambulance:client:withdrawalStarted', function(substance)
    withdrawalActive[substance] = true
    local level = LocalState.addiction[substance] or 0
    Notify(Locale('withdrawal_starting'), 'warning', 6000)
    StartWithdrawalVisuals(level)
    ApplyAddictionEffects()
end)

-- Server tells client withdrawal ended (used item that relieves it)
RegisterNetEvent('hbs_ambulance:client:withdrawalEnded', function(substance)
    withdrawalActive[substance] = false
    StopWithdrawalVisuals()
    ApplyAddictionEffects()
end)

-- ── State bag sync ────────────────────────────────────────────────────────

AddStateBagChangeHandler(SB.Keys.addiction, nil, function(bagName, _, value)
    local myBag = 'player:' .. GetPlayerServerId(PlayerId())
    if bagName ~= myBag then return end
    LocalState.addiction = value or {}
    ApplyAddictionEffects()
    TriggerEvent('hbs_ambulance:client:hudUpdate')
end)

-- ── Event hooks ───────────────────────────────────────────────────────────

AddEventHandler('hbs_ambulance:client:applyAddictionEffects', ApplyAddictionEffects)
