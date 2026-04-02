-- Death / bleedout system
-- Manages: last stand, bleedout timer, NUI death screen, respawn

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

-- ── Last Stand ─────────────────────────────────────────────────────────────

local function StartLastStand()
    if lastStandActive or bleedoutActive then return end
    lastStandActive = true
    SetDowned(true)

    local ped = PlayerPedId()

    -- Keep ped alive in GTA's eyes — prevents native death screen
    SetEntityInvincible(ped, true)
    if GetEntityHealth(ped) <= 100 then
        SetEntityHealth(ped, 101)
    end

    SetPlayerSprint(ped, false)
    TaskWrithe(ped, ped, Config.LastStandTime * 1000, 0)
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

-- ── Health monitor ─────────────────────────────────────────────────────────

CreateThread(function()
    while true do
        Wait(300)
        if not IsPlayerLoaded() then goto continue end

        local ped    = PlayerPedId()
        local health = GetEntityHealth(ped)

        if health <= 100 and not LocalState.isDowned then
            StartLastStand()
        end
        ::continue::
    end
end)

-- ── Shared revive cleanup ──────────────────────────────────────────────────

local function OnRevived()
    bleedoutActive  = false
    lastStandActive = false
    deathTimerThread = nil
    SetDowned(false)
    HideDeathScreen()

    local ped = PlayerPedId()
    SetEntityInvincible(ped, false)
    ClearPedTasksImmediately(ped)
    SetPlayerSprint(ped, true)
    SetEntityHealth(ped, 200)

    TriggerEvent('hbs_ambulance:client:clearInjuries')
    Notify(Locale('revive_success'), 'success')
end

-- EMS revive (from hbs_ambulance:server:performRevive)
RegisterNetEvent('hbs_ambulance:client:revived', OnRevived)

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
