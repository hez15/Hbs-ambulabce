-- HBS EMS server: revive, treat, research XP

-- ── Unlock helper ─────────────────────────────────────────────────────────

local function HasUnlock(src, ability)
    if not src or src <= 0 then return false end
    local unlocks = HBS.Get(src, 'emsUnlocks') or {}
    if HBSUtils.TableContains(unlocks, ability) then return true end
    local emsTier = HBS.Get(src, 'emsTier') or 1
    local abCfg = HBSConfig.EMSResearch.abilities[ability]
    return abCfg ~= nil and emsTier >= abCfg.tier
end

local function AwardXP(src, amount)
    if not src or src <= 0 or amount <= 0 then return end
    local cid = HBSUtils.GetCitizenId(src)
    if not cid then
        HBSLog('AwardXP', 'failed - no citizenid for src=' .. tostring(src))
        return
    end
    local data   = DB.LoadEMSResearch(cid)
    local newXP  = data.xp + amount
    local newTier = data.tier

    for i = #HBSConfig.EMSResearch.tiers, 1, -1 do
        local t = HBSConfig.EMSResearch.tiers[i]
        if newXP >= t.xpRequired then newTier = t.tier; break end
    end

    HBSLog('AwardXP', ('cid=%s +%d xp  %d→%d xp  tier %d→%d'):format(cid, amount, data.xp, newXP, data.tier, newTier))

    DB.SaveEMSResearch(cid, newTier, newXP, data.unlocks)
    HBS.Set(src, 'emsTier', newTier)
    HBS.Set(src, 'emsXP',   newXP)
    TriggerClientEvent('hbs_ambulance:client:emsResearchUpdate', src,
        { tier = newTier, xp = newXP, unlocks = data.unlocks })

    local tierLabel = HBSConfig.EMSResearch.tiers[newTier] and HBSConfig.EMSResearch.tiers[newTier].label or 'EMT'
    TriggerClientEvent('hbs_ambulance:client:notify', src, 'success', ('+%d XP  |  %s'):format(amount, tierLabel))
    if newTier > data.tier then
        TriggerClientEvent('hbs_ambulance:client:notify', src, 'success', ('Tier up! You are now a %s'):format(tierLabel))
    end
end

-- ── Revive ────────────────────────────────────────────────────────────────

local function PerformRevive(reviverSrc, targetSrc)
    HBSLog('PerformRevive', ('reviver=%s target=%s'):format(tostring(reviverSrc), tostring(targetSrc)))

    -- Validate revive item before doing anything
    if reviverSrc and reviverSrc > 0 and HBSConfig.ReviveRequiresItem then
        local hasUnlock = HasUnlock(reviverSrc, 'hands_only_revive')
        if not hasUnlock then
            local count = exports.ox_inventory:GetItemCount(reviverSrc, HBSConfig.ReviveItem)
            HBSLog('PerformRevive', ('item check: %s x%d (needs 1)'):format(HBSConfig.ReviveItem, count))
            if count < 1 then
                TriggerClientEvent('hbs_ambulance:client:notify', reviverSrc, 'error',
                    ('Requires %s to revive.'):format(HBSConfig.ReviveItem))
                return
            end
            exports.ox_inventory:RemoveItem(reviverSrc, HBSConfig.ReviveItem, 1)
        end
    end

    local cid = HBSUtils.GetCitizenId(targetSrc)
    if not cid then
        HBSLog('PerformRevive', 'failed - no citizenid for target=' .. tostring(targetSrc))
        return
    end
    HBSLog('PerformRevive', 'clearing injuries and reviving cid=' .. cid)

    DownedPlayers[targetSrc] = nil
    HBS.Set(targetSrc, 'isDowned', false)
    HBS.Set(targetSrc, 'triage',   nil)
    DB.ClearInjuries(cid)
    HBS.Set(targetSrc, 'injuries', {})

    -- Push injury clear to target client immediately (net event, not local)
    TriggerClientEvent('hbs_ambulance:client:clearInjuries', targetSrc)

    -- Adrenaline unlock
    if HasUnlock(reviverSrc, 'adrenaline_revive') then
        TriggerClientEvent('hbs_ambulance:client:addStress', targetSrc, -50)
        SetEntityHealth(GetPlayerPed(targetSrc), 200)
    end

    -- Tell qbx_medical the player is revived (clears laststand/dead state + animation)
    TriggerClientEvent('qbx_medical:client:playerRevived', targetSrc)
    -- Our HBS cleanup (hide death screen, clear injuries HUD)
    TriggerClientEvent('hbs_ambulance:client:revived', targetSrc)
    TriggerEvent('hbs:server:broadcastDownedBlips')
end

-- ── Transport XP ──────────────────────────────────────────────────────────

