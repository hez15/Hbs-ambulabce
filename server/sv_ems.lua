-- EMS server: revive, treat, carry state, patient transport

-- ── Revive by EMS ─────────────────────────────────────────────────────────

RegisterNetEvent('hbs_ambulance:server:revivePlayer', function(targetSrc)
    local src = source
    if not Utils.IsEMS(src) then return end

    local targetCid = Utils.GetCitizenId(targetSrc)
    if not targetCid then return end

    -- Remove from downed registry
    DownedPlayers[targetSrc] = nil
    SB.Set(targetSrc, 'isDowned',  false)

    -- Clear injuries
    DB.ClearInjuries(targetCid)
    SB.Set(targetSrc, 'injuries', {})

    -- Remove defib from EMS inventory
    if Config.ReviveRequiresItem then
        exports.ox_inventory:RemoveItem(src, Config.ReviveItem, 1)
    end

    TriggerClientEvent('hbs_ambulance:client:revived', targetSrc)
    TriggerEvent('hbs_ambulance:server:broadcastDownedBlips')
    Utils.Debug('EMS', src, 'revived player', targetSrc)
end)

-- ── Treat wounds (EMS) ────────────────────────────────────────────────────

RegisterNetEvent('hbs_ambulance:server:treatPlayer', function(targetSrc)
    local src = source
    if not Utils.IsEMS(src) then return end

    local targetCid = Utils.GetCitizenId(targetSrc)
    if not targetCid then return end

    -- Remove all non-critical injuries
    local injuries = DB.LoadInjuries(targetCid)
    for part, sev in pairs(injuries) do
        if sev ~= 'critical' then
            DB.SaveInjury(targetCid, part, nil)
        end
    end

    -- Reload and sync
    local updated = DB.LoadInjuries(targetCid)
    SB.Set(targetSrc, 'injuries', updated)
    TriggerClientEvent('hbs_ambulance:client:applyInjuryEffects', targetSrc)
end)

-- ── Carry state ───────────────────────────────────────────────────────────

RegisterNetEvent('hbs_ambulance:server:setCarried', function(targetSrc, isCarried, carrierSrc)
    SB.Set(targetSrc, 'isCarried',  isCarried)
    SB.Set(targetSrc, 'carrierSrc', carrierSrc)
end)

-- ── Ambulance patient load/unload ─────────────────────────────────────────

RegisterNetEvent('hbs_ambulance:server:loadPatient', function(targetSrc, plate)
    SB.Set(targetSrc, 'isCarried', true)
    Utils.Debug('Patient', targetSrc, 'loaded into', plate)
end)

RegisterNetEvent('hbs_ambulance:server:unloadPatient', function(targetSrc)
    SB.Set(targetSrc, 'isCarried', false)
    TriggerClientEvent('hbs_ambulance:client:patientUnloaded', source)
end)
