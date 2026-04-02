-- EMS Research / Tier Progression — Server
-- XP awarding, tier-up, unlock selection, advanced ability handlers, admin commands

-- ── In-memory dispatch response tracker ──────────────────────────────────
-- { [src] = os.time() } — timestamp when this EMS last received a dispatch alert
local lastDispatchAlert = {}

-- Hands-only revive per-target cooldown: { [reviverSrc] = { [targetSrc] = os.time() } }
local handsOnlyCooldowns = {}

-- Administer meds per-EMS cooldown: { [src] = os.time() }
local administerCooldowns = {}

-- Methadone per-EMS per-patient cooldown: { [src] = { [targetSrc] = os.time() } }
local methadoneCooldowns = {}

-- ── Helpers ───────────────────────────────────────────────────────────────

local function GetEMSTier(src)
    return SB.Get(src, 'emsTier') or 1
end

local function GetEMSUnlocks(src)
    return SB.Get(src, 'emsUnlocks') or {}
end

local function HasUnlock(src, ability)
    -- Check both permanent unlocks and temporary mentor boost
    local unlocks    = GetEMSUnlocks(src)
    local mentorTier = SB.Get(src, 'mentorTier')
    if Utils.TableContains(unlocks, ability) then return true end
    -- Mentor boost grants all Tier-2 abilities temporarily
    if mentorTier and mentorTier >= 2 then
        local abilityCfg = Config.EMSResearch.abilities[ability]
        if abilityCfg and abilityCfg.tier <= mentorTier then return true end
    end
    return false
end

-- Calculate tier from total XP
local function CalcTier(xp)
    local tier = 1
    for _, t in ipairs(Config.EMSResearch.tiers) do
        if xp >= t.xpRequired then tier = t.tier end
    end
    return tier
end

-- Get tier config entry
local function GetTierCfg(tier)
    for _, t in ipairs(Config.EMSResearch.tiers) do
        if t.tier == tier then return t end
    end
    return Config.EMSResearch.tiers[1]
end

-- Get abilities available for a specific tier
local function GetTierAbilities(tier)
    local list = {}
    for key, ab in pairs(Config.EMSResearch.abilities) do
        if ab.tier == tier then list[key] = ab end
    end
    return list
end

-- Count how many unlocks the player has chosen for a specific tier
local function CountUnlocksForTier(unlocks, tier)
    local count = 0
    for _, key in ipairs(unlocks) do
        local ab = Config.EMSResearch.abilities[key]
        if ab and ab.tier == tier then count = count + 1 end
    end
    return count
end

-- ── Award XP ──────────────────────────────────────────────────────────────

AddEventHandler('hbs_ambulance:server:awardEMSXP', function(src, amount)
    if not Utils.IsEMS(src) then return end
    local cid = Utils.GetCitizenId(src)
    if not cid then return end

    local data    = DB.LoadEMSResearch(cid)
    local oldTier = data.tier
    local newXP   = data.xp + amount
    local newTier = CalcTier(newXP)

    DB.SaveEMSResearch(cid, newTier, newXP, data.unlocks)
    SB.Set(src, 'emsTier', newTier)
    SB.Set(src, 'emsXP',   newXP)

    -- XP notification
    TriggerClientEvent('hbs_ambulance:client:emsXPAwarded', src, amount, newXP)

    -- Tier-up notification
    if newTier > oldTier then
        local tierCfg = GetTierCfg(newTier)
        TriggerClientEvent('hbs_ambulance:client:emsTierUp', src, newTier, tierCfg.label)
        Utils.Debug('EMS tier-up:', cid, oldTier, '->', newTier)
    end
end)

-- ── Unlock Ability ────────────────────────────────────────────────────────

RegisterNetEvent('hbs_ambulance:server:unlockAbility', function(ability)
    local src = source
    if not Utils.IsEMS(src) then return end
    local cid = Utils.GetCitizenId(src)
    if not cid then return end

    local abCfg = Config.EMSResearch.abilities[ability]
    if not abCfg then return end

    local data    = DB.LoadEMSResearch(cid)
    local curTier = data.tier

    -- Must have reached the ability's tier
    if curTier < abCfg.tier then
        TriggerClientEvent('hbs_ambulance:client:notify', src, {
            msg = 'You have not reached the required tier for this ability.', type = 'error'
        })
        return
    end

    -- Already unlocked
    if Utils.TableContains(data.unlocks, ability) then
        TriggerClientEvent('hbs_ambulance:client:notify', src, {
            msg = abCfg.label .. ' is already unlocked.', type = 'inform'
        })
        return
    end

    -- Check unlock slot budget for this tier
    local tierCfg    = GetTierCfg(abCfg.tier)
    local usedSlots  = CountUnlocksForTier(data.unlocks, abCfg.tier)
    if tierCfg.unlockSlots > 0 and usedSlots >= tierCfg.unlockSlots then
        TriggerClientEvent('hbs_ambulance:client:notify', src, {
            msg = 'You have used all unlock slots for this tier. Choose wisely!', type = 'error'
        })
        return
    end

    local newUnlocks = DB.AddEMSUnlock(cid, ability)
    SB.Set(src, 'emsUnlocks', newUnlocks)
    TriggerClientEvent('hbs_ambulance:client:abilityUnlocked', src, ability, abCfg.label)
    Utils.Debug('EMS unlock:', cid, ability)
end)

