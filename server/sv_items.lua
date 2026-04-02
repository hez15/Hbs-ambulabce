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
        local addiction = DB.LoadAddiction(cid)
        local sub = addiction[cfg.substance] or { level = 0 }
        local chance = cfg.addictChance[sub.level] or 0.05
        if math.random() < chance then
            local newLevel = math.min(4, sub.level + 1)
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
        for sub, data in pairs(addiction) do
            if data.level > 0 then
                DB.SaveAddiction(cid, sub, math.max(0, data.level - (cfg.reduceAmount or 1)))
            end
        end
        TriggerClientEvent('hbs_ambulance:client:addictionUpdate', src, DB.LoadAddiction(cid))
    end

    exports.qbx_core:Notify(src, (cfg.label or itemName) .. ' used.', 'success')
end)
