-- HBS Medical item use handlers
-- lib.progressCircle is a BLOCKING coroutine call — must run in CreateThread

local cooldowns = {}

local function OnCooldown(name)
    local cfg = HBSConfig.MedicalItems[name]
    if not cfg or not cfg.cooldown then return false end
    return (GetGameTimer() - (cooldowns[name] or 0)) < (cfg.cooldown * 1000)
end

local function SetCooldown(name) cooldowns[name] = GetGameTimer() end

-- ── Find nearby players ───────────────────────────────────────────────────

local function FindDownedNearby(maxDist)
    local myPos = GetEntityCoords(cache.ped)
    for _, pid in ipairs(GetActivePlayers()) do
        if pid ~= PlayerId() then
            local srv = GetPlayerServerId(pid)
            local ped = GetPlayerPed(pid)
            if GetStateBagValue('player:' .. srv, HBS.Keys.isDowned) then
                if #(GetEntityCoords(ped) - myPos) <= (maxDist or 3.0) then
                    return srv
                end
            end
        end
    end
end

local function FindAnyNearby(maxDist)
    local myPos = GetEntityCoords(cache.ped)
    for _, pid in ipairs(GetActivePlayers()) do
        if pid ~= PlayerId() then
            if #(GetEntityCoords(GetPlayerPed(pid)) - myPos) <= (maxDist or 3.0) then
                return GetPlayerServerId(pid)
            end
        end
    end
end

-- ── Progress helper (blocking) ────────────────────────────────────────────

local function RunProgress(cfg, label)
    local dict = cfg.animation and cfg.animation.dict
    local clip = cfg.animation and cfg.animation.anim
    if dict then
        RequestAnimDict(dict)
        while not HasAnimDictLoaded(dict) do Wait(10) end
    end
    return lib.progressCircle({
        duration     = (cfg.useTime or 5) * 1000,
        label        = label or cfg.label or 'Using item...',
        useWhileDead = false,
        canCancel    = true,
        disable      = { move = false, car = false, combat = true },
        anim         = dict and { dict = dict, clip = clip, flag = cfg.animation.flag or 49 } or nil,
    })
end

-- ── Main item handler ─────────────────────────────────────────────────────

local function UseItem(name)
    local cfg = HBSConfig.MedicalItems[name]
    if not cfg then return end

    if OnCooldown(name) then
        exports.qbx_core:Notify('Item is on cooldown.', 'error')
        return
    end

    -- Defibrillator: needs downed player nearby
    if cfg.canRevive then
        local targetSrc = FindDownedNearby(3.0)
        if not targetSrc then
            exports.qbx_core:Notify('No downed player nearby.', 'error')
            return
        end
        if RunProgress(cfg, 'Defibrillating...') then
            SetCooldown(name)
            TriggerServerEvent('hbs_ambulance:server:itemRevive', name, targetSrc)
        end
        return
    end

    -- Healing items: check matching injury exists
    if cfg.heals and #cfg.heals > 0 then
        local match = false
        for _, sev in ipairs(cfg.heals) do
            for _, cur in pairs(HBSState.injuries) do
                if cur == sev then match = true; break end
            end
            if match then break end
        end
        if not match then
            exports.qbx_core:Notify('No matching injuries to treat.', 'error')
            return
        end
    end

    if RunProgress(cfg, 'Using ' .. (cfg.label or name) .. '...') then
        SetCooldown(name)
        TriggerServerEvent('hbs_ambulance:server:useItem', name)
    end
end

-- Wrapped in CreateThread so lib.progressCircle coroutine yield works
AddEventHandler('hbs_ambulance:client:useItem', function(data)
    local name = type(data) == 'string' and data or (data.name or data.item)
    CreateThread(function() UseItem(name) end)
end)