-- ── Callback: get research data for menu ─────────────────────────────────

lib.callback.register('hbs_ambulance:getEMSResearch', function(source)
    local src = source
    local cid = Utils.GetCitizenId(src)
    if not cid then return nil end
    local data = DB.LoadEMSResearch(cid)
    -- Find next tier threshold
    local nextThreshold = nil
    for _, t in ipairs(Config.EMSResearch.tiers) do
        if t.xpRequired > data.xp then nextThreshold = t.xpRequired; break end
    end
    return {
        tier          = data.tier,
        xp            = data.xp,
        unlocks       = data.unlocks,
        nextThreshold = nextThreshold,
    }
end)

-- ── Duty Toggle ───────────────────────────────────────────────────────────

RegisterNetEvent('hbs_ambulance:server:setDuty', function(onDuty)
    local src = source
    if not Utils.IsEMS(src) then return end
    SB.Set(src, 'onDuty', onDuty)
    Utils.Debug('EMS duty change:', src, onDuty)
end)

-- Passive duty XP (fired by client timer while on duty)
RegisterNetEvent('hbs_ambulance:server:dutyXPTick', function()
    local src = source
    if not Utils.IsEMS(src) then return end
    if not SB.Get(src, 'onDuty') then return end
    TriggerEvent('hbs_ambulance:server:awardEMSXP', src, Config.EMSResearch.xpRewards.dutyPassive)
end)

-- First responder bonus — called when EMS arrives near a downed player
RegisterNetEvent('hbs_ambulance:server:checkFirstResponder', function(downedSrc)
    local src = source
    if not Utils.IsEMS(src) then return end
    local alertTime = lastDispatchAlert[downedSrc]
    if alertTime and (os.time() - alertTime) <= Config.EMSResearch.dispatchWindowSecs then
        TriggerEvent('hbs_ambulance:server:awardEMSXP', src, Config.EMSResearch.xpRewards.firstResponder)
        lastDispatchAlert[downedSrc] = nil   -- only award once per incident
    end
end)

-- Transport delivery bonus — called when patient unloaded at hospital zone
RegisterNetEvent('hbs_ambulance:server:transportDelivery', function()
    local src = source
    if not Utils.IsEMS(src) then return end
    TriggerEvent('hbs_ambulance:server:awardEMSXP', src, Config.EMSResearch.xpRewards.transport)
end)

-- Record dispatch time so first responder bonus can be checked
AddEventHandler('hbs_ambulance:server:dispatchSent', function(downedSrc)
    lastDispatchAlert[downedSrc] = os.time()
end)

-- ── Advanced Abilities ────────────────────────────────────────────────────

