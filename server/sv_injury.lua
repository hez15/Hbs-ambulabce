-- HBS Injury persistence

RegisterNetEvent('hbs_ambulance:server:saveInjury', function(part, severity)
    local src = source
    local cid = HBSUtils.GetCitizenId(src)
    if not cid then return end

    local existing = DB.LoadInjuries(cid)
    local cur = existing[part]

    -- Only save if new injury is worse than existing
    if not cur or InjuryDefs.IsWorse(severity, cur) then
        local ok, err = pcall(DB.SaveInjury, cid, part, severity)
        if not ok then
            HBSLog('saveInjury', ('DB save failed (run SQL migration?): %s'):format(tostring(err)))
        end
        existing[part] = severity  -- always update state bag, even if DB failed
        HBS.Set(src, 'injuries', existing)
        TriggerClientEvent('hbs_ambulance:client:applyInjuryEffects', src, existing)
        HBSLog('saveInjury', ('cid=%s part=%s sev=%s (prev=%s)'):format(cid, part, severity, tostring(cur)))

        -- Critical/fracture wounds have a chance to develop infection
        if (severity == 'critical' or severity == 'fracture') and HBSConfig.Diseases and HBSConfig.Diseases.infection then
            local infChance = severity == 'critical' and 0.15 or 0.06
            if math.random() < infChance then
                local diseases = DB.LoadDiseases(cid)
                if not diseases.infection then
                    pcall(DB.SaveDisease, cid, 'infection', 1)
                    diseases.infection = 1
                    HBS.Set(src, 'diseases', diseases)
                    TriggerClientEvent('hbs_ambulance:client:diseasesUpdate', src, diseases)
                    TriggerClientEvent('hbs_ambulance:client:notify', src, 'error',
                        'Your wound shows early signs of infection.')
                    HBSLog('saveInjury', ('wound infection triggered: cid=%s severity=%s'):format(cid, severity))
                end
            end
        end
    else
        HBSLog('saveInjury', ('cid=%s skipped %s=%s — existing %s not worse'):format(cid, part, severity, tostring(cur)))
    end
end)
