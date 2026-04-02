-- Addiction system: level tracking, withdrawal timers, relief, reduction

-- ── Withdrawal timer management ───────────────────────────────────────────

local function CancelWithdrawal(src, substance)
    if WithdrawalTimers[src] and WithdrawalTimers[src][substance] then
        -- Timers in FiveM are one-shot; we use a flag to skip the callback
        WithdrawalTimers[src][substance] = nil
    end
end

local function ScheduleWithdrawal(src, cid, substance, level)
    if level <= 0 then return end
    if not WithdrawalTimers[src] then WithdrawalTimers[src] = {} end

    local delayMs = Config.Addiction.withdrawalDelay * 60 * 1000

    WithdrawalTimers[src][substance] = true   -- mark as scheduled

    SetTimeout(delayMs, function()
        -- Check: player still connected, timer not cancelled, still addicted
        if not WithdrawalTimers[src] then return end
        if not WithdrawalTimers[src][substance] then return end
        local curCid = Utils.GetCitizenId(src)
        if not curCid or curCid ~= cid then return end

        -- Trigger withdrawal on client
        TriggerClientEvent('hbs_ambulance:client:withdrawalStarted', src, substance)
        Utils.Debug('Withdrawal started for', cid, substance)
    end)
end

-- ── Schedule withdrawal for all substances on player load ─────────────────

AddEventHandler('hbs_ambulance:server:scheduleWithdrawal', function(src, cid, addictions)
    for sub, data in pairs(addictions) do
        if data.level > 0 then
            -- Calculate remaining time based on last_use
            local lastUseStr = data.lastUse
            if lastUseStr then
                -- Parse timestamp (simplified: schedule from now if last_use is recent)
                -- For production: calculate elapsed time from last_use and subtract from delay
                ScheduleWithdrawal(src, cid, sub, data.level)
            end
        end
    end
end)

-- ── Process addiction on item use ─────────────────────────────────────────

AddEventHandler('hbs_ambulance:server:processAddiction', function(src, cid, itemCfg)
    local substance = itemCfg.substance
    if not substance then return end

    -- Load current addiction
    local addictions = DB.LoadAddiction(cid)
    local entry      = addictions[substance] or { level = 0 }
    local curLevel   = entry.level
    local chances    = itemCfg.addictChance or {}
    local chance     = chances[curLevel] or 0.0

    -- Roll for addiction increase
    local shouldIncrease = math.random() < chance

    if shouldIncrease and curLevel < 4 then
        local newLevel = curLevel + 1
        DB.SaveAddiction(cid, substance, newLevel, os.date('!%Y-%m-%d %H:%M:%S'))
        SB.Set(src, 'addiction', GetAddictionLevels(cid))
        TriggerClientEvent('hbs_ambulance:client:addictionUpdated', src, substance, newLevel)
        Utils.Debug('Addiction increased for', cid, substance, '->', newLevel)
    else
        -- Just update last_use time
        DB.SaveAddiction(cid, substance, curLevel, os.date('!%Y-%m-%d %H:%M:%S'))
    end

    -- Cancel existing withdrawal timer (just used), then reschedule
    CancelWithdrawal(src, substance)
    TriggerClientEvent('hbs_ambulance:client:withdrawalEnded', src, substance)
    ScheduleWithdrawal(src, cid, substance,
        shouldIncrease and (curLevel + 1) or curLevel)
end)

-- ── Withdrawal relief (painkiller / methadone) ────────────────────────────

AddEventHandler('hbs_ambulance:server:relieveWithdrawal', function(src, cid, itemCfg)
    -- Suppress withdrawal effects temporarily
    TriggerClientEvent('hbs_ambulance:client:withdrawalEnded', src, 'all')
    -- Reschedule withdrawal after the item's pain duration
    local delay = (itemCfg.painDuration or 60)
    SetTimeout(delay * 1000, function()
        local curCid = Utils.GetCitizenId(src)
        if curCid ~= cid then return end
        local addictions = DB.LoadAddiction(cid)
        for sub, data in pairs(addictions) do
            if data.level > 0 then
                TriggerClientEvent('hbs_ambulance:client:withdrawalStarted', src, sub)
            end
        end
    end)
end)

-- ── Reduce addiction (methadone) ──────────────────────────────────────────

AddEventHandler('hbs_ambulance:server:reduceAddiction', function(src, cid, amount)
    local addictions = DB.LoadAddiction(cid)
    local newLevels  = {}
    for sub, data in pairs(addictions) do
        local newLevel = math.max(0, data.level - amount)
        DB.UpdateAddictionLevel(cid, sub, newLevel)
        newLevels[sub] = newLevel
        TriggerClientEvent('hbs_ambulance:client:addictionUpdated', src, sub, newLevel)
        -- If fully clean, stop withdrawal
        if newLevel == 0 then
            CancelWithdrawal(src, sub)
            TriggerClientEvent('hbs_ambulance:client:withdrawalEnded', src, sub)
        end
    end
    SB.Set(src, 'addiction', newLevels)
end)

-- ── Helper: build simple level table from DB ──────────────────────────────

function GetAddictionLevels(cid)
    local addictions = DB.LoadAddiction(cid)
    local t = {}
    for sub, data in pairs(addictions) do
        t[sub] = data.level
    end
    return t
end