-- Tier 3: Administer meds directly to downed player
RegisterNetEvent('hbs_ambulance:server:administerMed', function(targetSrc, medType)
    local src = source
    if not Utils.IsEMS(src) then return end
    if not HasUnlock(src, 'administer_meds') then return end

    -- Cooldown check
    local last = administerCooldowns[src] or 0
    if (os.time() - last) < Config.EMSResearch.administerCooldown then
        local remaining = Config.EMSResearch.administerCooldown - (os.time() - last)
        TriggerClientEvent('hbs_ambulance:client:notify', src, {
            msg = string.format('Med administration on cooldown (%ds remaining).', remaining),
            type = 'error'
        })
        return
    end
    administerCooldowns[src] = os.time()

    local cid = Utils.GetCitizenId(targetSrc)
    if not cid then return end

    if medType == 'morphine' then
        -- Heal critical/fracture injuries + stress reduction
        local injuries = DB.LoadInjuries(cid)
        for part, sev in pairs(injuries) do
            if sev == 'critical' or sev == 'fracture' then
                DB.SaveInjury(cid, part, nil)
                break
            end
        end
        local updated = DB.LoadInjuries(cid)
        SB.Set(targetSrc, 'injuries', updated)
        TriggerClientEvent('hbs_ambulance:client:applyInjuryEffects', targetSrc)
        -- Restore some health
        local ped = GetPlayerPed(targetSrc)
        SetEntityHealth(ped, math.min(200, GetEntityHealth(ped) + 20))
        -- Roll for addiction increase on the patient (EMS-administered morphine still risks addiction)
        TriggerEvent('hbs_ambulance:server:processAddiction', targetSrc, 'morphine')

    elseif medType == 'painkiller' then
        -- Stress reduction + slight health restore
        local curStress = SB.Get(targetSrc, 'stress') or 0
        local newStress = math.max(0, curStress - 15)
        SB.Set(targetSrc, 'stress', newStress)
        DB.SaveStress(cid, newStress)
        TriggerClientEvent('hbs_ambulance:client:setStress', targetSrc, newStress)
        local ped = GetPlayerPed(targetSrc)
        SetEntityHealth(ped, math.min(200, GetEntityHealth(ped) + 10))
        -- Painkiller from EMS also relieves active withdrawal
        TriggerEvent('hbs_ambulance:server:relieveWithdrawal', targetSrc, 'morphine')
        TriggerEvent('hbs_ambulance:server:relieveWithdrawal', targetSrc, 'painkiller')

    elseif medType == 'methadone' then
        -- Dedicated methadone cooldown (per-patient, longer than general cooldown)
        if not methadoneCooldowns[src] then methadoneCooldowns[src] = {} end
        local lastMeth = methadoneCooldowns[src][targetSrc] or 0
        if (os.time() - lastMeth) < Config.EMSResearch.methadoneCooldown then
            local remaining = Config.EMSResearch.methadoneCooldown - (os.time() - lastMeth)
            TriggerClientEvent('hbs_ambulance:client:notify', src, {
                msg = string.format('Methadone still on cooldown for this patient (%ds).', remaining),
                type = 'error'
            })
            return
        end
        methadoneCooldowns[src][targetSrc] = os.time()

        -- Reduce the patient's highest active addiction level by 1
        local addictions  = DB.LoadAddiction(cid)
        local reduced     = false
        local worstSub    = nil
        local worstLevel  = 0
        for sub, data in pairs(addictions) do
            if data.level > worstLevel then
                worstLevel = data.level
                worstSub   = sub
            end
        end
        if worstSub and worstLevel > 0 then
            local newLevel = math.max(0, worstLevel - 1)
            MySQL.query.await('UPDATE hbs_addiction SET level=? WHERE citizenid=? AND substance=?',
                { newLevel, cid, worstSub })
            -- Rebuild and sync addiction state
            local updatedAddictions = DB.LoadAddiction(cid)
            local addLevel = {}
            for sub, data in pairs(updatedAddictions) do addLevel[sub] = data.level end
            SB.Set(targetSrc, 'addiction', addLevel)
            TriggerClientEvent('hbs_ambulance:client:addictionUpdated', targetSrc, addLevel)
            -- Relieve withdrawal effects immediately
            TriggerEvent('hbs_ambulance:server:relieveWithdrawal', targetSrc, worstSub)
            reduced = true
        end

        if reduced then
            TriggerClientEvent('hbs_ambulance:client:notify', src, {
                msg = string.format('Methadone administered — %s addiction reduced.', worstSub or 'patient'),
                type = 'success'
            })
            -- Award addiction treatment XP
            TriggerEvent('hbs_ambulance:server:awardEMSXP', src,
                Config.EMSResearch.xpRewards.addictionTreat)
        else
            TriggerClientEvent('hbs_ambulance:client:notify', src, {
                msg = 'Patient has no active addiction to treat.', type = 'inform'
            })
        end
        return  -- early return; skip generic success notify below
    end

    TriggerClientEvent('hbs_ambulance:client:notify', src, {
        msg = 'Medication administered to patient.', type = 'success'
    })
end)

-- Tier 4: Full surgery (clear all injuries on target)
RegisterNetEvent('hbs_ambulance:server:fullSurgery', function(targetSrc)
    local src = source
    if not Utils.IsEMS(src) then return end
    if not HasUnlock(src, 'full_surgery') then return end

    local cid = Utils.GetCitizenId(targetSrc)
    if not cid then return end

    DB.ClearInjuries(cid)
    SB.Set(targetSrc, 'injuries', {})
    TriggerClientEvent('hbs_ambulance:client:applyInjuryEffects', targetSrc)

    -- Also restore some health
    local ped = GetPlayerPed(targetSrc)
    SetEntityHealth(ped, math.min(200, GetEntityHealth(ped) + 50))

    TriggerClientEvent('hbs_ambulance:client:notify', src, {
        msg = 'Surgery complete — all injuries cleared.', type = 'success'
    })
end)

