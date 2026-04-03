-- HBS EMS: ox_target actions, revive/treat with research unlocks, downed blips

local downedBlips = {}
local carryActive = false
local carriedPed  = nil
local carriedSrc  = nil

-- ── Helpers ───────────────────────────────────────────────────────────────

local function PedToServerId(ped)
    for _, pid in ipairs(GetActivePlayers()) do
        if GetPlayerPed(pid) == ped then
            return GetPlayerServerId(pid)
        end
    end
end

local function PedIsDowned(ped)
    local srv = PedToServerId(ped)
    if not srv then return false end
    return GetStateBagValue('player:' .. srv, HBS.Keys.isDowned) == true
end

-- ── Minigame ─────────────────────────────────────────────────────────────

local _mgResult  = nil
local _mgActive  = false

RegisterNuiCallback('minigameResult', function(data, cb)
    _mgResult = data.success == true
    _mgActive = false
    cb('ok')
end)

-- Runs the NUI precision bar minigame.
-- E key presses are detected in Lua and forwarded to JS.
-- Returns true on success, false on failure or timeout.
local function RunMinigame(theme, difficulty)
    if _mgActive then return false end
    _mgResult = nil
    _mgActive = true

    local diff   = ({ easy = 1, medium = 2, hard = 3 })[difficulty] or 2
    local rounds = diff
    local timeoutMs = rounds * 9000 + 2000

    SendNUIMessage({ action = 'startMinigame', theme = theme, difficulty = difficulty, rounds = rounds })

    local deadline = GetGameTimer() + timeoutMs
    while _mgActive and GetGameTimer() < deadline do
        Wait(0)
        if IsControlJustPressed(0, 38) then   -- E / INPUT_PICKUP
            SendNUIMessage({ action = 'minigamePress' })
        end
    end

    if _mgActive then   -- timed out
        _mgActive = false
        SendNUIMessage({ action = 'stopMinigame' })
        return false
    end

    return _mgResult == true
end

-- ── Helpers for difficulty by patient injury severity ─────────────────────

local function GetPatientWorstInjury(targetSrc)
    local injuries = HBS.GetRemote(targetSrc, 'injuries') or {}
    local worst = nil
    if type(injuries) == 'table' then
        for _, sev in pairs(injuries) do
            if not worst or (InjuryDefs.Ranks[sev] or 0) > (InjuryDefs.Ranks[worst] or 0) then
                worst = sev
            end
        end
    end
    return worst
end

local function SeverityToDifficulty(sev)
    if sev == 'critical' then return 'hard'
    elseif sev == 'fracture' then return 'medium'
    else return 'easy' end
end

local function SuggestTriage(targetSrc)
    local worst = GetPatientWorstInjury(targetSrc)
    if worst == 'critical' then return 'critical'
    elseif worst == 'fracture' then return 'moderate'
    else return 'minor' end
end

-- ── Play animation helper ─────────────────────────────────────────────────

local function PlayAnim(dict, clip, flag)
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do Wait(10) end
    TaskPlayAnim(cache.ped, dict, clip, 8.0, -8.0, -1, flag, 0, false, false, false)
end

-- ── Revive ────────────────────────────────────────────────────────────────

local function Revive(targetSrc)
    if HBSConfig.ReviveRequiresItem and not HBSHasUnlock('hands_only_revive') then
        if exports.ox_inventory:Search('count', HBSConfig.ReviveItem) < 1 then
            exports.qbx_core:Notify('You need a ' .. HBSConfig.ReviveItem .. '.', 'error')
            return
        end
    end

    PlayAnim('missambulance', 'amb_action_treat_b_doctor', 49)
    local difficulty = HBSHasUnlock('rapid_revive') and 'easy' or 'medium'
    local success = RunMinigame('defib', difficulty)
    ClearPedTasks(cache.ped)

    if success then
        TriggerServerEvent('hbs_ambulance:server:emsRevive', targetSrc)
    else
        TriggerServerEvent('hbs_ambulance:server:minigameFailed', targetSrc, 'revive')
        exports.qbx_core:Notify('Shock failed — poor timing.', 'error')
    end
end

-- ── Treat wounds ──────────────────────────────────────────────────────────

local function TreatWounds(targetSrc)
    local worst = GetPatientWorstInjury(targetSrc)
    local difficulty = SeverityToDifficulty(worst)

    PlayAnim('mini@repair', 'fixing_a_ped', 16)
    local success = RunMinigame('treat', difficulty)
    ClearPedTasks(cache.ped)

    if success then
        TriggerServerEvent('hbs_ambulance:server:emsTreat', targetSrc)
        exports.qbx_core:Notify('Wounds treated successfully.', 'success')
    else
        TriggerServerEvent('hbs_ambulance:server:minigameFailed', targetSrc, 'treat')
        exports.qbx_core:Notify('Treatment failed — patient stressed.', 'error')
    end
end

-- ── Carry ─────────────────────────────────────────────────────────────────

local StopCarry  -- forward declaration so StartCarry's closure can reference it

