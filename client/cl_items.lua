-- Medical item use handlers (registered with ox_inventory)

local cooldowns = {}   -- { [itemName] = gameTimer (ms) }

-- ── Cooldown check ────────────────────────────────────────────────────────

local function OnCooldown(name)
    local cfg = Config.MedicalItems[name]
    if not cfg or not cfg.cooldown then return false end
    local last = cooldowns[name] or 0
    return (GetGameTimer() - last) < (cfg.cooldown * 1000)
end

local function SetCooldown(name)
    cooldowns[name] = GetGameTimer()
end

-- ── Find nearest downed player for defib ─────────────────────────────────

local function FindDownedNearby(maxDist)
    maxDist = maxDist or 3.0
    local myCoords = GetEntityCoords(PlayerPedId())
    for _, pid in ipairs(GetActivePlayers()) do
        if pid ~= PlayerId() then
            local srv  = GetPlayerServerId(pid)
            local ped  = GetPlayerPed(pid)
            if GetStateBagValue('player:' .. srv, SB.Keys.isDowned) then
                if #(GetEntityCoords(ped) - myCoords) <= maxDist then
                    return srv, ped
                end
            end
        end
    end
    return nil, nil
end

-- ── Find any nearby player (for blood test) ───────────────────────────────

local function FindAnyPlayerNearby(maxDist)
    maxDist = maxDist or 3.0
    local myCoords = GetEntityCoords(PlayerPedId())
    for _, pid in ipairs(GetActivePlayers()) do
        if pid ~= PlayerId() then
            local ped = GetPlayerPed(pid)
            if #(GetEntityCoords(ped) - myCoords) <= maxDist then
                return GetPlayerServerId(pid), ped
            end
        end
    end
    return nil, nil
end

-- ── Progress bar with animation helper ───────────────────────────────────

local function RunItemProgress(cfg, label, cb)
    local animDict = cfg.animation and cfg.animation.dict
    local animClip = cfg.animation and cfg.animation.anim

    if animDict then
        RequestAnimDict(animDict)
        while not HasAnimDictLoaded(animDict) do Wait(10) end
    end

    lib.progressBar({
        duration     = cfg.useTime * 1000,
        label        = label,
        useWhileDead = false,
        canCancel    = true,
        anim         = animDict and { dict = animDict, clip = animClip, flag = 49 } or nil,
    }, cb)
end

-- ── Main item use handler ─────────────────────────────────────────────────

local function UseItem(name)
    local cfg = Config.MedicalItems[name]
    if not cfg then return end

    if OnCooldown(name) then
        Notify(Locale('item_cooldown'), 'error')
        return
    end

    -- Blood test kit: requires EMS job, finds nearest player
    if name == 'blood_test_kit' then
        local pd = exports.qbx_core:GetPlayerData()
        if not (pd and pd.job and pd.job.name == Config.EmsJob) then
            Notify('Only EMS can use a blood test kit.', 'error')
            return
        end
        local targetSrc, _ = FindAnyPlayerNearby(3.0)
        if not targetSrc then
            Notify('No patient within range.', 'error')
            return
        end
        RunItemProgress(cfg, 'Performing blood test...', function(done)
            if done then
                TriggerServerEvent('hbs_ambulance:server:bloodTest', targetSrc)
            end
        end)
        return
    end

    -- Defibrillator: must have downed player nearby
    if cfg.canRevive then
        local targetSrc, targetPed = FindDownedNearby(3.0)
        if not targetSrc then
            Notify(Locale('item_not_downed'), 'error')
            return
        end
        RunItemProgress(cfg, Locale('item_defibrillator_use'), function(done)
            if done then
                SetCooldown(name)
                TriggerServerEvent('hbs_ambulance:server:useItem', name, { targetSrc = targetSrc })
            end
        end)
        return
    end

    -- Wound-healing items: check player has matching injury
    if cfg.heals and #cfg.heals > 0 then
        local hasMatch = false
        for _, severity in ipairs(cfg.heals) do
            for _, cur in pairs(LocalState.injuries) do
                if cur == severity then hasMatch = true; break end
            end
            if hasMatch then break end
        end
        if not hasMatch then
            Notify(Locale('item_no_injuries'), 'error')
            return
        end
    end

    -- Determine label
    local labelKey = 'item_' .. name .. '_use'
    local label    = Locale(labelKey)

    RunItemProgress(cfg, label, function(done)
        if done then
            SetCooldown(name)
            TriggerServerEvent('hbs_ambulance:server:useItem', name, {})
        end
    end)
end

-- ── Register items with ox_inventory ─────────────────────────────────────

for itemName, _ in pairs(Config.MedicalItems) do
    local name = itemName   -- capture for closure
    exports.ox_inventory:RegisterStacks(name, function()
        UseItem(name)
    end)
end

-- ── Blood test result display ─────────────────────────────────────────────

RegisterNetEvent('hbs_ambulance:client:bloodTestResult', function(targetName, addictions)
    local options = {}
    local hasAny  = false

    for sub, data in pairs(addictions or {}) do
        if data.level > 0 then
            hasAny = true
            local levelLabel = (Config.Addiction.levelLabels or {})[data.level] or ('Level ' .. data.level)
            table.insert(options, {
                title       = sub:sub(1,1):upper() .. sub:sub(2),
                description = levelLabel .. string.format(' (Level %d/4)', data.level),
                disabled    = true,
            })
        end
    end

    if not hasAny then
        table.insert(options, {
            title    = 'No substances detected',
            disabled = true,
        })
    end

    lib.registerContext({
        id      = 'hbs_blood_test_result',
        title   = 'Blood Test — ' .. (targetName or 'Patient'),
        options = options,
    })
    lib.showContext('hbs_blood_test_result')
end)