-- Tier 5: Hands-only revive (no defib item needed)
RegisterNetEvent('hbs_ambulance:server:handsOnlyRevive', function(targetSrc)
    local src = source
    if not Utils.IsEMS(src) then return end
    if not HasUnlock(src, 'hands_only_revive') then return end

    -- Cooldown per target
    if not handsOnlyCooldowns[src] then handsOnlyCooldowns[src] = {} end
    local last = handsOnlyCooldowns[src][targetSrc] or 0
    if (os.time() - last) < Config.EMSResearch.handsOnlyCooldown then
        local remaining = Config.EMSResearch.handsOnlyCooldown - (os.time() - last)
        TriggerClientEvent('hbs_ambulance:client:notify', src, {
            msg = string.format('Hands-only revive on cooldown (%ds).', remaining), type = 'error'
        })
        return
    end
    handsOnlyCooldowns[src][targetSrc] = os.time()

    -- Perform the revive (reuse sv_ems logic via event)
    TriggerEvent('hbs_ambulance:server:performRevive', src, targetSrc, false)
    TriggerEvent('hbs_ambulance:server:awardEMSXP', src, Config.EMSResearch.xpRewards.revive)
end)

-- Tier 5: Mentor boost — give Tier-1 EMS temporary Tier-2 abilities
RegisterNetEvent('hbs_ambulance:server:mentorBoost', function(targetSrc)
    local src = source
    if not Utils.IsEMS(src) then return end
    if not HasUnlock(src, 'mentor_boost') then return end
    if not Utils.IsEMS(targetSrc) then
        TriggerClientEvent('hbs_ambulance:client:notify', src, {
            msg = 'Target must be an EMS player.', type = 'error'
        })
        return
    end

    local targetTier = GetEMSTier(targetSrc)
    if targetTier > 1 then
        TriggerClientEvent('hbs_ambulance:client:notify', src, {
            msg = 'Mentor boost only works on Tier-1 EMTs.', type = 'error'
        })
        return
    end

    SB.Set(targetSrc, 'mentorTier', 2)
    TriggerClientEvent('hbs_ambulance:client:mentorBoosted', targetSrc, src)
    TriggerClientEvent('hbs_ambulance:client:notify', src, {
        msg = 'Mentor boost applied. Your partner now has Tier-2 abilities for 30 min.', type = 'success'
    })

    -- Remove boost after duration
    SetTimeout(Config.EMSResearch.mentorDuration * 1000, function()
        SB.Set(targetSrc, 'mentorTier', nil)
        TriggerClientEvent('hbs_ambulance:client:mentorBoostEnded', targetSrc)
    end)
end)

-- Tier 5: Mass casualty alert
RegisterNetEvent('hbs_ambulance:server:massCasualtyAlert', function()
    local src = source
    if not Utils.IsEMS(src) then return end
    if not HasUnlock(src, 'mass_casualty') then return end
    local coords = GetEntityCoords(GetPlayerPed(src))
    local msg    = string.format('⚠ MASS CASUALTY EVENT at %.0f, %.0f — All units respond!',
        coords.x, coords.y)
    TriggerClientEvent('hbs_ambulance:client:emsDispatch', -1, msg)
end)

-- ── Internal: shared revive logic (used by sv_ems + hands-only) ──────────

AddEventHandler('hbs_ambulance:server:performRevive', function(reviverSrc, targetSrc, consumeItem)
    local targetCid = Utils.GetCitizenId(targetSrc)
    if not targetCid then return end

    DownedPlayers[targetSrc] = nil
    SB.Set(targetSrc, 'isDowned', false)
    DB.ClearInjuries(targetCid)
    SB.Set(targetSrc, 'injuries', {})

    if consumeItem and Config.ReviveRequiresItem then
        exports.ox_inventory:RemoveItem(reviverSrc, Config.ReviveItem, 1)
    end

    -- Adrenaline revive unlock
    if HasUnlock(reviverSrc, 'adrenaline_revive') then
        TriggerClientEvent('hbs_ambulance:client:adrenaline', targetSrc)
    end

    TriggerClientEvent('hbs_ambulance:client:revived', targetSrc)
    TriggerEvent('hbs_ambulance:server:broadcastDownedBlips')
end)

-- ── Admin Commands ────────────────────────────────────────────────────────

