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

-- ── Disease research (in-memory; resets on server restart) ───────────────────
-- Tracks how many samples have been analyzed per disease.

local DiseaseResearch = {}   -- { [disease] = count }

-- EMS collects a sample from an infected player via ox_target.
-- Gives one `sampleItem` (with disease metadata) to the EMS.
RegisterNetEvent('hbs_ambulance:server:collectDiseaseSample', function(targetSrc)
    local src = source
    if not HBSUtils.IsEMS(src) then return end

    local cid = HBSUtils.GetCitizenId(targetSrc)
    if not cid then return end

    local diseases = DB.LoadDiseases(cid)
    if not next(diseases) then
        TriggerClientEvent('hbs_ambulance:client:notify', src, 'error', 'Target has no active diseases.')
        return
    end

    -- Collect from the worst (highest-stage) disease the target has
    local chosenDisease, chosenStage = nil, 0
    for disease, stage in pairs(diseases) do
        if stage > chosenStage then
            chosenDisease = disease
            chosenStage   = stage
        end
    end

    local cfg        = HBSConfig.Diseases and HBSConfig.Diseases[chosenDisease]
    local sampleItem = cfg and cfg.sampleItem or 'disease_sample'

    exports.ox_inventory:AddItem(src, sampleItem, 1, { disease = chosenDisease, stage = chosenStage })

    TriggerClientEvent('hbs_ambulance:client:notify', src, 'success',
        ('Sample collected: %s Stage %d.'):format(cfg and cfg.label or chosenDisease, chosenStage))
    TriggerClientEvent('hbs_ambulance:client:notify', targetSrc, 'inform',
        'A medical sample has been taken from you.')

    HBSLog('disease', ('sample collected: src=%s disease=%s stage=%d'):format(tostring(src), chosenDisease, chosenStage))
end)

-- EMS analyzes a held sample at the research terminal.
-- Consumes the sample item, increments the server-wide research counter.
RegisterNetEvent('hbs_ambulance:server:analyzeSample', function(disease)
    local src = source
    if not HBSUtils.IsEMS(src) then return end

    local cfg = HBSConfig.Diseases and HBSConfig.Diseases[disease]
    if not cfg then return end

    local sampleItem = cfg.sampleItem or 'disease_sample'

    -- Check inventory for a sample of this specific disease
    local count = exports.ox_inventory:GetItemCount(src, sampleItem, { disease = disease })
    if count < 1 then
        TriggerClientEvent('hbs_ambulance:client:notify', src, 'error',
            ('No %s sample in your inventory.'):format(cfg.label or disease))
        return
    end

    exports.ox_inventory:RemoveItem(src, sampleItem, 1, { disease = disease })

    DiseaseResearch[disease] = (DiseaseResearch[disease] or 0) + 1
    local total   = DiseaseResearch[disease]
    local target  = cfg.researchTarget or 5

    HBSLog('disease', ('research: src=%s analyzed %s (%d/%d)'):format(tostring(src), disease, total, target))

    -- Broadcast updated research data to all online EMS
    local research  = {}
    for d, c in pairs(DiseaseResearch) do research[d] = c end
    local players = exports.qbx_core:GetQBPlayers()
    for _, player in pairs(players) do
        if player.PlayerData.job.type == 'ems' then
            TriggerClientEvent('hbs_ambulance:client:researchUpdate', player.PlayerData.source, research)
        end
    end

    TriggerClientEvent('hbs_ambulance:client:notify', src, 'success',
        ('Sample analyzed — %s research: %d / %d'):format(cfg.label or disease, total, target))

    if total == target then
        local msg = ('OUTBREAK RESEARCH: %s fully analyzed! EMS now have optimized treatment data.'):format(cfg.label or disease)
        for _, player in pairs(players) do
            if player.PlayerData.job.type == 'ems' then
                TriggerClientEvent('hbs_ambulance:client:notify', player.PlayerData.source, 'success', msg)
            end
        end
    end
end)

-- Callback: return current research progress + active outbreak counts for the terminal.
lib.callback.register('hbs_ambulance:server:getResearchData', function(source)
    if not HBSUtils.IsEMS(source) then return nil end

    local outbreaks = {}
    local players = exports.qbx_core:GetQBPlayers()
    for _, player in pairs(players) do
        local cid = player.PlayerData.citizenid
        if cid then
            local diseases = DB.LoadDiseases(cid)
            for disease in pairs(diseases) do
                outbreaks[disease] = (outbreaks[disease] or 0) + 1
            end
        end
    end

    local research = {}
    for d, c in pairs(DiseaseResearch) do research[d] = c end

    return { research = research, outbreaks = outbreaks }
end)

-- ── Civilian self-treat disease (antibiotic from inventory) ──────────────────
-- Reduces the disease by one stage per antibiotic used.
-- EMS full-clear (treatDisease) is a separate, faster path requiring patient_examine unlock.

RegisterNetEvent('hbs_ambulance:server:selfTreatDisease', function(itemName, disease)
    local src = source
    local cfg = HBSConfig.MedicalItems[itemName]
    if not cfg or not cfg.selfTreatDisease then return end

    local diseaseCfg = HBSConfig.Diseases and HBSConfig.Diseases[disease]
    if not diseaseCfg then return end

    if exports.ox_inventory:GetItemCount(src, itemName) < 1 then
        TriggerClientEvent('hbs_ambulance:client:notify', src, 'error',
            ('No %s in your inventory.'):format(itemName))
        return
    end

    local cid = HBSUtils.GetCitizenId(src)
    if not cid then return end

    local diseases = DB.LoadDiseases(cid)
    if not diseases[disease] then
        TriggerClientEvent('hbs_ambulance:client:notify', src, 'error', 'You do not have that disease.')
        return
    end

    -- Consume the antibiotic
    exports.ox_inventory:RemoveItem(src, itemName, 1)

    local currentStage = diseases[disease]
    if currentStage <= 1 then
        -- Stage 1 → fully cleared
        DB.ClearDisease(cid, disease)
        diseases[disease] = nil
        HBS.Set(src, 'diseases', diseases)
        TriggerClientEvent('hbs_ambulance:client:diseasesUpdate', src, diseases)
        TriggerClientEvent('hbs_ambulance:client:notify', src, 'success',
            (diseaseCfg.label or disease) .. ' has been cleared.')
    else
        -- Reduce one stage
        local newStage = currentStage - 1
        DB.SaveDisease(cid, disease, newStage)
        diseases[disease] = newStage
        HBS.Set(src, 'diseases', diseases)
        TriggerClientEvent('hbs_ambulance:client:diseasesUpdate', src, diseases)
        TriggerClientEvent('hbs_ambulance:client:notify', src, 'success',
            ('Antibiotic working — %s reduced to Stage %d. Keep taking them.'):format(
                diseaseCfg.label or disease, newStage))
    end

    HBSLog('selfTreatDisease', ('cid=%s treated %s with %s (was stage %d)'):format(
        cid, disease, itemName, currentStage))
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
