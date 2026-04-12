-- HBS Drug system — timed highs, come-downs, addiction via existing system

local activeHigh     = nil  -- { substance, endTime, cfg }
local activeComeDown = nil  -- { substance, endTime, speedMult }
local regenThread    = nil

-- ── Apply high ────────────────────────────────────────────────────────────────

local function ClearHighEffects()
    if activeHigh and activeHigh.cfg and activeHigh.cfg.effects and activeHigh.cfg.effects.drunk then
        ResetPedMovementClipset(cache.ped, 0)
        AnimpostfxStop('DrunkEffect')
        SetPedConfigFlag(cache.ped, 100, false)
    end
    SetRunSprintMultiplierForPlayer(PlayerId(), 1.0)
    ClearTimecycleModifier()
end

local function ClearComeDownEffects()
    if activeComeDown then
        local drugCfg = HBSConfig.Drugs and HBSConfig.Drugs[activeComeDown.substance]
        if drugCfg and drugCfg.effects and drugCfg.effects.drunk then
            ResetPedMovementClipset(cache.ped, 0)
            AnimpostfxStop('DrunkEffect')
            SetPedConfigFlag(cache.ped, 100, false)
        end
    end
    SetRunSprintMultiplierForPlayer(PlayerId(), 1.0)
end

local function ApplyHighEffects(cfg)
    local fx = cfg.effects
    if not fx then return end

    if fx.speedMult then
        SetRunSprintMultiplierForPlayer(PlayerId(), fx.speedMult)
    end

    if fx.screenEffect then
        SetTimecycleModifier(fx.screenEffect)
        SetTimecycleModifierStrength(0.6)
    end

    if fx.postFx then
        AnimpostfxPlay(fx.postFx, 2000, false)
    end

    -- Drunk stumble: override movement clipset and apply blur
    if fx.drunk then
        local drunkSet = 'MOVE_M@DRUNK@MODERATEDRUNK'
        RequestAnimSet(drunkSet)
        local t = 0
        while not HasAnimSetLoaded(drunkSet) and t < 20 do Wait(100); t = t + 1 end
        if HasAnimSetLoaded(drunkSet) then
            SetPedMovementClipset(cache.ped, drunkSet, 1.0)
        end
        AnimpostfxPlay('DrunkEffect', 0, true)
        SetPedConfigFlag(cache.ped, 100, true)  -- PED_FLAG_IS_DRUNK
    end
end

-- ── Health regen tick (meth) ──────────────────────────────────────────────────

local function StartRegenTick()
    if regenThread then return end
    regenThread = true
    CreateThread(function()
        while activeHigh and activeHigh.cfg.effects.healthRegen do
            Wait(4000)
            if not activeHigh or not activeHigh.cfg.effects.healthRegen then break end
            local ped = cache.ped
            local hp  = GetEntityHealth(ped)
            if hp < 200 and not HBSState.isDowned then
                SetEntityHealth(ped, math.min(200, hp + 3))
            end
        end
        regenThread = nil
    end)
end

-- ── Paranoia tick ─────────────────────────────────────────────────────────────

local function StartParanoiaTick()
    CreateThread(function()
        while activeHigh and activeHigh.cfg.effects.paranoia do
            Wait(math.random(8000, 20000))
            if not activeHigh or not activeHigh.cfg.effects.paranoia then break end
            ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', 0.15)
            Wait(1200)
            ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', 0.0)
        end
    end)
end

-- ── Main high timer ───────────────────────────────────────────────────────────