RegisterCommand('setemstier', function(src, args)
    if src ~= 0 and not IsPlayerAceAllowed(src, 'hbs_ambulance.admin') then
        if src ~= 0 then TriggerClientEvent('hbs_ambulance:client:notify', src,
            { msg = 'No permission.', type = 'error' }) end
        return
    end
    local targetId = tonumber(args[1])
    local newTier  = tonumber(args[2])
    if not targetId or not newTier or newTier < 1 or newTier > 5 then
        print('[hbs_ambulance] Usage: /setemstier [playerid] [1-5]')
        return
    end
    local cid = Utils.GetCitizenId(targetId)
    if not cid then print('[hbs_ambulance] Player not found'); return end

    local data     = DB.LoadEMSResearch(cid)
    local tierCfg  = GetTierCfg(newTier)
    local newXP    = math.max(data.xp, tierCfg.xpRequired)
    DB.SaveEMSResearch(cid, newTier, newXP, data.unlocks)
    SB.Set(targetId, 'emsTier', newTier)
    SB.Set(targetId, 'emsXP',   newXP)
    TriggerClientEvent('hbs_ambulance:client:emsTierUp', targetId, newTier, tierCfg.label)
    print(string.format('[hbs_ambulance] Set %s to tier %d (%s)', cid, newTier, tierCfg.label))
end, true)

RegisterCommand('setemsxp', function(src, args)
    if src ~= 0 and not IsPlayerAceAllowed(src, 'hbs_ambulance.admin') then
        if src ~= 0 then TriggerClientEvent('hbs_ambulance:client:notify', src,
            { msg = 'No permission.', type = 'error' }) end
        return
    end
    local targetId = tonumber(args[1])
    local amount   = tonumber(args[2])
    if not targetId or not amount then
        print('[hbs_ambulance] Usage: /setemsxp [playerid] [amount]')
        return
    end
    local cid = Utils.GetCitizenId(targetId)
    if not cid then print('[hbs_ambulance] Player not found'); return end

    local data    = DB.LoadEMSResearch(cid)
    local newTier = CalcTier(amount)
    DB.SaveEMSResearch(cid, newTier, amount, data.unlocks)
    SB.Set(targetId, 'emsTier', newTier)
    SB.Set(targetId, 'emsXP',   amount)
    TriggerClientEvent('hbs_ambulance:client:emsXPAwarded', targetId, 0, amount)
    print(string.format('[hbs_ambulance] Set %s XP to %d (tier %d)', cid, amount, newTier))
end, true)

RegisterCommand('resetems', function(src, args)
    if src ~= 0 and not IsPlayerAceAllowed(src, 'hbs_ambulance.admin') then
        if src ~= 0 then TriggerClientEvent('hbs_ambulance:client:notify', src,
            { msg = 'No permission.', type = 'error' }) end
        return
    end
    local targetId = tonumber(args[1])
    if not targetId then
        print('[hbs_ambulance] Usage: /resetems [playerid]')
        return
    end
    local cid = Utils.GetCitizenId(targetId)
    if not cid then print('[hbs_ambulance] Player not found'); return end

    DB.SaveEMSResearch(cid, 1, 0, {})
    SB.Set(targetId, 'emsTier',    1)
    SB.Set(targetId, 'emsXP',      0)
    SB.Set(targetId, 'emsUnlocks', {})
    TriggerClientEvent('hbs_ambulance:client:notify', targetId, {
        msg = 'Your EMS research progress has been reset.', type = 'warning'
    })
    print(string.format('[hbs_ambulance] Reset EMS research for %s', cid))
end, true)

RegisterCommand('viewems', function(src, args)
    if src ~= 0 and not IsPlayerAceAllowed(src, 'hbs_ambulance.admin') then
        if src ~= 0 then TriggerClientEvent('hbs_ambulance:client:notify', src,
            { msg = 'No permission.', type = 'error' }) end
        return
    end
    local targetId = tonumber(args[1])
    if not targetId then
        print('[hbs_ambulance] Usage: /viewems [playerid]')
        return
    end
    local cid = Utils.GetCitizenId(targetId)
    if not cid then print('[hbs_ambulance] Player not found'); return end

    local data    = DB.LoadEMSResearch(cid)
    local tierCfg = GetTierCfg(data.tier)
    print(string.format('[hbs_ambulance] EMS Stats for %s:', cid))
    print(string.format('  Tier: %d (%s) | XP: %d', data.tier, tierCfg.label, data.xp))
    print('  Unlocks: ' .. table.concat(data.unlocks, ', '))
end, true)
