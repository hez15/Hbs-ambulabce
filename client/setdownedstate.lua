-- HBS Death screen + downed state handler
-- Ped physics/animation managed by qbx_medical.
-- This file: NUI death screen, server tracking, revive cleanup.

local config      = require 'config.client'
local sharedConfig = require 'config.shared'
local isShowing   = false
local doctorCount = 0

local _resourceName = GetCurrentResourceName()

-- ── NUI helpers ───────────────────────────────────────────────────────────

local function ShowDeathScreen(canRespawn, timeRemaining)
    if isShowing then return end
    HBSUtils.Debug('downed', ('ShowDeathScreen: canRespawn=%s timeRemaining=%s'):format(
        tostring(canRespawn), tostring(timeRemaining)))
    isShowing = true
    HBSState.isDowned = true
    HBS.SetLocal('isDowned', true)

    SendNUIMessage({
        action        = 'showDeathScreen',
        bleedoutMs    = (timeRemaining or 300) * 1000,
        canRespawn    = canRespawn == true,
        resourceName  = _resourceName,
    })
    SetNuiFocus(true, true)

    -- Mirror countdown in NUI
    CreateThread(function()
        local t = timeRemaining or 300
        while t > 0 and HBSState.isDowned do
            Wait(1000)
            t = t - 1
            SendNUIMessage({ action = 'updateTimer', ms = t * 1000 })
        end
        if HBSState.isDowned then
            SendNUIMessage({ action = 'showForceRespawn' })
        end
    end)
end

local function HideDeathScreen()
    if not isShowing then return end
    HBSUtils.Debug('downed', 'HideDeathScreen called')
    isShowing = false
    HBSState.isDowned = false
    HBS.SetLocal('isDowned', false)
    SendNUIMessage({ action = 'hideDeathScreen' })
    SetNuiFocus(false, false)
end

-- ── qbx_medical poll loop — show NUI when in laststand or dead ───────────

CreateThread(function()
    local lastDoctorCheck = 0
    while true do
        local isDead      = exports.qbx_medical:IsDead()
        local inLaststand = exports.qbx_medical:IsLaststand()

        if isDead or inLaststand then
            -- Keep ped animation running (qbx_medical handles invincibility/writhe)
            if isDead and not IsInHospitalBed then
                exports.qbx_medical:PlayDeadAnimation()
            end

            if not isShowing then
                -- Refresh doctor count periodically
                local now = GetGameTimer()
                if (now - lastDoctorCheck) > 60000 then
                    doctorCount = lib.callback.await('qbx_ambulancejob:server:getNumDoctors')
                    lastDoctorCheck = now
                    HBSUtils.Debug('downed', ('doctor count refreshed: %d (min=%d)'):format(doctorCount, HBSConfig.MinEmsOnline))
                end

                local timeLeft = inLaststand
                    and math.ceil(exports.qbx_medical:GetLaststandTime())
                    or  300

                HBSUtils.Debug('downed', ('player downed: isDead=%s inLaststand=%s timeLeft=%d doctorCount=%d'):format(
                    tostring(isDead), tostring(inLaststand ~= false), timeLeft, doctorCount))
                ShowDeathScreen(doctorCount < HBSConfig.MinEmsOnline, timeLeft)
                TriggerServerEvent('hbs_ambulance:server:playerDowned')
            end

            Wait(0)
        else
            if isShowing then HideDeathScreen() end
            Wait(1000)
        end
    end
end)

-- ── Revive hooks ──────────────────────────────────────────────────────────

-- Flag set just before qbx_medical's event fires for CPR/bystander revivals.
-- Prevents the qbx hook from clearing injuries that the civilian didn't heal.
local _cprRevive = false

RegisterNetEvent('hbs_ambulance:client:markCPRRevive', function()
    _cprRevive = true
end)

-- qbx_medical revive (hospital check-in / standard revive)
RegisterNetEvent('qbx_medical:client:playerRevived', function()
    HideDeathScreen()
    if not _cprRevive then
        -- Full recovery: hospital or EMS path clears injuries + stress
        TriggerEvent('hbs:client:clearInjuries')
        TriggerEvent('hbs:client:setStress', 0)
    end
    _cprRevive  = false
    EmsNotified = false
end)

