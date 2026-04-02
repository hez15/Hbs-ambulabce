-- EMS Research client: research menu, duty toggle, advanced ability interactions

-- ── Local EMS research state (mirrors state bags) ─────────────────────────
EMSResearch = {
    tier     = 1,
    xp       = 0,
    unlocks  = {},
    onDuty   = false,
    mentorTier = nil,  -- temporary mentor boost tier
}

-- Per-target hands-only cooldown display (client side, seconds remaining)
local handsOnlyCooldownEnd = {}   -- { [targetSrc] = os.time() expiry }

-- ── Helpers ───────────────────────────────────────────────────────────────

local function IsEMS()
    local pd = exports.qbx_core:GetPlayerData()
    return pd and pd.job and pd.job.name == Config.EmsJob
end

local function GetEffectiveTier()
    return math.max(EMSResearch.tier, EMSResearch.mentorTier or 0)
end

local function HasUnlock(ability)
    if Utils.TableContains(EMSResearch.unlocks, ability) then return true end
    if EMSResearch.mentorTier then
        local abCfg = Config.EMSResearch.abilities[ability]
        if abCfg and abCfg.tier <= EMSResearch.mentorTier then return true end
    end
    return false
end

-- Get effective revive time (rapid_revive reduces by 30%)
function GetReviveTime()
    if HasUnlock('rapid_revive') then
        return math.floor(Config.ReviveTime * 0.7)
    end
    return Config.ReviveTime
end

-- ── Load EMS research on player load ─────────────────────────────────────

AddEventHandler('hbs_ambulance:client:stateLoaded', function()
    if not IsEMS() then return end
    lib.callback('hbs_ambulance:getEMSResearch', false, function(data)
        if not data then return end
        EMSResearch.tier    = data.tier    or 1
        EMSResearch.xp      = data.xp      or 0
        EMSResearch.unlocks = data.unlocks or {}
    end)
end)

-- ── Duty toggle ───────────────────────────────────────────────────────────

local dutyTickThread = nil

local function SetDuty(onDuty)
    EMSResearch.onDuty = onDuty
    SB.SetLocal('onDuty', onDuty)
    TriggerServerEvent('hbs_ambulance:server:setDuty', onDuty)

    if onDuty then
        Notify('You are now on duty. Passive XP active.', 'success')
        -- Start passive XP tick
        if not dutyTickThread then
            dutyTickThread = CreateThread(function()
                while EMSResearch.onDuty do
                    Wait(Config.EMSResearch.dutyPassiveInterval * 1000)
                    if EMSResearch.onDuty then
                        TriggerServerEvent('hbs_ambulance:server:dutyXPTick')
                    end
                end
                dutyTickThread = nil
            end)
        end
    else
        Notify('You are now off duty.', 'inform')
    end
end

RegisterCommand('emsduty', function()
    if not IsEMS() then return end
    SetDuty(not EMSResearch.onDuty)
end, false)

-- ── First responder check (called when EMS gets near a downed player) ─────

function CheckFirstResponder(downedSrc)
    TriggerServerEvent('hbs_ambulance:server:checkFirstResponder', downedSrc)
end

-- ── XP progress bar string helper ─────────────────────────────────────────

local function XPBarString(xp, nextThreshold)
    if not nextThreshold then return 'MAX TIER' end
    local pct   = math.floor((xp / nextThreshold) * 20)
    local filled= string.rep('█', pct)
    local empty = string.rep('░', 20 - pct)
    return string.format('%s%s  %d / %d XP', filled, empty, xp, nextThreshold)
end

-- ── Research Menu ─────────────────────────────────────────────────────────

local function BuildUnlockOptions(tier, unlocks)
    local options = {}
    -- Collect abilities for this tier
    local tierAbilities = {}
    for key, ab in pairs(Config.EMSResearch.abilities) do
        if ab.tier == tier then
            table.insert(tierAbilities, { key = key, ab = ab })
        end
    end

    -- Count used slots
    local usedSlots = 0
    for _, entry in ipairs(tierAbilities) do
        if Utils.TableContains(unlocks, entry.key) then
            usedSlots = usedSlots + 1
        end
    end

    -- Find tier config for slot count
    local slotCount = 0
    for _, t in ipairs(Config.EMSResearch.tiers) do
        if t.tier == tier then slotCount = t.unlockSlots; break end
    end
    local slotsRemaining = slotCount - usedSlots

    for _, entry in ipairs(tierAbilities) do
        local isUnlocked = Utils.TableContains(unlocks, entry.key)
        local label
        if isUnlocked then
            label = '✅ ' .. entry.ab.label
        elseif slotsRemaining > 0 then
            label = '🔬 ' .. entry.ab.label .. ' (Unlock)'
        else
            label = '🔒 ' .. entry.ab.label .. ' (Slots full)'
        end

        table.insert(options, {
            title       = label,
            description = entry.ab.desc,
            disabled    = isUnlocked or slotsRemaining <= 0,
            onSelect    = not isUnlocked and slotsRemaining > 0 and function()
                TriggerServerEvent('hbs_ambulance:server:unlockAbility', entry.key)
            end or nil,
        })
    end
    return options
