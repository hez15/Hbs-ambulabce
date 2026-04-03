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
                end

                local timeLeft = inLaststand
                    and math.ceil(exports.qbx_medical:GetLaststandTime())
                    or  300

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

-- qbx_medical revive (hospital check-in / standard revive)
RegisterNetEvent('qbx_medical:client:playerRevived', function()
    HideDeathScreen()
    TriggerEvent('hbs:client:clearInjuries')
    TriggerEvent('hbs:client:setStress', 0)
    EmsNotified = false
end)

-- Our EMS research revive path
RegisterNetEvent('hbs_ambulance:client:revived', function()
    HideDeathScreen()
    SetEntityHealth(cache.ped, 200)
    SetEntityInvincible(cache.ped, false)
    ClearPedTasksImmediately(cache.ped)
    TriggerEvent('hbs:client:clearInjuries')
    TriggerEvent('hbs:client:setStress', 0)
    exports.qbx_core:Notify('You have been revived!', 'success')
end)

-- ── NUI respawn button ────────────────────────────────────────────────────

RegisterNuiCallback('respawn', function(data, cb)
    HideDeathScreen()
    TriggerServerEvent('hbs_ambulance:server:requestRespawn')
    cb('ok')
end)

-- Fallback if fetch fails — JS dispatches respawnFallback via window.dispatchEvent
AddEventHandler('__cfx_nui:respawnFallback', function()
    HideDeathScreen()
    TriggerServerEvent('hbs_ambulance:server:requestRespawn')
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
