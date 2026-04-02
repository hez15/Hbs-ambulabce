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