end

local function OpenResearchMenu()
    lib.callback('hbs_ambulance:getEMSResearch', false, function(data)
        if not data then return end
        EMSResearch.tier    = data.tier
        EMSResearch.xp      = data.xp
        EMSResearch.unlocks = data.unlocks

        local tierCfg = nil
        for _, t in ipairs(Config.EMSResearch.tiers) do
            if t.tier == data.tier then tierCfg = t; break end
        end
        local tierLabel = tierCfg and tierCfg.label or 'EMT'
        local xpBar     = XPBarString(data.xp, data.nextThreshold)
        local dutyTxt   = EMSResearch.onDuty and '🟢 On Duty' or '🔴 Off Duty'

        -- Build per-tier unlock sections
        local options = {
            {
                title       = dutyTxt,
                description = 'Toggle duty status to earn passive XP',
                onSelect    = function()
                    SetDuty(not EMSResearch.onDuty)
                end,
            },
            {
                title       = 'Rank: ' .. tierLabel,
                description = xpBar,
                disabled    = true,
            },
        }

        -- Add unlock sections for tiers up to current
        for _, t in ipairs(Config.EMSResearch.tiers) do
            if t.tier > 1 and t.tier <= data.tier then
                local tierOptions = BuildUnlockOptions(t.tier, data.unlocks)
                if #tierOptions > 0 then
                    table.insert(options, {
                        title    = '── Tier ' .. t.tier .. ' — ' .. t.label .. ' ──',
                        disabled = true,
                    })
                    for _, opt in ipairs(tierOptions) do
                        table.insert(options, opt)
                    end
                end
            end
        end

        -- Locked future tiers preview
        for _, t in ipairs(Config.EMSResearch.tiers) do
            if t.tier > data.tier then
                table.insert(options, {
                    title       = '🔒 Tier ' .. t.tier .. ' — ' .. t.label,
                    description = 'Requires ' .. t.xpRequired .. ' XP',
                    disabled    = true,
                })
            end
        end

        lib.registerContext({
            id      = 'hbs_ems_research_menu',
            title   = '🏥 EMS Research',
            options = options,
        })
        lib.showContext('hbs_ems_research_menu')
    end)
end

-- ── Advanced Ability: Examine Patient (Tier 2 — patient_examine) ──────────

