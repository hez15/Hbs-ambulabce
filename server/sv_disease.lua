-- HBS Diseases — server: progression, spread, EMS treatment

-- ── Disease progression tick ───────────────────────────────────────────────
-- Advances each active disease by one stage every progressTime seconds.

CreateThread(function()
    -- Track when each player's disease last progressed { [src] = { [disease] = lastProgressTime } }
    local progressTimers = {}

    while true do
        Wait(30000)  -- check every 30s, progression gates on progressTime

        local players = exports.qbx_core:GetQBPlayers()
        local now     = os.time()

        for _, player in pairs(players) do
            local src = player.PlayerData.source
            local cid = player.PlayerData.citizenid
            if not cid then goto nextPlayer end

            local diseases = DB.LoadDiseases(cid)
            if not next(diseases) then
                progressTimers[src] = nil
                goto nextPlayer
            end

            progressTimers[src] = progressTimers[src] or {}

            for disease, stage in pairs(diseases) do
                local cfg = HBSConfig.Diseases and HBSConfig.Diseases[disease]
                if not cfg then goto nextDisease end

                local maxStage    = cfg.stages or 3
                local progressTime = cfg.progressTime or 600
                local lastProg    = progressTimers[src][disease] or (now - progressTime)

                if (now - lastProg) >= progressTime then
                    progressTimers[src][disease] = now
                    if stage < maxStage then
                        local newStage = stage + 1
                        DB.SaveDisease(cid, disease, newStage)
                        diseases[disease] = newStage
                        HBS.Set(src, 'diseases', diseases)
                        TriggerClientEvent('hbs_ambulance:client:diseasesUpdate', src, diseases)
                        TriggerClientEvent('hbs_ambulance:client:notify', src, 'error',
                            ('Your %s has worsened (Stage %d).'):format(cfg.label or disease, newStage))
                        HBSLog('disease', ('progression: cid=%s %s stage %d→%d'):format(cid, disease, stage, newStage))
                    end
                end

                ::nextDisease::
            end

            ::nextPlayer::
        end
    end
end)

-- ── Proximity spread tick ──────────────────────────────────────────────────

