-- Death / bleedout system
-- Manages: last stand, bleedout timer, NUI death screen, respawn

local bleedoutActive  = false
local lastStandActive = false
local bleedoutSecs    = 0
local lastHealth      = 200

-- ── Helpers ────────────────────────────────────────────────────────────────

local function SetDowned(state)
    LocalState.isDowned = state
    SB.SetLocal('isDowned', state)
end

local function ShowDeathScreen(secs)
    SendNUIMessage({
        action        = 'showDeathScreen',
        timeRemaining = secs,
    })
    SetNuiFocus(false, false)
end

local function HideDeathScreen()
    SendNUIMessage({ action = 'hideDeathScreen' })
end

-- ── Respawn (triggered from NUI callback or force) ─────────────────────────

local function DoRespawn(willText)
    if not LocalState.isDowned then return end
    SetDowned(false)
    bleedoutActive  = false
    lastStandActive = false
    HideDeathScreen()
    SetPlayerSprint(PlayerPedId(), true)
    TriggerServerEvent('hbs_ambulance:server:requestRespawn', willText or '')
end

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

    ShowDeathScreen(Config.BleedoutTime)
    TriggerServerEvent('hbs_ambulance:server:playerDowned')

    -- After last stand window, start bleedout
    SetTimeout(Config.LastStandTime * 1000, function()
        if lastStandActive then
            lastStandActive = false
            TriggerEvent('hbs_ambulance:client:startBleedout')
        end
    end)
end

-- ── Bleedout ───────────────────────────────────────────────────────────────

AddEventHandler('hbs_ambulance:client:startBleedout', function()
    if bleedoutActive then return end
    bleedoutActive = true
    bleedoutSecs   = Config.BleedoutTime

    if not LocalState.isDowned then
        SetDowned(true)
        TriggerServerEvent('hbs_ambulance:server:playerDowned')
    end

    ShowDeathScreen(bleedoutSecs)

    CreateThread(function()
        while bleedoutActive and bleedoutSecs > 0 do
            Wait(1000)
            bleedoutSecs = bleedoutSecs - 1
            SendNUIMessage({ action = 'updateTimer', timeRemaining = bleedoutSecs })
        end
        if bleedoutActive then
            -- Timer ran out — force respawn screen
            TriggerServerEvent('hbs_ambulance:server:recordDeath', {
                x = GetEntityCoords(PlayerPedId()).x,
                y = GetEntityCoords(PlayerPedId()).y,
                z = GetEntityCoords(PlayerPedId()).z,
                will = '',
            })
            SendNUIMessage({ action = 'forceRespawn' })
        end
    end)
end)

-- ── Health monitor ─────────────────────────────────────────────────────────

CreateThread(function()
    while true do
        Wait(300)
        if not IsPlayerLoaded() then goto continue end

        local ped    = PlayerPedId()
        local health = GetEntityHealth(ped)  -- 0-200 (100 = zero hp in gameplay)

        if health <= 100 and not LocalState.isDowned then
            StartLastStand()
        end

        lastHealth = health
        ::continue::
    end
end)

-- ── Revived by EMS ─────────────────────────────────────────────────────────

RegisterNetEvent('hbs_ambulance:client:revived', function()
    bleedoutActive  = false
    lastStandActive = false
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
