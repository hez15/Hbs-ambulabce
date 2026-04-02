-- HBS Stress persistence

RegisterNetEvent('hbs_ambulance:server:saveStress', function(stress)
    local src = source
    local cid = HBSUtils.GetCitizenId(src)
    if not cid then return end
    DB.SaveStress(cid, math.max(0, math.min(100, stress)))
    HBS.Set(src, 'stress', stress)
end)