RegisterNetEvent('hbs_ambulance:server:transportPatient', function(targetSrc)
    local src = source
    if not HBSUtils.IsEMS(src) then return end
    -- Only award if target is still downed
    if not DownedPlayers[targetSrc] then return end
    HBSLog('transportPatient', ('EMS %s transporting patient %s'):format(tostring(src), tostring(targetSrc)))
    AwardXP(src, HBSConfig.EMSResearch.xpRewards.transport or 50)
    TriggerClientEvent('hbs_ambulance:client:notify', src, 'success', 'Transport XP awarded.')
end)

-- ── Mass Casualty Alert (Tier 5) ──────────────────────────────────────────

local mcaCooldowns = {}

RegisterNetEvent('hbs_ambulance:server:massCasualtyAlert', function()
    local src = source
    if not HBSUtils.IsEMS(src) then return end
    if not HasUnlock(src, 'mass_casualty') then
        TriggerClientEvent('hbs_ambulance:client:notify', src, 'error', 'Requires Mass Casualty Alert unlock.')
        return
    end

    local now = os.time()
    if (now - (mcaCooldowns[src] or 0)) < 300 then   -- 5 min cooldown
        TriggerClientEvent('hbs_ambulance:client:notify', src, 'error', 'Mass Casualty Alert on cooldown.')
        return
    end
    mcaCooldowns[src] = now

    local callerName = GetPlayerName(src)
    local coords     = GetEntityCoords(GetPlayerPed(src))
    local msg        = ('%s declared a MASS CASUALTY EVENT at %.0f, %.0f'):format(callerName, coords.x, coords.y)

    HBSLog('massCasualtyAlert', msg)

    local players = exports.qbx_core:GetQBPlayers()
    for _, v in pairs(players) do
        if v.PlayerData.job.type == 'ems' then
            TriggerClientEvent('hbs_ambulance:client:massCasualtyAlert', v.PlayerData.source, {
                callerName = callerName,
                coords     = { x = coords.x, y = coords.y, z = coords.z },
                message    = msg,
            })
        end
    end
end)

-- ── Minigame failure penalty ──────────────────────────────────────────────

RegisterNetEvent('hbs_ambulance:server:minigameFailed', function(targetSrc, actionType)
    local src = source
    if not HBSUtils.IsEMS(src) then return end
    local ped = GetPlayerPed(targetSrc)
    if not ped or ped == 0 then return end
    local penalty = actionType == 'revive' and 15 or 8
    local hp = GetEntityHealth(ped)
    SetEntityHealth(ped, math.max(101, hp - penalty))
    HBSLog('minigameFailed', ('action=%s target=%s penalty=%d'):format(actionType, tostring(targetSrc), penalty))
end)

RegisterNetEvent('hbs_ambulance:server:emsRevive', function(targetSrc)
    local src = source
    if not HBSUtils.IsEMS(src) then return end
    PerformRevive(src, targetSrc)
    AwardXP(src, HBSConfig.EMSResearch.xpRewards.revive)
end)

-- Also hook qbx's standard revive event to award our XP
RegisterNetEvent('hospital:server:RevivePlayer', function(playerId)
    local src = source
    -- Let qbx handle the actual revive; we just award XP + clear our state
    local cid = HBSUtils.GetCitizenId(playerId)
    if cid then
        DownedPlayers[playerId] = nil
        HBS.Set(playerId, 'isDowned', false)
        DB.ClearInjuries(cid)
        HBS.Set(playerId, 'injuries', {})
    end
    AwardXP(src, HBSConfig.EMSResearch.xpRewards.revive)
    TriggerEvent('hbs:server:broadcastDownedBlips')
end)

-- ── Treat wounds ──────────────────────────────────────────────────────────

RegisterNetEvent('hbs_ambulance:server:emsTreat', function(targetSrc)
    local src = source
    if not HBSUtils.IsEMS(src) then return end

    local cid = HBSUtils.GetCitizenId(targetSrc)
    if not cid then return end

    local injuries     = DB.LoadInjuries(cid)
    local traumaSplint = HasUnlock(src, 'trauma_splint')

    for part, sev in pairs(injuries) do
        local heal = sev == 'scratch' or sev == 'minor'
        if traumaSplint and sev == 'fracture' then heal = true end
        if sev == 'critical' then heal = false end  -- critical needs full surgery
        if heal then DB.SaveInjury(cid, part, nil) end
    end

    if HasUnlock(src, 'iv_therapy') then
        local ped = GetPlayerPed(targetSrc)
        SetEntityHealth(ped, math.min(200, GetEntityHealth(ped) + 75))
    end

    local updated = DB.LoadInjuries(cid)
    HBS.Set(targetSrc, 'injuries', updated)
    TriggerClientEvent('hbs_ambulance:client:applyInjuryEffects', targetSrc)
    AwardXP(src, HBSConfig.EMSResearch.xpRewards.treat)
end)

-- ── Examine patient (Tier 2 unlock) ──────────────────────────────────────────