local function StartHigh(drugName, cfg)
    -- Clear any existing high
    if activeHigh then
        HBSUtils.Debug('drugs', 'overriding existing high: ' .. activeHigh.substance)
        ClearHighEffects()
    end
    -- Clear any active come-down so its speed penalty doesn't stack under the new high
    if activeComeDown then
        HBSUtils.Debug('drugs', 'clearing come-down before new high: ' .. activeComeDown.substance)
        ClearComeDownEffects()
        activeComeDown = nil
    end

    activeHigh = { substance = drugName, endTime = GetGameTimer() + (cfg.duration * 1000), cfg = cfg }
    HBSUtils.Debug('drugs', ('high started: %s duration=%ds'):format(drugName, cfg.duration))
    ApplyHighEffects(cfg)
    HBSNotify('inform', ('You feel the effects of %s.'):format(cfg.label))

    if cfg.effects.healthRegen then StartRegenTick() end
    if cfg.effects.paranoia    then StartParanoiaTick() end

    -- Pain relief (heroin): clear scratch/minor injuries client-side
    if cfg.effects.painRelief then
        for part, sev in pairs(HBSState.injuries) do
            if sev == 'scratch' or sev == 'minor' then
                HBSState.injuries[part] = nil
            end
        end
        HBS.SetLocal('injuries', HBSState.injuries)
        TriggerEvent('hbs:client:hudUpdate')
        TriggerEvent('hbs:client:applyInjuryEffects')
    end

    -- High countdown thread
    CreateThread(function()
        while GetGameTimer() < activeHigh.endTime do
            Wait(1000)
        end
        -- High ended — start come-down
        HBSUtils.Debug('drugs', ('high ended: %s'):format(drugName))
        ClearHighEffects()
        activeHigh = nil

        if cfg.comeDown and cfg.comeDown > 0 then
            local cdSpeed = cfg.effects.sedation and 0.80 or 0.92
            activeComeDown = {
                substance = drugName,
                endTime   = GetGameTimer() + (cfg.comeDown * 1000),
                speedMult = cdSpeed,
            }
            HBSUtils.Debug('drugs', ('come-down started: %s speedMult=%.2f duration=%ds'):format(drugName, cdSpeed, cfg.comeDown))
            SetRunSprintMultiplierForPlayer(PlayerId(), cdSpeed)
            HBSNotify('error', ('The %s is wearing off.'):format(cfg.label))

            Wait(cfg.comeDown * 1000)
            ClearComeDownEffects()
            activeComeDown = nil
            HBSUtils.Debug('drugs', ('come-down ended: %s'):format(drugName))
        end
    end)
end

-- ── Net event: server confirmed drug use, start high ─────────────────────────

RegisterNetEvent('hbs_ambulance:client:drugEffect', function(drugName)
    local cfg = HBSConfig.Drugs[drugName]
    if not cfg then
        HBSUtils.Debug('drugs', 'drugEffect received but no config for: ' .. tostring(drugName))
        return
    end
    HBSUtils.Debug('drugs', 'drugEffect received: ' .. drugName)
    CreateThread(function() StartHigh(drugName, cfg) end)
end)

-- ── Net event: addiction updated from drug use ────────────────────────────────
-- (handled by existing cl_addiction.lua addictionUpdate event)

-- ── Clear drug state on unload (stops dangling threads) ──────────────────────

AddEventHandler('QBCore:Client:OnPlayerUnloaded', function()
    activeHigh     = nil
    activeComeDown = nil
    ClearHighEffects()
    ClearComeDownEffects()
end)
AddEventHandler('qbx_core:playerUnloaded', function()
    activeHigh     = nil
    activeComeDown = nil
    ClearHighEffects()
    ClearComeDownEffects()
end)

-- Preload drug animation dicts to eliminate first-use delay
AddEventHandler('hbs:client:stateLoaded', function()
    CreateThread(function()
        local seenDicts = {}
        for _, cfg in pairs(HBSConfig.Drugs or {}) do
            if cfg.animation and cfg.animation.dict and not seenDicts[cfg.animation.dict] then
                seenDicts[cfg.animation.dict] = true
                RequestAnimDict(cfg.animation.dict)
            end
        end
        RequestAnimSet('MOVE_M@DRUNK@MODERATEDRUNK')
    end)
end)

-- ── Use drug item event ───────────────────────────────────────────────────────

AddEventHandler('hbs_ambulance:client:useDrug', function(drugName)
    local cfg = HBSConfig.Drugs[drugName]
    if not cfg then return end

    CreateThread(function()
        local dict = cfg.animation and cfg.animation.dict
        local clip = cfg.animation and cfg.animation.anim
        if dict then
            RequestAnimDict(dict)
            local t = 0
            while not HasAnimDictLoaded(dict) and t < 30 do Wait(100); t = t + 1 end
        end

        local completed = lib.progressCircle({
            duration     = (cfg.useTime or 3) * 1000,
            label        = ('Using %s...'):format(cfg.label),
            useWhileDead = false,
            canCancel    = true,
            disable      = { move = false, car = false, combat = true },
            anim         = dict and { dict = dict, clip = clip, flag = cfg.animation.flag or 49 } or nil,
        })

        if completed then
            TriggerServerEvent('hbs_ambulance:server:useDrug', drugName)
        end
    end)
end)