function ExaminePatient(targetSrc, targetPed)
    if not HasUnlock('patient_examine') then return false end

    -- Read target state bags
    local injuries  = GetStateBagValue('player:' .. targetSrc, SB.Keys.injuries) or {}
    local stress    = GetStateBagValue('player:' .. targetSrc, SB.Keys.stress)   or 0
    local addiction = GetStateBagValue('player:' .. targetSrc, SB.Keys.addiction) or {}

    local injuryLines = {}
    for part, sev in pairs(injuries) do
        table.insert(injuryLines, string.format('%s: %s', part:gsub('_', ' '), sev:gsub('_', ' ')))
    end
    if #injuryLines == 0 then injuryLines = { 'No injuries detected' } end

    local addictionLines = {}
    for sub, lvl in pairs(addiction) do
        if lvl > 0 then
            local levelLabel = (Config.Addiction.levelLabels or {})[lvl] or ('Level ' .. lvl)
            table.insert(addictionLines, string.format('%s: %s', sub, levelLabel))
        end
    end

    local options = {
        { title = 'Injuries',      description = table.concat(injuryLines, ', '),    disabled = true },
        { title = 'Stress Level',  description = string.format('%d / 100', stress),  disabled = true },
        { title = 'Addiction',     description = #addictionLines > 0 and table.concat(addictionLines, ', ') or 'None detected', disabled = true },
    }

    if #addictionLines > 0 then
        table.insert(options, {
            title       = 'Treatment Options',
            description = 'Administer methadone via [K] to reduce addiction level',
            disabled    = true,
        })
    end

    lib.registerContext({ id = 'hbs_examine_patient', title = 'Patient Examination', options = options })
    lib.showContext('hbs_examine_patient')
    return true
end

-- ── Advanced Ability: Administer Meds (Tier 3 — administer_meds) ─────────

function AdministerMeds(targetSrc)
    if not HasUnlock('administer_meds') then return false end

    -- Check patient addiction for methadone description
    local addiction    = GetStateBagValue('player:' .. targetSrc, SB.Keys.addiction) or {}
    local worstLevel   = 0
    local worstSub     = nil
    for sub, lvl in pairs(addiction) do
        if lvl > worstLevel then worstLevel = lvl; worstSub = sub end
    end
    local methDesc = worstSub and worstLevel > 0
        and string.format('Reduce %s addiction (Level %d → %d)', worstSub, worstLevel, math.max(0, worstLevel - 1))
        or  'No active addiction detected'

    lib.registerContext({
        id    = 'hbs_administer_menu',
        title = 'Administer Medication',
        options = {
            {
                title       = 'Morphine',
                description = 'Treat critical/fracture injuries + restore health (may increase addiction)',
                onSelect    = function()
                    RequestAnimDict('mini@repair')
                    while not HasAnimDictLoaded('mini@repair') do Wait(10) end
                    lib.progressBar({
                        duration = 5000, label = 'Administering morphine...',
                        useWhileDead = false, canCancel = true,
                        anim = { dict = 'mini@repair', clip = 'fixing_a_ped', flag = 16 },
                    }, function(done)
                        if done then TriggerServerEvent('hbs_ambulance:server:administerMed', targetSrc, 'morphine') end
                    end)
                end,
            },
            {
                title       = 'Painkiller',
                description = 'Reduce patient stress, restore health, and relieve withdrawal',
                onSelect    = function()
                    RequestAnimDict('mini@repair')
                    while not HasAnimDictLoaded('mini@repair') do Wait(10) end
                    lib.progressBar({
                        duration = 3000, label = 'Administering painkiller...',
                        useWhileDead = false, canCancel = true,
                        anim = { dict = 'mini@repair', clip = 'fixing_a_ped', flag = 16 },
                    }, function(done)
                        if done then TriggerServerEvent('hbs_ambulance:server:administerMed', targetSrc, 'painkiller') end
                    end)
                end,
            },
            {
                title       = 'Methadone',
                description = methDesc .. ' (20 min CD) | +' .. (Config.EMSResearch.xpRewards.addictionTreat or 40) .. ' XP',
                disabled    = worstLevel <= 0,
                onSelect    = function()
                    RequestAnimDict('mini@repair')
                    while not HasAnimDictLoaded('mini@repair') do Wait(10) end
                    lib.progressBar({
                        duration = 8000, label = 'Administering methadone...',
                        useWhileDead = false, canCancel = true,
                        anim = { dict = 'mini@repair', clip = 'fixing_a_ped', flag = 16 },
                    }, function(done)
                        if done then TriggerServerEvent('hbs_ambulance:server:administerMed', targetSrc, 'methadone') end
                    end)
                end,
            },
        },
    })
    lib.showContext('hbs_administer_menu')
    return true
end

-- ── Advanced Ability: Full Surgery (Tier 4 — full_surgery) ───────────────

function FullSurgery(targetSrc)
    if not HasUnlock('full_surgery') then return false end
    RequestAnimDict('mini@repair')
    while not HasAnimDictLoaded('mini@repair') do Wait(10) end
    lib.progressBar({
        duration     = 20000,
        label        = '🔪 Performing surgery...',
        useWhileDead = false,
        canCancel    = true,
        anim         = { dict = 'mini@repair', clip = 'fixing_a_ped', flag = 16 },
    }, function(done)
        if done then TriggerServerEvent('hbs_ambulance:server:fullSurgery', targetSrc) end
    end)
    return true
end

-- ── Advanced Ability: Hands-Only Revive (Tier 5) ─────────────────────────

function HandsOnlyRevive(targetSrc)
    if not HasUnlock('hands_only_revive') then return false end
    -- Client-side cooldown check (visual only — server enforces)
    local expiry = handsOnlyCooldownEnd[targetSrc]
    if expiry and os.time() < expiry then
        local remaining = expiry - os.time()
        Notify(string.format('Hands-only revive on cooldown (%ds).', remaining), 'error')
        return false
    end
    RequestAnimDict('mini@repair')
    while not HasAnimDictLoaded('mini@repair') do Wait(10) end
    lib.progressBar({
        duration     = GetReviveTime() * 1000,
        label        = '🖐 Hands-only resuscitation...',
        useWhileDead = false,
        canCancel    = true,
        anim         = { dict = 'mini@repair', clip = 'fixing_a_ped', flag = 16 },
    }, function(done)
        if done then
            TriggerServerEvent('hbs_ambulance:server:handsOnlyRevive', targetSrc)
            handsOnlyCooldownEnd[targetSrc] = os.time() + Config.EMSResearch.handsOnlyCooldown
        end
    end)
    return true
end

-- ── Advanced Ability: Mentor Boost (Tier 5) ──────────────────────────────

local function FindNearbyEMS(maxDist)
    maxDist = maxDist or 5.0
    local myCoords = GetEntityCoords(PlayerPedId())
    for _, pid in ipairs(GetActivePlayers()) do
        if pid ~= PlayerId() then
            local srv = GetPlayerServerId(pid)
            local ped = GetPlayerPed(pid)
            if #(GetEntityCoords(ped) - myCoords) <= maxDist then
                -- Check if they're EMS (can't easily check job client-side for others, so just send to server)
                return srv
            end
        end
    end
    return nil
