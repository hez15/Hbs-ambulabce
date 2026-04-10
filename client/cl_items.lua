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

-- ── Injury selection menu for healing items ───────────────────────────────
-- RunMinigame is defined globally in cl_ems.lua (loaded before cl_items.lua).

local SEV_LABELS = { scratch='Scratch', minor='Minor Wound', fracture='Fracture', critical='Critical Wound' }

local function OpenInjuryMenu(itemName, cfg)
    local treatMap = HBSConfig.TreatMap
    if not treatMap then return end

    -- Build list of injuries this item can treat based on TreatMap
    local options = {}
    local healSet = {}
    for _, sev in ipairs(cfg.heals or {}) do healSet[sev] = true end

    for part, currentSev in pairs(HBSState.injuries) do
        if not healSet[currentSev] then goto nextPart end

        -- Check healParts constraint
        local partOk = false
        for _, hp in ipairs(cfg.healParts or { 'any' }) do
            if hp == 'any' or hp == part then partOk = true; break end
        end
        if not partOk then goto nextPart end

        local treatCfg = treatMap[currentSev]
        if not treatCfg or treatCfg.item ~= itemName then goto nextPart end

        local partLabel = part:gsub('_', ' '):gsub('^%l', string.upper)
        local nextSev   = treatCfg.downgradeTo
        local result    = nextSev and ('→ ' .. (SEV_LABELS[nextSev] or nextSev)) or '→ Healed'
        local _part, _sev, _cfg = part, currentSev, treatCfg

        options[#options + 1] = {
            title       = ('%s — %s %s'):format(partLabel, SEV_LABELS[currentSev] or currentSev, result),
            description = ('Uses 1x %s'):format(itemName),
            onSelect    = function()
                CreateThread(function()
                    local success = RunMinigame(_cfg.theme, _cfg.difficulty)
                    -- Always fire server event — server consumes item and handles outcome
                    TriggerServerEvent('hbs_ambulance:server:useItemOnInjury', itemName, _part, _sev, success)
                    if success then
                        local msg = nextSev
                            and ('Treated %s — now %s.'):format(SEV_LABELS[_sev] or _sev, SEV_LABELS[nextSev] or nextSev)
                            or  ('Treated %s — fully healed!'):format(SEV_LABELS[_sev] or _sev)
                        exports.qbx_core:Notify(msg, 'success')
                    else
                        exports.qbx_core:Notify(('Treatment failed — %s wasted.'):format(itemName), 'error')
                    end
                end)
            end,
        }
        ::nextPart::
    end

    if #options == 0 then
        exports.qbx_core:Notify('No matching injuries to treat.', 'error')
        return
    end

    lib.registerContext({ id = 'hbs_self_treat_menu', title = 'Treat Injury', options = options })
    lib.showContext('hbs_self_treat_menu')
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

    -- Civilian revive (first aid kit on downed player)
    if cfg.canCivilianRevive then
        local targetSrc = FindDownedNearby(3.0)
        if targetSrc then
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
                anim         = dict and { dict = dict, clip = clip, flag = cfg.animation.flag or 49 } or nil,
            }) then
                SetCooldown(name)
                TriggerServerEvent('hbs_ambulance:server:civilianRevive', name, targetSrc)
            end
            return
        end
        -- No downed player nearby — fall through to self-heal
    end

    -- Healing items → open per-injury selection menu with minigame
    if cfg.heals and #cfg.heals > 0 then
        OpenInjuryMenu(name, cfg)
        return
    end

    -- Non-healing items (bloodbag, painkiller, methadone) — plain progress bar
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
