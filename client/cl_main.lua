-- HBS bootstrap: shared client state, framework hooks, helpers

HBSState = {
    isDowned    = false,
    injuries    = {},
    stress      = 0,
    inPain      = false,
    bloodloss   = false,
    addiction   = {},
    diseases    = {},
    loaded      = false,
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
        HBSState.diseases    = data.diseases  or {}
        HBSState.emsResearch = research
        HBSState.emsTier     = research.tier    or 1
        HBSState.emsXP       = research.xp      or 0
        HBSState.emsUnlocks  = research.unlocks or {}
        -- Mark loaded AFTER data is populated so ticks see valid state
        HBSState.loaded = true

        HBS.SetLocal('injuries',  HBSState.injuries)
        HBS.SetLocal('stress',    HBSState.stress)
        HBS.SetLocal('addiction', HBSState.addiction)
        HBS.SetLocal('diseases',  HBSState.diseases)

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
        diseases = {}, loaded = false,
        emsResearch = { tier = 1, xp = 0, unlocks = {} },
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

-- ── /checkme — self medical status ───────────────────────────────────────────

local SEV_ICONS = { scratch = '🟡', minor = '🟠', fracture = '🔵', critical = '🔴' }
local SEV_LABEL = { scratch = 'Scratch', minor = 'Minor Wound', fracture = 'Fracture', critical = 'Critical' }

RegisterCommand('checkme', function()
    if not IsHBSLoaded() then
        HBSNotify('Medical data not loaded yet.', 'error')
        return
    end

    local ped    = cache.ped
    local maxHp  = GetEntityMaxHealth(ped)
    local hp     = GetEntityHealth(ped)
    local hpPct  = math.floor(math.max(0, (hp - 100) / (maxHp - 100)) * 100)
    local stress = math.floor((HBSState.stress or 0))

    local options = {}

    -- Health
    options[#options + 1] = {
        title       = 'Health',
        description = hpPct .. '%',
        icon        = 'fas fa-heart',
        iconColor   = hpPct < 30 and '#e03030' or (hpPct < 60 and '#f97316' or '#22c55e'),
        disabled    = true,
    }

    -- Stress
    options[#options + 1] = {
        title       = 'Stress',
        description = stress .. '%',
        icon        = 'fas fa-brain',
        iconColor   = stress > 75 and '#e03030' or (stress > 40 and '#f97316' or '#94a3b8'),
        disabled    = true,
    }

    -- Injuries
    local injuryCount = 0
    for part, sev in pairs(HBSState.injuries) do
        injuryCount = injuryCount + 1
        local partLabel = part:gsub('_', ' '):gsub('^%l', string.upper)
        options[#options + 1] = {
            title       = (SEV_ICONS[sev] or '⚪') .. ' ' .. partLabel,
            description = SEV_LABEL[sev] or sev,
            icon        = 'fas fa-bone',
            iconColor   = sev == 'critical' and '#e03030' or (sev == 'fracture' and '#60a5fa' or '#f97316'),
            disabled    = true,
        }
    end
    if injuryCount == 0 then
        options[#options + 1] = {
            title = '✅ No Active Injuries',
            icon  = 'fas fa-check',
            iconColor = '#22c55e',
            disabled = true,
        }
    end

    -- Addiction
    local addLabels = HBSConfig.Addiction and HBSConfig.Addiction.levelLabels or {}
    local hasAddiction = false
    for sub, level in pairs(HBSState.addiction or {}) do
        if level > 0 then
            hasAddiction = true
            local subCfg = HBSConfig.Substances and HBSConfig.Substances[sub]
            options[#options + 1] = {
                title       = (subCfg and subCfg.label or sub) .. ' Dependency',
                description = (addLabels[level] or 'Level ' .. level) .. ' (level ' .. level .. '/4)',
                icon        = 'fas fa-pills',
                iconColor   = level >= 3 and '#e03030' or '#a78bfa',
                disabled    = true,
            }
        end
    end

    -- Diseases
    local hasDisease = false
    for disease, stage in pairs(HBSState.diseases or {}) do
        hasDisease = true
        local dcfg = HBSConfig.Diseases and HBSConfig.Diseases[disease]
        options[#options + 1] = {
            title       = (dcfg and dcfg.label or disease),
            description = 'Stage ' .. stage .. ' / ' .. (dcfg and dcfg.stages or '?'),
            icon        = 'fas fa-virus',
            iconColor   = '#f97316',
            disabled    = true,
        }
    end

    if not hasAddiction and not hasDisease then
        options[#options + 1] = {
            title     = '✅ Clean — No Dependency or Disease',
            icon      = 'fas fa-shield-heart',
            iconColor = '#22c55e',
            disabled  = true,
        }
    end

    lib.registerContext({ id = 'hbs_self_check', title = '🏥 My Medical Status', options = options })
    lib.showContext('hbs_self_check')
end, false)
