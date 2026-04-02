-- Client bootstrap: framework hooks, shared local state

-- ── Shared local state (all modules read/write this) ───────────────────────
LocalState = {
    isDowned   = false,
    injuries   = {},   -- { head = 'fracture', left_leg = 'scratch', ... }
    stress     = 0,
    inPain     = false,
    bloodloss  = false,
    isCarried  = false,
    addiction  = {},   -- { morphine = 2, painkiller = 0, ... }
    loaded     = false,
}

-- ── Framework reference ────────────────────────────────────────────────────

local function OnPlayerLoaded()
    LocalState.loaded = true
    Utils.Debug('Player loaded — fetching state from server')

    lib.callback('hbs_ambulance:getPlayerState', false, function(data)
        if not data then return end
        LocalState.injuries = data.injuries or {}
        LocalState.stress   = data.stress   or 0
        LocalState.isDowned = data.isDowned or false
        LocalState.addiction= data.addiction or {}

        SB.SetLocal('injuries',  LocalState.injuries)
        SB.SetLocal('stress',    LocalState.stress)
        SB.SetLocal('isDowned',  LocalState.isDowned)
        SB.SetLocal('addiction', LocalState.addiction)

        TriggerEvent('hbs_ambulance:client:stateLoaded')
        TriggerEvent('hbs_ambulance:client:hudUpdate')
        TriggerEvent('hbs_ambulance:client:applyInjuryEffects')
        TriggerEvent('hbs_ambulance:client:applyAddictionEffects')
    end)
end

local function OnPlayerUnloaded()
    LocalState = {
        isDowned  = false, injuries = {}, stress = 0,
        inPain    = false, bloodloss = false, isCarried = false,
        addiction = {}, loaded = false,
    }
    TriggerEvent('hbs_ambulance:client:hideHud')
end

AddEventHandler('QBCore:Client:OnPlayerLoaded',   OnPlayerLoaded)
AddEventHandler('QBCore:Client:OnPlayerUnloaded', OnPlayerUnloaded)
AddEventHandler('qbx_core:playerLoaded',           OnPlayerLoaded)
AddEventHandler('qbx_core:playerUnloaded',          OnPlayerUnloaded)

-- ── Generic notify from server ─────────────────────────────────────────────

RegisterNetEvent('hbs_ambulance:client:notify', function(data)
    if not data then return end
    lib.notify({ title = data.msg, type = data.type or 'inform', duration = 5000 })
end)

-- ── Accessor ───────────────────────────────────────────────────────────────

function IsPlayerLoaded() return LocalState.loaded end

-- ── Notify helper (used across modules) ───────────────────────────────────

function Notify(msg, ntype, duration)
    lib.notify({
        title    = msg,
        type     = ntype or 'inform',
        duration = duration or 4000,
    })
end
