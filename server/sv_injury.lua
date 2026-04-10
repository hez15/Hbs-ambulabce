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
    else
        HBSLog('saveInjury', ('cid=%s skipped %s=%s — existing %s not worse'):format(cid, part, severity, tostring(cur)))
    end
end)