-- Full EMS revive (injuries cleared server-side before this fires)
RegisterNetEvent('hbs_ambulance:client:revived', function()
    HideDeathScreen()
    SetEntityInvincible(cache.ped, false)
    ClearPedTasksImmediately(cache.ped)
    TriggerEvent('hbs:client:clearInjuries')
    TriggerEvent('hbs:client:setStress', 0)
    exports.qbx_core:Notify('You have been revived!', 'success')

    -- Brief disorientation — player staggers for ~3s before regaining full control
    CreateThread(function()
        Wait(150)
        RequestAnimDict('move_m@drunk@a')
        local t = 0
        while not HasAnimDictLoaded('move_m@drunk@a') and t < 20 do Wait(100); t = t + 1 end
        if HasAnimDictLoaded('move_m@drunk@a') then
            TaskPlayAnim(cache.ped, 'move_m@drunk@a', 'idle',
                4.0, -4.0, 3000, 49, 0, false, false, false)
        end
    end)
end)

-- Civilian CPR / first aid kit revive — barely alive.
-- HP is set to 106 server-side. Injuries are KEPT. No stress clear.
RegisterNetEvent('hbs_ambulance:client:cprRevived', function()
    HideDeathScreen()
    SetEntityInvincible(cache.ped, false)
    ClearPedTasksImmediately(cache.ped)
    -- Do NOT override HP — server already set it to 106 via addHealth/setHealth
    -- Do NOT clear injuries — patient is still critically wounded

    CreateThread(function()
        -- Eyes opening: instant black then slow fade in
        DoScreenFadeOut(0)
        Wait(500)
        DoScreenFadeIn(2500)

        -- Struggle to get up
        local dict = 'move_m@drunk@a'
        if not HasAnimDictLoaded(dict) then
            RequestAnimDict(dict)
            local t = 0
            while not HasAnimDictLoaded(dict) and t < 20 do Wait(100); t = t + 1 end
        end
        if HasAnimDictLoaded(dict) then
            TaskPlayAnim(cache.ped, dict, 'idle', 3.0, -3.0, 5000, 49, 0, false, false, false)
        end

        -- Disorientation: shake + blur
        ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', 0.10)
        SetTimecycleModifier('drug_flying_in_sky')
        SetTimecycleModifierStrength(0.45)

        Wait(2500)
        ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', 0.0)
        Wait(2000)
        ClearTimecycleModifier()

        exports.qbx_core:Notify('You are barely alive — find EMS immediately!', 'error', 10000)
    end)
end)

-- ── NUI Call EMS button ───────────────────────────────────────────────────

RegisterNuiCallback('callEMS', function(_, cb)
    TriggerServerEvent('hbs_ambulance:server:callEMS')
    cb('ok')
end)

RegisterNetEvent('hbs_ambulance:client:callEMSResult', function(success, remaining)
    SendNUIMessage({ action = 'callEMSResult', success = success, cooldown = remaining or 120 })
end)

-- ── NUI respawn button ────────────────────────────────────────────────────

RegisterNuiCallback('respawn', function(data, cb)
    HideDeathScreen()
    TriggerServerEvent('hbs_ambulance:server:requestRespawn', data and data.lastWords or nil)
    cb('ok')
end)

-- Fallback if fetch fails — JS dispatches respawnFallback via window.dispatchEvent
AddEventHandler('__cfx_nui:respawnFallback', function()
    HideDeathScreen()
    TriggerServerEvent('hbs_ambulance:server:requestRespawn', nil)
end)

-- ── Teleport to hospital after server respawn ─────────────────────────────

RegisterNetEvent('hbs_ambulance:client:respawnAt', function(coords)
    DoScreenFadeOut(500)
    Wait(600)
    local ped = cache.ped
    SetEntityInvincible(ped, false)
    ClearPedTasksImmediately(ped)
    SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, true)
    SetEntityHeading(ped, coords.w or 0.0)
    SetEntityHealth(ped, 200)
    TriggerEvent('hbs:client:clearInjuries')
    TriggerEvent('hbs:client:setStress', 0)
    DoScreenFadeIn(1000)
end)