RegisterNetEvent('hbs_ambulance:server:examinePlayer', function(targetSrc)
    local src = source
    if not HBSUtils.IsEMS(src) then return end
    if not HasUnlock(src, 'patient_examine') then
        TriggerClientEvent('hbs_ambulance:client:notify', src, 'error', 'Requires Patient Examination unlock.')
        return
    end

    local cid = HBSUtils.GetCitizenId(targetSrc)
    if not cid then return end

    local injuries  = DB.LoadInjuries(cid)
    local stress    = DB.LoadStress(cid)
    local addiction = DB.LoadAddiction(cid)

    TriggerClientEvent('hbs_ambulance:client:examineResult', src, {
        playerName = GetPlayerName(targetSrc),
        injuries   = injuries,
        stress     = stress,
        addiction  = addiction,
    })
end)

-- ── Addiction therapy (Tier 3 unlock) ────────────────────────────────────────

RegisterNetEvent('hbs_ambulance:server:administerDetox', function(targetSrc)
    local src = source
    if not HBSUtils.IsEMS(src) then return end
    if targetSrc == src then
        TriggerClientEvent('hbs_ambulance:client:notify', src, 'error', 'Cannot administer detox to yourself.')
        return
    end
    if not HasUnlock(src, 'addiction_therapy') then
        TriggerClientEvent('hbs_ambulance:client:notify', src, 'error', 'Requires Addiction Therapy unlock.')
        return
    end

    -- Consume one methadone from EMS inventory
    local hasMethadone = exports.ox_inventory:GetItemCount(src, 'methadone') >= 1
    if not hasMethadone then
        TriggerClientEvent('hbs_ambulance:client:notify', src, 'error', 'Requires methadone in inventory.')
        return
    end
    exports.ox_inventory:RemoveItem(src, 'methadone', 1)

    local cid = HBSUtils.GetCitizenId(targetSrc)
    if not cid then return end

    -- Reduce each substance addiction by 1 (min 0) — values are plain numbers
    local addiction = DB.LoadAddiction(cid)
    for substance, level in pairs(addiction) do
        local newLevel = math.max(0, (type(level) == 'number' and level or 0) - 1)
        DB.SaveAddiction(cid, substance, newLevel)
        addiction[substance] = newLevel
    end

    HBS.Set(targetSrc, 'addiction', addiction)
    TriggerClientEvent('hbs_ambulance:client:addictionUpdate', targetSrc, addiction)
    TriggerClientEvent('hbs_ambulance:client:notify', targetSrc, 'success', 'Detox administered — addiction reduced.')
    AwardXP(src, HBSConfig.EMSResearch.xpRewards.treat)
end)

-- ── Full detox (Tier 4 unlock) ────────────────────────────────────────────────

RegisterNetEvent('hbs_ambulance:server:fullDetox', function(targetSrc)
    local src = source
    if not HBSUtils.IsEMS(src) then return end
    if not HasUnlock(src, 'full_detox') then
        TriggerClientEvent('hbs_ambulance:client:notify', src, 'error', 'Requires Full Detox unlock.')
        return
    end

    -- Costs 2 methadone
    local hasMethadone = exports.ox_inventory:GetItemCount(src, 'methadone') >= 2
    if not hasMethadone then
        TriggerClientEvent('hbs_ambulance:client:notify', src, 'error', 'Requires 2x methadone.')
        return
    end
    exports.ox_inventory:RemoveItem(src, 'methadone', 2)

    local cid = HBSUtils.GetCitizenId(targetSrc)
    if not cid then return end

    DB.LoadAddiction(cid) -- load to get substances
    local cleared = {}
    local addiction = DB.LoadAddiction(cid)
    for substance in pairs(addiction) do
        DB.SaveAddiction(cid, substance, 0)
        cleared[substance] = 0
    end

    HBS.Set(targetSrc, 'addiction', cleared)
    TriggerClientEvent('hbs_ambulance:client:addictionUpdate', targetSrc, cleared)
    TriggerClientEvent('hbs_ambulance:client:notify', targetSrc, 'success', 'Full detox complete — all addiction cleared.')
    AwardXP(src, HBSConfig.EMSResearch.xpRewards.treat * 2)
end)

-- ── Full surgery (Tier 4 unlock) ──────────────────────────────────────────

RegisterNetEvent('hbs_ambulance:server:fullSurgery', function(targetSrc)
    local src = source
    if not HBSUtils.IsEMS(src) then return end
    if not HasUnlock(src, 'full_surgery') then return end

    local cid = HBSUtils.GetCitizenId(targetSrc)
    if not cid then return end

    DB.ClearInjuries(cid)
    HBS.Set(targetSrc, 'injuries', {})
    TriggerClientEvent('hbs_ambulance:client:applyInjuryEffects', targetSrc)
    SetEntityHealth(GetPlayerPed(targetSrc), 200)
    AwardXP(src, HBSConfig.EMSResearch.xpRewards.treat * 3)
end)