CreateThread(function()
    while true do
        Wait(60000)  -- every 60 seconds

        local players = exports.qbx_core:GetQBPlayers()
        local playerList = {}

        for _, player in pairs(players) do
            local src = player.PlayerData.source
            local cid = player.PlayerData.citizenid
            if cid and GetPlayerPed(src) ~= 0 then
                local coords = GetEntityCoords(GetPlayerPed(src))
                playerList[#playerList + 1] = { src=src, cid=cid, coords=coords }
            end
        end

        -- For each infected player, check nearby players for spread
        for _, infected in ipairs(playerList) do
            local infectedDiseases = DB.LoadDiseases(infected.cid)
            for disease, stage in pairs(infectedDiseases) do
                local cfg = HBSConfig.Diseases and HBSConfig.Diseases[disease]
                if not cfg or not cfg.spreadRadius or cfg.spreadRadius <= 0 then goto nextSpread end

                local spreadChance = cfg.spreadChance or 0.02

                for _, nearby in ipairs(playerList) do
                    if nearby.src == infected.src then goto nextNearby end
                    local dist = #(infected.coords - nearby.coords)
                    if dist <= cfg.spreadRadius then
                        -- Check if nearby player already has this disease
                        local nearbyDiseases = DB.LoadDiseases(nearby.cid)
                        if not nearbyDiseases[disease] then
                            if math.random() < spreadChance then
                                DB.SaveDisease(nearby.cid, disease, 1)
                                nearbyDiseases[disease] = 1
                                HBS.Set(nearby.src, 'diseases', nearbyDiseases)
                                TriggerClientEvent('hbs_ambulance:client:diseasesUpdate', nearby.src, nearbyDiseases)
                                TriggerClientEvent('hbs_ambulance:client:notify', nearby.src, 'error',
                                    ('You have contracted %s.'):format(cfg.label or disease))
                                HBSLog('disease', ('spread: %s contracted %s from src=%s'):format(nearby.cid, disease, tostring(infected.src)))
                            end
                        end
                    end
                    ::nextNearby::
                end

                ::nextSpread::
            end
        end
    end
end)

-- ── EMS treat disease ──────────────────────────────────────────────────────

RegisterNetEvent('hbs_ambulance:server:treatDisease', function(targetSrc, disease)
    local src = source
    if not HBSUtils.IsEMS(src) then return end
    if not HasUnlock(src, 'patient_examine') then
        TriggerClientEvent('hbs_ambulance:client:notify', src, 'error', 'Requires Patient Examination unlock.')
        return
    end

    local cfg = HBSConfig.Diseases and HBSConfig.Diseases[disease]
    if not cfg then
        TriggerClientEvent('hbs_ambulance:client:notify', src, 'error', 'Unknown disease.')
        return
    end

    -- Consume treat item if configured
    if cfg.treatItem then
        if exports.ox_inventory:GetItemCount(src, cfg.treatItem) < 1 then
            TriggerClientEvent('hbs_ambulance:client:notify', src, 'error',
                ('Requires %s to treat this condition.'):format(cfg.treatItem))
            return
        end
        exports.ox_inventory:RemoveItem(src, cfg.treatItem, 1)
    end

    local cid = HBSUtils.GetCitizenId(targetSrc)
    if not cid then return end

    DB.ClearDisease(cid, disease)
    local updated = DB.LoadDiseases(cid)
    HBS.Set(targetSrc, 'diseases', updated)
    TriggerClientEvent('hbs_ambulance:client:diseasesUpdate', targetSrc, updated)
    TriggerClientEvent('hbs_ambulance:client:notify', targetSrc, 'success',
        ('Your %s has been treated.'):format(cfg.label or disease))
    TriggerClientEvent('hbs_ambulance:client:notify', src, 'success', 'Disease treated successfully.')

    HBSLog('disease', ('treated: cid=%s disease=%s by src=%s'):format(cid, disease, tostring(src)))
end)

-- ── Contract disease (for items, environmental triggers, etc.) ──────────────

RegisterNetEvent('hbs_ambulance:server:contractDisease', function(disease, stage)
    local src = source
    local cfg = HBSConfig.Diseases and HBSConfig.Diseases[disease]
    if not cfg then return end

    local cid = HBSUtils.GetCitizenId(src)
    if not cid then return end

    stage = math.max(1, math.min(cfg.stages or 3, stage or 1))

    local current = DB.LoadDiseases(cid)
    -- Only set if not already infected or new stage is worse
    if not current[disease] or current[disease] < stage then
        DB.SaveDisease(cid, disease, stage)
        current[disease] = stage
        HBS.Set(src, 'diseases', current)
        TriggerClientEvent('hbs_ambulance:client:diseasesUpdate', src, current)
        TriggerClientEvent('hbs_ambulance:client:notify', src, 'error',
            ('You have contracted %s (Stage %d).'):format(cfg.label or disease, stage))
        HBSLog('disease', ('contracted: cid=%s disease=%s stage=%d'):format(cid, disease, stage))
    end
end)

-- ── Export for external scripts ────────────────────────────────────────────

exports('contractDisease', function(src, disease, stage)
    local cfg = HBSConfig.Diseases and HBSConfig.Diseases[disease]
    if not cfg then return end
    local cid = HBSUtils.GetCitizenId(src)
    if not cid then return end
    stage = math.max(1, math.min(cfg.stages or 3, stage or 1))
    local current = DB.LoadDiseases(cid)
    if not current[disease] or current[disease] < stage then
        DB.SaveDisease(cid, disease, stage)
        current[disease] = stage
        HBS.Set(src, 'diseases', current)
        TriggerClientEvent('hbs_ambulance:client:diseasesUpdate', src, current)
    end
end)
