-- Server-side item use processing (authority: remove item, apply effects)

RegisterNetEvent('hbs_ambulance:server:useItem', function(itemName, data)
    local src = source
    local cfg = Config.MedicalItems[itemName]
    if not cfg then return end

    local cid    = Utils.GetCitizenId(src)
    local Player = exports.qbx_core:GetPlayer(src)
    if not cid or not Player then return end

    -- Consume item
    exports.ox_inventory:RemoveItem(src, itemName, 1)

    -- ── Defibrillator / revive ────────────────────────────────────────────
    if cfg.canRevive and data.targetSrc then
        local targetSrc = data.targetSrc
        local targetCid = Utils.GetCitizenId(targetSrc)
        if not targetCid then return end

        DownedPlayers[targetSrc] = nil
        SB.Set(targetSrc, 'isDowned', false)
        SB.Set(targetSrc, 'triage',   nil)
        DB.ClearInjuries(targetCid)
        SB.Set(targetSrc, 'injuries', {})
        TriggerClientEvent('hbs_ambulance:client:revived', targetSrc)
        TriggerClientEvent('hbs_ambulance:client:applyInjuryEffects', targetSrc)
        TriggerEvent('hbs_ambulance:server:broadcastDownedBlips')
        return
    end

    -- ── Health restore ────────────────────────────────────────────────────
    if cfg.healthRestore then
        local ped = GetPlayerPed(src)
        SetEntityHealth(ped, math.min(200, GetEntityHealth(ped) + cfg.healthRestore))
    end

    -- ── Bloodloss clear ───────────────────────────────────────────────────
    if cfg.treatBloodloss then
        SB.Set(src, 'bloodloss', false)
    end

    -- ── Wound healing ─────────────────────────────────────────────────────
    if cfg.heals and #cfg.heals > 0 then
        local injuries = DB.LoadInjuries(cid)
        for part, curSev in pairs(injuries) do
            if Utils.TableContains(cfg.heals, curSev) then
                -- Check body part restriction
                local allowed = (not cfg.healParts) or
                                Utils.TableContains(cfg.healParts, 'any') or
                                Utils.TableContains(cfg.healParts, part)
                if allowed then
                    DB.SaveInjury(cid, part, nil)
                    break   -- heal first matching injury only (one use)
                end
            end
        end
        local updated = DB.LoadInjuries(cid)
        SB.Set(src, 'injuries', updated)
        TriggerClientEvent('hbs_ambulance:client:applyInjuryEffects', src)
    end

    -- ── Stress reduction ──────────────────────────────────────────────────
    if cfg.stressReduce then
        local curStress = SB.Get(src, 'stress') or 0
        local newStress = math.max(0, curStress - cfg.stressReduce)
        SB.Set(src, 'stress', newStress)
        DB.SaveStress(cid, newStress)
        TriggerClientEvent('hbs_ambulance:client:setStress', src, newStress)
    end

    -- ── Pain suppression ──────────────────────────────────────────────────
    if cfg.painDuration then
        SB.Set(src, 'inPain', true)
        SetTimeout(cfg.painDuration * 1000, function()
            SB.Set(src, 'inPain', false)
        end)
    end

    -- ── Addiction processing ──────────────────────────────────────────────
    if cfg.addictive and cfg.substance then
        TriggerEvent('hbs_ambulance:server:processAddiction', src, cid, cfg)
    end

    -- ── Withdrawal relief (methadone, painkiller) ─────────────────────────
    if cfg.withdrawalRelief then
        TriggerEvent('hbs_ambulance:server:relieveWithdrawal', src, cid, cfg)
    end

    -- ── Addiction reduce (methadone) ──────────────────────────────────────
    if cfg.addictionReduce and cfg.reduceAmount then
        TriggerEvent('hbs_ambulance:server:reduceAddiction', src, cid, cfg.reduceAmount)
    end
end)

-- ── Blood test ────────────────────────────────────────────────────────────

RegisterNetEvent('hbs_ambulance:server:bloodTest', function(targetSrc)
    local src = source
    if not Utils.IsEMS(src) then return end

    -- Consume item
    exports.ox_inventory:RemoveItem(src, 'blood_test_kit', 1)

    local targetCid = Utils.GetCitizenId(targetSrc)
    if not targetCid then
        TriggerClientEvent('hbs_ambulance:client:notify', src, {
            msg = 'Could not identify patient.', type = 'error'
        })
        return
    end

    local addictions = DB.LoadAddiction(targetCid)

    -- Get patient display name
    local Player = exports.qbx_core:GetPlayer(targetSrc)
    local targetName = Player and Player.PlayerData.charinfo and
        (Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname)
        or 'Unknown'

    -- Send results to EMS
    TriggerClientEvent('hbs_ambulance:client:bloodTestResult', src, targetName, addictions)

    -- Award XP
    TriggerEvent('hbs_ambulance:server:awardEMSXP', src,
        Config.EMSResearch.xpRewards.bloodTest or 20)

    Utils.Debug('Blood test by EMS', src, 'on', targetSrc, targetCid)
end)