end

local function UseMentorBoost()
    if not HasUnlock('mentor_boost') then return end
    local targetSrc = FindNearbyEMS(5.0)
    if not targetSrc then
        Notify('No EMS player nearby to mentor.', 'error')
        return
    end
    TriggerServerEvent('hbs_ambulance:server:mentorBoost', targetSrc)
end

-- ── Mass Casualty Alert (Tier 5) ──────────────────────────────────────────

local function UseMassCasualtyAlert()
    if not HasUnlock('mass_casualty') then return end
    lib.registerContext({
        id    = 'hbs_mass_casualty_confirm',
        title = '⚠ Mass Casualty Alert',
        options = {
            {
                title       = 'Broadcast Alert',
                description = 'Alert ALL online EMS of a mass casualty event',
                onSelect    = function()
                    TriggerServerEvent('hbs_ambulance:server:massCasualtyAlert')
                end,
            },
        },
    })
    lib.showContext('hbs_mass_casualty_confirm')
end

-- ── Key bindings ──────────────────────────────────────────────────────────

CreateThread(function()
    while true do
        Wait(0)
        if not IsPlayerLoaded() or not IsEMS() then Wait(2000); goto continue end

        -- [R] Research menu (when no interaction hint showing and not busy)
        if IsControlJustPressed(0, 45) then   -- R key
            if not LocalState.isDowned then
                OpenResearchMenu()
            end
        end

        -- [M] Mass casualty alert (Tier 5 — mass_casualty)
        if IsControlJustPressed(0, 244) then   -- M key
            if HasUnlock('mass_casualty') then
                UseMassCasualtyAlert()
            end
        end

        -- [N] Mentor boost (Tier 5 — mentor_boost)
        if IsControlJustPressed(0, 249) then   -- N key
            if HasUnlock('mentor_boost') then
                UseMentorBoost()
            end
        end

        ::continue::
    end
end)

-- ── Net events ────────────────────────────────────────────────────────────

-- XP awarded notification
RegisterNetEvent('hbs_ambulance:client:emsXPAwarded', function(amount, totalXP)
    if amount > 0 then
        lib.notify({
            title    = string.format('+%d EMS XP', amount),
            description = string.format('Total: %d XP', totalXP),
            type     = 'inform',
            duration = 3000,
        })
    end
    EMSResearch.xp = totalXP
end)

-- Tier-up notification
RegisterNetEvent('hbs_ambulance:client:emsTierUp', function(newTier, tierLabel)
    EMSResearch.tier = newTier
    lib.notify({
        title       = '🏅 Tier Up!',
        description = string.format('You are now a %s. Open your research menu [R] to unlock new abilities!', tierLabel),
        type        = 'success',
        duration    = 10000,
    })
end)

-- Ability unlocked notification
RegisterNetEvent('hbs_ambulance:client:abilityUnlocked', function(ability, label)
    if not Utils.TableContains(EMSResearch.unlocks, ability) then
        table.insert(EMSResearch.unlocks, ability)
    end
    lib.notify({
        title       = '🔓 Ability Unlocked',
        description = label,
        type        = 'success',
        duration    = 6000,
    })
end)

-- Mentor boost received
RegisterNetEvent('hbs_ambulance:client:mentorBoosted', function(mentorSrc)
    EMSResearch.mentorTier = 2
    Notify('A senior medic has boosted your abilities for 30 minutes!', 'success', 8000)
end)

RegisterNetEvent('hbs_ambulance:client:mentorBoostEnded', function()
    EMSResearch.mentorTier = nil
    Notify('Mentor boost has expired.', 'inform')
end)

-- State bag sync for EMS data
AddStateBagChangeHandler(SB.Keys.emsTier, nil, function(bagName, _, value)
    local myBag = 'player:' .. GetPlayerServerId(PlayerId())
    if bagName ~= myBag then return end
    EMSResearch.tier = value or 1
end)

AddStateBagChangeHandler(SB.Keys.emsUnlocks, nil, function(bagName, _, value)
    local myBag = 'player:' .. GetPlayerServerId(PlayerId())
    if bagName ~= myBag then return end
    EMSResearch.unlocks = value or {}
end)

AddStateBagChangeHandler(SB.Keys.mentorTier, nil, function(bagName, _, value)
    local myBag = 'player:' .. GetPlayerServerId(PlayerId())
    if bagName ~= myBag then return end
    EMSResearch.mentorTier = value
end)
