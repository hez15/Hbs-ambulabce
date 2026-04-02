-- NUI bridge: sends state updates to the HTML HUD

local hudVisible = false

-- ── Show / Hide ────────────────────────────────────────────────────────────

local function ShowHud()
    hudVisible = true
    SendNUIMessage({ action = 'showHud' })
end

local function HideHud()
    hudVisible = false
    SendNUIMessage({ action = 'hideHud' })
end

-- ── Full state push ────────────────────────────────────────────────────────

local function PushHud()
    if not hudVisible then return end
    SendNUIMessage({
        action    = 'updateHud',
        injuries  = LocalState.injuries,
        stress    = LocalState.stress,
        isDowned  = LocalState.isDowned,
        inPain    = LocalState.inPain,
        bloodloss = LocalState.bloodloss,
        addiction = LocalState.addiction,
    })
end

-- ── Events ─────────────────────────────────────────────────────────────────

AddEventHandler('hbs_ambulance:client:hudUpdate',   PushHud)
AddEventHandler('hbs_ambulance:client:hideHud',     HideHud)
AddEventHandler('hbs_ambulance:client:stateLoaded', ShowHud)
AddEventHandler('QBCore:Client:OnPlayerLoaded',     ShowHud)
AddEventHandler('qbx_core:playerLoaded',             ShowHud)

-- ── Periodic refresh (safety net) ──────────────────────────────────────────

CreateThread(function()
    while true do
        Wait(3000)
        if IsPlayerLoaded() then PushHud() end
    end
end)

-- ── NUI Callbacks ──────────────────────────────────────────────────────────

RegisterNUICallback('respawn', function(data, cb)
    local willText = (data and data.will) or ''
    -- Forward to death module via event
    TriggerEvent('hbs_ambulance:client:confirmRespawn', willText)
    cb({ ok = true })
end)

RegisterNUICallback('closeHud', function(_, cb)
    cb({ ok = true })
end)