local function StartCarry(targetSrc, targetPed)
    if carryActive then return end
    carryActive = true
    carriedPed  = targetPed
    carriedSrc  = targetSrc

    local myPed     = cache.ped
    local boneIndex = GetPedBoneIndex(myPed, 57005)
    AttachEntityToEntity(targetPed, myPed, boneIndex, 0.5, 0.0, 0.0, 0.0, 0.0, 0.0, true, true, false, true, 1, true)

    TriggerServerEvent('hbs_ambulance:server:setCarried', targetSrc, true)

    -- Add ox_target option on the carried ped to put them down
    exports.ox_target:addLocalEntity(targetPed, {
        {
            name     = 'hbs_put_down_' .. targetSrc,
            icon     = 'fa-solid fa-person-walking-arrow-right',
            label    = 'Put Down Patient',
            distance = 2.0,
            onSelect = function()
                StopCarry()
            end,
        },
    })
end

StopCarry = function()
    if not carryActive then return end
    if carriedPed then
        exports.ox_target:removeLocalEntity(carriedPed, { 'hbs_put_down_' .. (carriedSrc or '') })
        DetachEntity(carriedPed, true, true)
    end
    TriggerServerEvent('hbs_ambulance:server:setCarried', carriedSrc, false)
    carryActive = false
    carriedPed  = nil
    carriedSrc  = nil
end

-- ── ox_target global player options ───────────────────────────────────────

exports.ox_target:addGlobalPlayer({
    {
        label       = 'Revive with First Aid Kit',
        icon        = 'fas fa-kit-medical',
        distance    = 3.0,
        canInteract = function(entity)
            if HBSIsEMS() then return false end -- EMS uses the proper revive option
            if not PedIsDowned(entity) then return false end
            return exports.ox_inventory:GetItemCount(cache.playerId, 'firstaidkit') >= 1
        end,
        onSelect    = function(data)
            local srv = PedToServerId(data.entity)
            if not srv then return end
            CreateThread(function()
                local cfg  = HBSConfig.MedicalItems['firstaidkit']
                local dict = cfg.animation and cfg.animation.dict
                local clip = cfg.animation and cfg.animation.anim
                if dict then
                    RequestAnimDict(dict)
                    while not HasAnimDictLoaded(dict) do Wait(10) end
                end
                if lib.progressCircle({
                    duration     = (cfg.civilianReviveTime or 20) * 1000,
                    label        = 'Treating downed player...',
                    useWhileDead = false,
                    canCancel    = true,
                    disable      = { move = true, car = true, combat = true },
                    anim         = dict and { dict = dict, clip = clip, flag = 49 } or nil,
                }) then
                    TriggerServerEvent('hbs_ambulance:server:civilianRevive', 'firstaidkit', srv)
                end
            end)
        end,
    },
    {
        label       = 'Revive Patient',
        icon        = 'fas fa-heartbeat',
        distance    = 3.0,
        canInteract = function(entity) return HBSIsEMS() and PedIsDowned(entity) end,
        onSelect    = function(data)
            local srv = PedToServerId(data.entity)
            if srv then CreateThread(function() Revive(srv) end) end
        end,
    },
    {
        label       = 'Treat Wounds',
        icon        = 'fas fa-band-aid',
        distance    = 3.0,
        canInteract = function() return HBSIsEMS() end,
        onSelect    = function(data)
            local srv = PedToServerId(data.entity)
            if srv then CreateThread(function() TreatWounds(srv) end) end
        end,
    },
    {
        label       = 'Examine Patient',
        icon        = 'fas fa-stethoscope',
        distance    = 2.5,
        canInteract = function() return HBSIsEMS() and HBSHasUnlock('patient_examine') end,
        onSelect    = function(data)
            local srv = PedToServerId(data.entity)
            if not srv then return end
            TriggerServerEvent('hbs_ambulance:server:examinePlayer', srv)
        end,
    },
    {
        label       = 'Carry Patient',
        icon        = 'fas fa-hands-holding',
        distance    = 3.0,
        canInteract = function(entity) return HBSIsEMS() and PedIsDowned(entity) and not carryActive end,
        onSelect    = function(data)
            local srv = PedToServerId(data.entity)
            if srv then CreateThread(function() StartCarry(srv, data.entity) end) end
        end,
    },
    {
        label       = 'Triage Patient',
        icon        = 'fas fa-triangle-exclamation',
        distance    = 3.0,
        canInteract = function(entity) return HBSIsEMS() and PedIsDowned(entity) end,
        onSelect    = function(data)
            local srv = PedToServerId(data.entity)
            if not srv then return end
            local suggested = SuggestTriage(srv)
            local function triageOption(level, label, desc)
                local isSuggested = suggested == level
                return {
                    title       = isSuggested and ('★ ' .. label .. ' (Suggested)') or label,
                    description = desc,
                    onSelect    = function() TriggerServerEvent('hbs_ambulance:server:triagePatient', srv, level) end,
                }
            end
            lib.registerContext({
                id      = 'hbs_triage_' .. srv,
                title   = 'Triage Patient',
                options = {
                    triageOption('critical', 'Critical', 'Life-threatening injuries'),
                    triageOption('moderate', 'Moderate', 'Serious but stable'),
                    triageOption('minor',    'Minor',    'Non-life-threatening'),
                },
            })
            lib.showContext('hbs_triage_' .. srv)
        end,
    },
    {
        label       = 'Administer Detox',
        icon        = 'fas fa-flask-vial',
        distance    = 3.0,
        canInteract = function() return HBSIsEMS() and HBSHasUnlock('addiction_therapy') end,
        onSelect    = function(data)
            local srv = PedToServerId(data.entity)
            if not srv then return end
            CreateThread(function()
                PlayAnim('mp_suicide', 'pill', 49)
                local success = RunMinigame('detox', 'medium')
                ClearPedTasks(cache.ped)
                if success then
                    TriggerServerEvent('hbs_ambulance:server:administerDetox', srv)
                else
                    exports.qbx_core:Notify('Injection failed — imprecise dosage.', 'error')
                end
            end)
        end,
    },
    {
        label       = 'Full Detox Treatment',
        icon        = 'fas fa-shield-virus',
        distance    = 3.0,
        canInteract = function() return HBSIsEMS() and HBSHasUnlock('full_detox') end,
        onSelect    = function(data)
            local srv = PedToServerId(data.entity)
            if not srv then return end
            CreateThread(function()
                PlayAnim('mini@crate_search@std@ps', 'crate_search_ps_std', 49)
                local success = RunMinigame('detox', 'hard')
                ClearPedTasks(cache.ped)
                if success then
                    TriggerServerEvent('hbs_ambulance:server:fullDetox', srv)
                else
                    exports.qbx_core:Notify('Full detox failed — procedure aborted.', 'error')
                end
            end)
        end,
    },
})

