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
    return abCfg and (HBSState.emsResearch.mentorTier or 0) >= abCfg.tier
end

-- ── Player loaded / unloaded ──────────────────────────────────────────────

local function OnPlayerLoaded()
    HBSState.loaded = true

    SetEntityInvincible(cache.ped, false)

    lib.callback.await('hbs_ambulance:server:getPlayerState', false, function(data)
        if not data then return end
        HBSState.injuries   = data.injuries  or {}
        HBSState.stress     = data.stress    or 0
        HBSState.addiction  = data.addiction or {}
        HBSState.emsResearch= data.emsResearch or { tier = 1, xp = 0, unlocks = {} }

        HBS.SetLocal('injuries',  HBSState.injuries)
        HBS.SetLocal('stress',    HBSState.stress)
        HBS.SetLocal('addiction', HBSState.addiction)

        TriggerEvent('hbs:client:stateLoaded')
        TriggerEvent('hbs:client:hudUpdate')
    end)
end

local function OnPlayerUnloaded()
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

RegisterNetEvent('hbs_ambulance:client:notify', function(data)
    if not data then return end
    exports.qbx_core:Notify(data.msg, data.type or 'inform', 5000)
end)

function IsHBSLoaded() return HBSState.loaded end
