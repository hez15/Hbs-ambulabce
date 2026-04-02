-- Stress / trauma system

local adrenalineActive = false
local lastVehSpeed     = 0.0

-- ── Stress modification ───────────────────────────────────────────────────

local function SetStress(val)
    LocalState.stress = Utils.Clamp(math.floor(val), 0, Config.Stress.max)
    SB.SetLocal('stress', LocalState.stress)
    SendNUIMessage({ action = 'updateStress', stress = LocalState.stress })
    TriggerServerEvent('hbs_ambulance:server:saveStress', LocalState.stress)
end

local function AddStress(amount)
    if LocalState.isDowned then return end
    SetStress(LocalState.stress + amount)
    if LocalState.stress >= 75 then
        Notify(Locale('stress_high'), 'error', 4000)
    end
end

local function ReduceStress(amount)
    SetStress(LocalState.stress - amount)
end

-- ── Apply visual/gameplay stress effects ─────────────────────────────────

local function ApplyStressEffects()
    local stress = LocalState.stress
    local ped    = PlayerPedId()

    -- Find highest active threshold
    local effects = {}
    for threshold, fx in pairs(Config.Stress.effects) do
        if stress >= threshold then
            for k, v in pairs(fx) do effects[k] = v end
        end
    end

    -- Screen shake
    if effects.screenShake then
        local amp = 0.03 + (stress / 100) * 0.15
        ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', amp)
    else
        StopGameplayCamShaking(true)
    end

    -- Stamina drain
    if effects.staminaDrain then
        SetPlayerSprintStaminaReplenishMultiplier(ped, 0.25)
    elseif not adrenalineActive then
        SetPlayerSprintStaminaReplenishMultiplier(ped, 1.0)
    end

    -- Reduced accuracy (aim shake handled by stress-induced weapon sway)
    if effects.reducedAccuracy then
        SetPedShootRate(ped, 60)
    end
end

-- ── Natural stress decay ──────────────────────────────────────────────────

CreateThread(function()
    while true do
        Wait(1000)
        if not IsPlayerLoaded() then goto continue end
        if LocalState.stress > 0 and not LocalState.isDowned then
            ReduceStress(Config.Stress.naturalDecay)
        end
        ApplyStressEffects()
        ::continue::
    end
end)

-- ── Combat stress gain ────────────────────────────────────────────────────

CreateThread(function()
    while true do
        Wait(1000)
        if not IsPlayerLoaded() then goto continue end
        if IsPedInCombat(PlayerPedId(), 0) then
            AddStress(Config.Stress.sources.combat)
        end
        ::continue::
    end
end)

-- ── Vehicle crash detection ───────────────────────────────────────────────

CreateThread(function()
    while true do
        Wait(250)
        if not IsPlayerLoaded() then goto continue end
        local ped = PlayerPedId()
        if IsPedInAnyVehicle(ped, false) then
            local veh   = GetVehiclePedIsIn(ped, false)
            local speed = GetEntitySpeed(veh) * 3.6   -- m/s → km/h
            local delta = lastVehSpeed - speed
            if delta > Config.Stress.sources.crashDelta and lastVehSpeed > Config.Stress.sources.crashDelta then
                AddStress(Config.Stress.sources.vehicleCrash)
            end
            lastVehSpeed = speed
        else
            lastVehSpeed = 0.0
        end
        ::continue::
    end
end)

-- ── Adrenaline ────────────────────────────────────────────────────────────

local function TriggerAdrenaline()
    if adrenalineActive then return end
    adrenalineActive = true
    Notify(Locale('adrenaline_start'), 'inform', 4000)
    local ped = PlayerPedId()
    SetPlayerSprintStaminaReplenishMultiplier(ped, 4.0)
    SetPedMoveRateOverride(ped, 1.25)

    CreateThread(function()
        Wait(Config.AdrenalineDuration * 1000)
        adrenalineActive = false
        SetPlayerSprintStaminaReplenishMultiplier(ped, 1.0)
        SetPedMoveRateOverride(ped, 1.0)
        Notify(Locale('adrenaline_end'), 'inform', 3000)
    end)
end

-- ── Event hooks ───────────────────────────────────────────────────────────

AddEventHandler('hbs_ambulance:client:addStress',    function(amt) AddStress(amt) end)
AddEventHandler('hbs_ambulance:client:reduceStress', function(amt) ReduceStress(amt) end)
AddEventHandler('hbs_ambulance:client:setStress',    function(val) SetStress(val) end)
AddEventHandler('hbs_ambulance:client:adrenaline',   TriggerAdrenaline)

-- State bag sync from server
AddStateBagChangeHandler(SB.Keys.stress, nil, function(bagName, _, value)
    local myBag = 'player:' .. GetPlayerServerId(PlayerId())
    if bagName ~= myBag then return end
    LocalState.stress = value or 0
    SendNUIMessage({ action = 'updateStress', stress = LocalState.stress })
end)

-- Public accessors
function GetStress()         return LocalState.stress end
function AddStressPublic(n)  AddStress(n) end
function ReduceStressPublic(n) ReduceStress(n) end
