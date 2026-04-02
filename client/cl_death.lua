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
    SetNuiFocus(false, false)         -- release cursor/focus back to game
end

-- Show the death screen and start a unified countdown
-- totalSecs: total seconds shown on the timer (LastStandTime + BleedoutTime)
-- canRespawn: whether the respawn button is visible
local function ShowDeathScreen(totalSecs, canRespawn)
    SendNUIMessage({
        action        = 'showDeathScreen',
        timeRemaining = totalSecs,
        canRespawn    = canRespawn == true,
    })
    SetNuiFocus(true, true)           -- lock cursor into NUI so player can interact

    -- Kill any running timer thread before starting a new one
    if deathTimerThread then
        deathTimerThread = nil
    end

    -- Start unified countdown
    local remaining = totalSecs
    deathTimerThread = CreateThread(function()
        while remaining > 0 and LocalState.isDowned do
            Wait(1000)
            remaining = remaining - 1
            SendNUIMessage({ action = 'updateTimer', timeRemaining = remaining })
        end
        -- Timer expired — force respawn prompt
        if LocalState.isDowned then
            SendNUIMessage({ action = 'forceRespawn' })
        end
        deathTimerThread = nil
    end)
end

-- ── Check EMS online count before showing the respawn button ─────────────

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
    SetPlayerSprint(PlayerPedId(), true)
    TriggerServerEvent('hbs_ambulance:server:requestRespawn', willText or '')
end

-- NUI callback: player clicked "Respawn at Hospital"
RegisterNuiCallback('respawn', function(data, cb)
    DoRespawn(data and data.will or '')
    cb('ok')
end)

-- Internal event (used by other modules if needed)
AddEventHandler('hbs_ambulance:client:confirmRespawn', function(willText)
    DoRespawn(willText)
end)

-- ── Last Stand ─────────────────────────────────────────────────────────────

local function StartLastStand()
    if lastStandActive or bleedoutActive then return end
    lastStandActive = true
    SetDowned(true)

    -- Disable sprint, play writhe animation
    SetPlayerSprint(PlayerPedId(), false)
    TaskWrithe(PlayerPedId(), PlayerPedId(), Config.LastStandTime * 1000, 0)
    Notify(Locale('last_stand_msg'), 'warning', 6000)

    -- Show screen — timer counts down the full window (last stand + bleedout)
    local totalSecs = Config.LastStandTime + Config.BleedoutTime
    ShowDeathScreenWithEMSCheck(totalSecs)

    TriggerServerEvent('hbs_ambulance:server:playerDowned')

    -- After last stand window, transition to bleedout state
    SetTimeout(Config.LastStandTime * 1000, function()
        if lastStandActive then
            lastStandActive = false
            bleedoutActive  = true
        end
    end)

    -- Forced death when entire window expires (backup — timer thread also handles this)
    SetTimeout(totalSecs * 1000, function()
        if LocalState.isDowned and bleedoutActive then
            TriggerServerEvent('hbs_ambulance:server:recordDeath', {
                x    = GetEntityCoords(PlayerPedId()).x,
                y    = GetEntityCoords(PlayerPedId()).y,
                z    = GetEntityCoords(PlayerPedId()).z,
                will = '',
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
        local health = GetEntityHealth(ped)   -- 0-200 (100 = zero gameplay hp)

        if health <= 100 and not LocalState.isDowned then
            StartLastStand()
        end
        ::continue::
    end
end)

-- ── Revived by EMS ─────────────────────────────────────────────────────────

RegisterNetEvent('hbs_ambulance:client:revived', function()
    bleedoutActive  = false
    lastStandActive = false
    deathTimerThread = nil
    SetDowned(false)
    HideDeathScreen()
    SetPlayerSprint(PlayerPedId(), true)
    SetEntityHealth(PlayerPedId(), 200)
    TriggerEvent('hbs_ambulance:client:clearInjuries')
    Notify(Locale('revive_success'), 'success')
end)

-- ── Teleport to hospital on respawn ────────────────────────────────────────

RegisterNetEvent('hbs_ambulance:client:respawnAt', function(coords)
    DoScreenFadeOut(500)
    Wait(600)
    local ped = PlayerPedId()
    SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, true)
    SetEntityHeading(ped, coords.w or 0.0)
    SetEntityHealth(ped, 200)
    TriggerEvent('hbs_ambulance:client:clearInjuries')
    TriggerEvent('hbs_ambulance:client:setStress', 0)
    DoScreenFadeIn(1000)
end)
