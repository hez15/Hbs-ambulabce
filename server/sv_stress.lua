-- Stress persistence

RegisterNetEvent('hbs_ambulance:server:saveStress', function(stressValue)
    local src = source
    local cid = Utils.GetCitizenId(src)
    if not cid then return end

    local val = Utils.Clamp(math.floor(stressValue), 0, Config.Stress.max)
    DB.SaveStress(cid, val)
    SB.Set(src, 'stress', val)
end)
