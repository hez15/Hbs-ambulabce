-- HBS Medical item use — server side

-- ── Defib revive ──────────────────────────────────────────────────────────

RegisterNetEvent('hbs_ambulance:server:itemRevive', function(itemName, targetSrc)
    local src = source
    local cfg = HBSConfig.MedicalItems[itemName]
    if not cfg or not cfg.canRevive then return end

    -- Remove the item
    exports.ox_inventory:RemoveItem(src, itemName, 1)

    local cid = HBSUtils.GetCitizenId(targetSrc)
    if not cid then return end

    DownedPlayers[targetSrc] = nil
    HBS.Set(targetSrc, 'isDowned', false)
    HBS.Set(targetSrc, 'triage', nil)
    DB.ClearInjuries(cid)
    HBS.Set(targetSrc, 'injuries', {})

    TriggerClientEvent('qbx_medical:client:playerRevived', targetSrc)
    TriggerClientEvent('hbs_ambulance:client:revived', targetSrc)
    TriggerEvent('hbs:server:broadcastDownedBlips')
end)

-- ── Self-use items ────────────────────────────────────────────────────────

RegisterNetEvent('hbs_ambulance:server:useItem', function(itemName)
    local src = source
    local cfg = HBSConfig.MedicalItems[itemName]
    if not cfg then return end

    local cid = HBSUtils.GetCitizenId(src)
    if not cid then return end

    -- Remove item
    exports.ox_inventory:RemoveItem(src, itemName, 1)

    -- Heal injuries
    if cfg.heals and #cfg.heals > 0 then
        local injuries = HBS.Get(src, 'injuries') or {}
        local healParts = cfg.healParts or { 'any' }
        local toHeal = {}

        for part, sev in pairs(injuries) do
            local partOk = false
            for _, hp in ipairs(healParts) do
                if hp == 'any' or hp == part then partOk = true; break end
            end
            if partOk then
                for _, healSev in ipairs(cfg.heals) do
                    if sev == healSev then toHeal[#toHeal + 1] = part; break end
                end
            end
        end

        if #toHeal > 0 then
            for _, part in ipairs(toHeal) do
                injuries[part] = nil
                pcall(DB.SaveInjury, cid, part, nil)
            end
            HBS.Set(src, 'injuries', injuries)
            TriggerClientEvent('hbs_ambulance:client:applyInjuryEffects', src, injuries)
        end
    end

    -- Restore HP (delegate to client — GetEntityHealth is unreliable in OAL mode)
    if cfg.healthRestore then
        TriggerClientEvent('hbs_ambulance:client:addHealth', src, cfg.healthRestore)
    end

    -- Stress reduction
    if cfg.stressReduce then
        TriggerClientEvent('hbs_ambulance:client:addStress', src, -cfg.stressReduce)
        local stress = DB.LoadStress(cid)
        DB.SaveStress(cid, math.max(0, stress - cfg.stressReduce))
    end

    -- Addiction — use central RollAddiction (defined in sv_addiction.lua)
    if cfg.addictive and cfg.substance then
        RollAddiction(src, cfg.substance)
    end

    -- Withdrawal relief
    if cfg.withdrawalRelief then
        TriggerClientEvent('hbs_ambulance:client:addictionUpdate', src, DB.LoadAddiction(cid))
    end

    -- Addiction reduce (methadone)
    if cfg.addictionReduce then
        local addiction = DB.LoadAddiction(cid)
        for sub, level in pairs(addiction) do
            if level > 0 then
                DB.SaveAddiction(cid, sub, math.max(0, level - (cfg.reduceAmount or 1)))
            end
        end
        TriggerClientEvent('hbs_ambulance:client:addictionUpdate', src, DB.LoadAddiction(cid))
    end

    exports.qbx_core:Notify(src, (cfg.label or itemName) .. ' used.', 'success')
end)

-- ── Civilian self-treat (per-injury, staged severity, minigame) ──────────────
-- Mirrors emsTreatInjury but for civilian self-use.
-- success=true  → downgrade injury; item consumed.
-- success=false → item wasted; injury unchanged.

RegisterNetEvent('hbs_ambulance:server:useItemOnInjury', function(itemName, part, claimedSev, success)
    local src = source
    local cfg = HBSConfig.MedicalItems[itemName]
    if not cfg then return end

    -- Validate TreatMap entry
    local treatCfg = HBSConfig.TreatMap and HBSConfig.TreatMap[claimedSev]
    if not treatCfg or treatCfg.item ~= itemName then
        HBSLog('useItemOnInjury', ('invalid mapping: item=%s sev=%s'):format(itemName, tostring(claimedSev)))
        return
    end

    -- Validate item is in inventory
    if exports.ox_inventory:GetItemCount(src, itemName) < 1 then
        TriggerClientEvent('hbs_ambulance:client:notify', src, 'error',
            ('Missing %s — treatment cancelled.'):format(itemName))
        return
    end

    -- Consume item (win or lose)
    exports.ox_inventory:RemoveItem(src, itemName, 1)

    -- Apply any non-wound effects regardless of minigame outcome (HP, stress, addiction)
    local cid = HBSUtils.GetCitizenId(src)
    if not cid then return end

    if cfg.healthRestore then
        TriggerClientEvent('hbs_ambulance:client:addHealth', src, cfg.healthRestore)
    end
    if cfg.stressReduce then
        local stress = DB.LoadStress(cid)
        DB.SaveStress(cid, math.max(0, stress - cfg.stressReduce))
        TriggerClientEvent('hbs_ambulance:client:addStress', src, -cfg.stressReduce)
    end
    if cfg.addictive and cfg.substance then
        RollAddiction(src, cfg.substance)
    end

    if not success then
        HBSLog('useItemOnInjury', ('failed minigame: src=%s item=%s wasted'):format(tostring(src), itemName))
        return
    end

    -- Validate injury still matches — use state bag (authoritative, current even if DB unavailable)
    local injuries = HBS.Get(src, 'injuries') or {}
    if injuries[part] ~= claimedSev then
        TriggerClientEvent('hbs_ambulance:client:notify', src, 'inform', 'Injury already treated.')
        return
    end

    -- Downgrade one step (nil removes key = fully healed)
    injuries[part] = treatCfg.downgradeTo
    HBS.Set(src, 'injuries', injuries)
    TriggerClientEvent('hbs_ambulance:client:applyInjuryEffects', src, injuries)

    -- Persist to DB (best-effort)
    pcall(DB.SaveInjury, cid, part, treatCfg.downgradeTo)

    HBSLog('useItemOnInjury', ('success: cid=%s %s %s→%s'):format(
        cid, part, claimedSev, tostring(treatCfg.downgradeTo)))
end)

-- ── Civilian revive (first aid kit on downed player) ─────────────────────────

RegisterNetEvent('hbs_ambulance:server:civilianRevive', function(itemName, targetSrc)
    local src = source
    local cfg = HBSConfig.MedicalItems[itemName]
    if not cfg or not cfg.canCivilianRevive then return end

    -- Must have the item
    if exports.ox_inventory:GetItemCount(src, itemName) < 1 then return end
    exports.ox_inventory:RemoveItem(src, itemName, 1)

    -- Revive the player — keeps injuries (they're still hurt, just conscious)
    if not DownedPlayers[targetSrc] then return end
    DownedPlayers[targetSrc] = nil
    HBS.Set(targetSrc, 'isDowned', false)
    HBS.Set(targetSrc, 'triage', nil)

    -- Give them low HP — they're up but in bad shape
    TriggerClientEvent('hbs_ambulance:client:setHealth', targetSrc, 120)

    TriggerClientEvent('qbx_medical:client:playerRevived', targetSrc)
    TriggerClientEvent('hbs_ambulance:client:revived', targetSrc)
    TriggerClientEvent('hbs_ambulance:client:notify', targetSrc, 'inform',
        'You were revived by a bystander. Seek medical attention.')
    TriggerEvent('hbs:server:broadcastDownedBlips')
end)

-- ── Drug use ──────────────────────────────────────────────────────────────────

RegisterNetEvent('hbs_ambulance:server:useDrug', function(drugName)
    local src = source
    local cfg = HBSConfig.Drugs[drugName]
    if not cfg then return end

    local cid = HBSUtils.GetCitizenId(src)
    if not cid then return end

    -- Remove item from inventory
    local hasItem = exports.ox_inventory:GetItemCount(src, drugName) >= 1
    if not hasItem then return end
    exports.ox_inventory:RemoveItem(src, drugName, 1)

    -- Stress reduction
    if cfg.effects and cfg.effects.stressReduce then
        local stress = DB.LoadStress(cid)
        DB.SaveStress(cid, math.max(0, stress - cfg.effects.stressReduce))
        TriggerClientEvent('hbs_ambulance:client:addStress', src, -cfg.effects.stressReduce)
    end

    -- Addiction roll — use central RollAddiction (defined in sv_addiction.lua)
    if cfg.addictive and cfg.substance then
        RollAddiction(src, cfg.substance)
    end

    -- Tell client to apply high effect
    TriggerClientEvent('hbs_ambulance:client:drugEffect', src, drugName)
end)