-- ── Downed blips (EMS only) ───────────────────────────────────────────────

RegisterNetEvent('hbs_ambulance:client:updateDownedBlips', function(list)
    for _, b in pairs(downedBlips) do RemoveBlip(b) end
    downedBlips = {}
    if not HBSIsEMS() then return end

    for _, entry in ipairs(list) do
        local blip = AddBlipForCoord(entry.x, entry.y, entry.z)
        SetBlipSprite(blip, 153)
        SetBlipColour(blip, entry.triage and HBSConfig.InjurySeverity and 1 or 1)
        SetBlipScale(blip, 0.8)
        SetBlipAsShortRange(blip, false)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName('Downed Player')
        EndTextCommandSetBlipName(blip)
        downedBlips[entry.src] = blip
    end
end)

-- ── Examine result display ────────────────────────────────────────────────

RegisterNetEvent('hbs_ambulance:client:examineResult', function(result)
    local sevLabels = { scratch = 'Scratch', minor = 'Minor', fracture = 'Fracture', critical = 'Critical' }
    local addLabels = HBSConfig.Addiction.levelLabels

    -- Build injury rows
    local injuryRows = {}
    local hasInjuries = false
    for part, sev in pairs(result.injuries or {}) do
        hasInjuries = true
        injuryRows[#injuryRows + 1] = {
            title    = part:gsub('_', ' '):gsub('^%l', string.upper),
            description = sevLabels[sev] or sev,
            disabled = true,
        }
    end
    if not hasInjuries then
        injuryRows[1] = { title = 'No injuries detected', disabled = true }
    end

    -- Build addiction rows
    local addRows = {}
    local hasAddiction = false
    for substance, level in pairs(result.addiction or {}) do
        if level > 0 then
            hasAddiction = true
            addRows[#addRows + 1] = {
                title       = substance:gsub('^%l', string.upper),
                description = addLabels[level] or tostring(level),
                disabled    = true,
            }
        end
    end
    if not hasAddiction then
        addRows[1] = { title = 'No substance dependency', disabled = true }
    end

    lib.registerContext({
        id      = 'hbs_examine_result',
        title   = ('Patient: %s'):format(result.playerName or 'Unknown'),
        options = {
            { title = ('Stress Level: %d%%'):format(result.stress or 0), disabled = true },
            {
                title    = 'Injuries',
                icon     = 'fas fa-bone',
                onSelect = function()
                    lib.registerContext({ id = 'hbs_examine_injuries', title = 'Injuries', menu = 'hbs_examine_result', options = injuryRows })
                    lib.showContext('hbs_examine_injuries')
                end,
            },
            {
                title    = 'Substance Dependency',
                icon     = 'fas fa-pills',
                onSelect = function()
                    lib.registerContext({ id = 'hbs_examine_addiction', title = 'Substance Dependency', menu = 'hbs_examine_result', options = addRows })
                    lib.showContext('hbs_examine_addiction')
                end,
            },
        },
    })
    lib.showContext('hbs_examine_result')
end)

-- ── EMS XP / research state sync ─────────────────────────────────────────

RegisterNetEvent('hbs_ambulance:client:emsResearchUpdate', function(data)
    HBSState.emsResearch = data
end)
