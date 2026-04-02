-- Death / bleedout system
-- Ped state (invincibility, writhe animation) is owned by qbx_medical.
-- This file handles: our NUI death screen, state tracking, dispatch, and cleanup.

local bleedoutActive  = false
local lastStandActive = false
local deathTimerThread = nil

-- ── Helpers ────────────────────────────────────────────────────────────────

local function SetDowned(state)
    LocalState.isDowned = state
    SB.SetLocal('isDowned', state)
end

local function HideDeathScreen()
    SendNUIMessage({ action = 'hideDeathScreen' })
    SetNuiFocus(false, false)
end

local function ShowDeathScreen(totalSecs, canRespawn)
    SendNUIMessage({
        action        = 'showDeathScreen',
        timeRemaining = totalSecs,
        canRespawn    = canRespawn == true,
    })
    SetNuiFocus(true, true)

    if deathTimerThread then
        deathTimerThread = nil
    end

    local remaining = totalSecs
    deathTimerThread = CreateThread(function()
        while remaining > 0 and LocalState.isDowned do
            Wait(1000)
            remaining = remaining - 1
            SendNUIMessage({ action = 'updateTimer', timeRemaining = remaining })
        end
        if LocalState.isDowned then
            SendNUIMessage({ action = 'forceRespawn' })
        end
        deathTimerThread = nil
    end)
end

local function ShowDeathScreenWithEMSCheck(totalSecs)
    lib.callback('hbs_ambulance:getEMSCount', false, function(emsCount)
        local canRespawn = (emsCount or 0) < Config.MinEmsOnline
        ShowDeathScreen(totalSecs, canRespawn)
    end)
end

-- ── Respawn (triggered from NUI button) ────────────────────────────────────

local function DoRespawn(willText)
    if not LocalState.isDowned then return end
    SetDowned(false)
    bleedoutActive  = false
    lastStandActive = false
    deathTimerThread = nil
    HideDeathScreen()

    local ped = PlayerPedId()
    SetEntityInvincible(ped, false)
    ClearPedTasksImmediately(ped)
    SetPlayerSprint(ped, true)

    TriggerServerEvent('hbs_ambulance:server:requestRespawn', willText or '')
end

RegisterNuiCallback('respawn', function(data, cb)
    DoRespawn(data and data.will or '')
    cb('ok')
end)

AddEventHandler('hbs_ambulance:client:confirmRespawn', function(willText)
    DoRespawn(willText)
end)

-- ── Last stand entry ────────────────────────────────────────────────────────
-- qbx_medical owns ped state (invincibility, writhe anim).
-- We just show our death screen UI and alert the server.

local function OnEnterLastStand()
    if lastStandActive or bleedoutActive then return end
    lastStandActive = true
    SetDowned(true)

    -- Sprint disabled; qbx_medical applies writhe anim and pins HP
    SetPlayerSprint(PlayerPedId(), false)
    Notify(Locale('last_stand_msg'), 'warning', 6000)

    local totalSecs = Config.LastStandTime + Config.BleedoutTime
    ShowDeathScreenWithEMSCheck(totalSecs)

    TriggerServerEvent('hbs_ambulance:server:playerDowned')

    SetTimeout(Config.LastStandTime * 1000, function()
        if lastStandActive then
            lastStandActive = false
            bleedoutActive  = true
        end
    end)

    SetTimeout(totalSecs * 1000, function()
        if LocalState.isDowned and bleedoutActive then
            local pos = GetEntityCoords(PlayerPedId())
            TriggerServerEvent('hbs_ambulance:server:recordDeath', {
                x = pos.x, y = pos.y, z = pos.z, will = '',
            })
        end
    end)
end

-- ── qbx_medical detection loop ─────────────────────────────────────────────
-- Poll qbx_medical exports instead of raw health, so we don't fight with
-- qbx_medical's own ped-state management.

CreateThread(function()
    while true do
        Wait(300)
        if not IsPlayerLoaded() then goto continue end

        local inLaststand = exports.qbx_medical:IsLaststand()
        if inLaststand and not LocalState.isDowned then
            OnEnterLastStand()
        end

        ::continue::
    end
end)

-- ── Revive cleanup (shared logic) ─────────────────────────────────────────

local function OnRevived()
    bleedoutActive  = false
    lastStandActive = false
    deathTimerThread = nil
    SetDowned(false)
    HideDeathScreen()

    local ped = PlayerPedId()
    -- qbx_medical re-enables damage on its side; we mirror here for safety
    SetEntityInvincible(ped, false)
    ClearPedTasksImmediately(ped)
    SetPlayerSprint(ped, true)
    SetEntityHealth(ped, 200)

    TriggerEvent('hbs_ambulance:client:clearInjuries')
    Notify(Locale('revive_success'), 'success')
end

-- Our own EMS revive event (from hbs_ambulance:server:performRevive)
RegisterNetEvent('hbs_ambulance:client:revived', OnRevived)

-- qbx_medical / qbx_ambulancejob revive event — hook so our UI always clears
RegisterNetEvent('qbx_medical:client:playerRevived', function()
    if LocalState.isDowned then
        OnRevived()
    end
end)

-- ── Teleport to hospital on respawn ────────────────────────────────────────

RegisterNetEvent('hbs_ambulance:client:respawnAt', function(coords)
    DoScreenFadeOut(500)
    Wait(600)
    local ped = PlayerPedId()
    SetEntityInvincible(ped, false)
    ClearPedTasksImmediately(ped)
    SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, true)
    SetEntityHeading(ped, coords.w or 0.0)
    SetEntityHealth(ped, 200)
    TriggerEvent('hbs_ambulance:client:clearInjuries')
    TriggerEvent('hbs_ambulance:client:setStress', 0)
    DoScreenFadeIn(1000)
end)
