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
        local injuries = DB.LoadInjuries(cid)
        local healParts = cfg.healParts or { 'any' }
        local healed = false

        for part, sev in pairs(injuries) do
            local partOk = false
            for _, hp in ipairs(healParts) do
                if hp == 'any' or hp == part then partOk = true; break end
            end
            if partOk then
                for _, healSev in ipairs(cfg.heals) do
                    if sev == healSev then
                        DB.SaveInjury(cid, part, nil)
                        healed = true
                        break
                    end
                end
            end
        end

        if healed then
            local updated = DB.LoadInjuries(cid)
            HBS.Set(src, 'injuries', updated)
            TriggerClientEvent('hbs_ambulance:client:applyInjuryEffects', src)
        end
    end

    -- Restore HP
    if cfg.healthRestore then
        local ped = GetPlayerPed(src)
        SetEntityHealth(ped, math.min(200, GetEntityHealth(ped) + cfg.healthRestore))
    end

    -- Stress reduction
    if cfg.stressReduce then
        TriggerClientEvent('hbs_ambulance:client:addStress', src, -cfg.stressReduce)
        local stress = DB.LoadStress(cid)
        DB.SaveStress(cid, math.max(0, stress - cfg.stressReduce))
    end

    -- Addiction
    if cfg.addictive and cfg.substance then
        local addiction  = DB.LoadAddiction(cid)
        local curLevel   = addiction[cfg.substance] or 0
        local chance     = cfg.addictChance[curLevel] or 0.05
        if math.random() < chance then
            local newLevel = math.min(4, curLevel + 1)
            DB.SaveAddiction(cid, cfg.substance, newLevel)
            TriggerClientEvent('hbs_ambulance:client:addictionUpdate', src, DB.LoadAddiction(cid))
        end
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
    local ped = GetPlayerPed(targetSrc)
    SetEntityHealth(ped, 120) -- ~20 HP above minimum

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

    -- Addiction roll
    if cfg.addictive and cfg.substance then
        local addiction = DB.LoadAddiction(cid)
        local curLevel  = addiction[cfg.substance] or 0
        local chance    = cfg.addictChance and cfg.addictChance[curLevel] or 0.10
        if math.random() < chance then
            local newLevel = math.min(4, curLevel + 1)
            DB.SaveAddiction(cid, cfg.substance, newLevel)
            TriggerClientEvent('hbs_ambulance:client:addictionUpdate', src, DB.LoadAddiction(cid))
        end
    end

    -- Tell client to apply high effect
    TriggerClientEvent('hbs_ambulance:client:drugEffect', src, drugName)
end)
