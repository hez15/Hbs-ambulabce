-- HBS Addiction persistence

RegisterNetEvent('hbs_ambulance:server:saveAddiction', function(substance, level)
    local src = source
    local cid = HBSUtils.GetCitizenId(src)
    if not cid then return end
    DB.SaveAddiction(cid, substance, level)
    HBS.Set(src, 'addiction', DB.LoadAddiction(cid))
end)
