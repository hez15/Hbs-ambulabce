-- Injury persistence: save, clear, sync state bags

RegisterNetEvent('hbs_ambulance:server:saveInjury', function(bodyPart, severity)
    local src = source
    local cid = Utils.GetCitizenId(src)
    if not cid then return end

    DB.SaveInjury(cid, bodyPart, severity)

    -- Reload and sync full injury table via state bag
    local injuries = DB.LoadInjuries(cid)
    SB.Set(src, 'injuries', injuries)
end)

RegisterNetEvent('hbs_ambulance:server:clearAllInjuries', function()
    local src = source
    local cid = Utils.GetCitizenId(src)
    if not cid then return end

    DB.ClearInjuries(cid)
    SB.Set(src, 'injuries', {})
end)
