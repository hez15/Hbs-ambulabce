-- HBS bootstrap: shared client state, framework hooks, helpers

HBSState = {
    isDowned   = false,
    injuries   = {},
    stress     = 0,
    inPain     = false,
    bloodloss  = false,
    addiction  = {},
    loaded     = false,
    emsResearch = { tier = 1, xp = 0, unlocks = {} },
}

-- ── Notify helper ─────────────────────────────────────────────────────────

function HBSNotify(msg, ntype, duration)
    exports.qbx_core:Notify(msg, ntype or 'inform', duration or 4000)
end

-- ── EMS check (client) ────────────────────────────────────────────────────

function HBSIsEMS()
    return QBX.PlayerData.job and QBX.PlayerData.job.type == 'ems'
end

function HBSHasUnlock(ability)
    if not HBSState.emsResearch then return false end
    if HBSUtils.TableContains(HBSState.emsResearch.unlocks, ability) then return true end
    local abCfg = HBSConfig.EMSResearch.abilities[ability]
    return abCfg and (HBSState.emsResearch.tier or 1) >= abCfg.tier
end

-- ── Player loaded / unloaded ──────────────────────────────────────────────

-- Guard against QBX firing both QBCore:Client:OnPlayerLoaded AND
-- qbx_core:playerLoaded in the same session, which would double-call
-- OnPlayerLoaded and send getPlayerState twice.
local _playerLoadInProgress = false

local function OnPlayerLoaded()
    if _playerLoadInProgress then
        HBSUtils.Debug('client', 'OnPlayerLoaded called again while already loading — skipping duplicate')
        return
    end
    _playerLoadInProgress = true

    SetEntityInvincible(cache.ped, false)

    lib.callback('hbs_ambulance:server:getPlayerState', false, function(data)
        _playerLoadInProgress = false

        if not data then
            HBSUtils.Debug('client', 'getPlayerState returned nil — server may not have citizen ID yet')
            HBSState.loaded = true
            TriggerEvent('hbs:client:stateLoaded')
            return
        end

        local research = data.emsResearch or { tier = 1, xp = 0, unlocks = {} }

        HBSState.injuries    = data.injuries  or {}
        HBSState.stress      = data.stress    or 0
        HBSState.addiction   = data.addiction or {}
        HBSState.emsResearch = research
        HBSState.emsTier     = research.tier    or 1
        HBSState.emsXP       = research.xp      or 0
        HBSState.emsUnlocks  = research.unlocks or {}
        -- Mark loaded AFTER data is populated so ticks see valid state
        HBSState.loaded = true

        HBS.SetLocal('injuries',  HBSState.injuries)
        HBS.SetLocal('stress',    HBSState.stress)
        HBS.SetLocal('addiction', HBSState.addiction)

        HBSUtils.Debug('client', ('state loaded: tier=%d xp=%d stress=%d'):format(
            HBSState.emsTier, HBSState.emsXP, HBSState.stress))

        TriggerEvent('hbs:client:stateLoaded')
        TriggerEvent('hbs:client:hudUpdate')
    end)
end

local function OnPlayerUnloaded()
    _playerLoadInProgress = false
    HBSState = {
        isDowned = false, injuries = {}, stress = 0,
        inPain = false, bloodloss = false, addiction = {},
        loaded = false, emsResearch = { tier = 1, xp = 0, unlocks = {} },
    }
    SendNUIMessage({ action = 'hideHud' })
end

AddEventHandler('QBCore:Client:OnPlayerLoaded',   OnPlayerLoaded)
AddEventHandler('QBCore:Client:OnPlayerUnloaded', OnPlayerUnloaded)
AddEventHandler('qbx_core:playerLoaded',           OnPlayerLoaded)
AddEventHandler('qbx_core:playerUnloaded',          OnPlayerUnloaded)

-- ── Generic notify from server ────────────────────────────────────────────

RegisterNetEvent('hbs_ambulance:client:notify', function(ntype, msg)
    exports.qbx_core:Notify(msg or ntype, type(ntype) == 'string' and ntype or 'inform', 5000)
end)

function IsHBSLoaded() return HBSState.loaded end
