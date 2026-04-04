-- HBS Stress persistence

RegisterNetEvent('hbs_ambulance:server:saveStress', function(stress)
    local src = source
    local cid = HBSUtils.GetCitizenId(src)
    if not cid then return end
    local clamped = math.max(0, math.min(100, stress))
    DB.SaveStress(cid, clamped)
    HBS.Set(src, 'stress', clamped)
end)
