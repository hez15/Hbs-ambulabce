-- Death: downed state, bleedout tracking, respawn, NPC heal, blip broadcast

-- ── Player downed ─────────────────────────────────────────────────────────
-- Triggered by our own client OR by qbx_medical when player enters last stand.

-- qbx_medical fires this when a player enters last stand.
-- We hook it so qbx_medical-managed deaths still populate DownedPlayers
-- and send dispatch alerts without the client having to duplicate logic.
RegisterNetEvent('qbx_medical:server:onPlayerLaststand', function()
    local src = source
    if DownedPlayers[src] then return end  -- already tracked (our event fired first)
    TriggerEvent('hbs_ambulance:server:playerDowned', src)
end)

-- qbx_medical fires this when a player respawns through qbx_ambulancejob's
-- hospital check-in. We hook it to clear our tracking state.
RegisterNetEvent('qbx_medical:server:playerRespawned', function()
    local src = source
    if not DownedPlayers[src] then return end
    DownedPlayers[src] = nil
    SB.Set(src, 'isDowned', false)
    TriggerEvent('hbs_ambulance:server:broadcastDownedBlips')
end)

RegisterNetEvent('hbs_ambulance:server:playerDowned', function(overrideSrc)
    -- When called via TriggerEvent internally, overrideSrc carries the real src
    local src = overrideSrc or source
    local cid    = Utils.GetCitizenId(src)
    if not cid then return end

    local coords = GetEntityCoords(GetPlayerPed(src))
    DownedPlayers[src] = { x = coords.x, y = coords.y, z = coords.z, citizenid = cid }
    SB.Set(src, 'isDowned', true)

    TriggerEvent('hbs_ambulance:server:broadcastDownedBlips')

    -- Dispatch alert with cooldown
    local now = os.time()
    local last = DispatchCooldowns[src] or 0
    if (now - last) >= Config.DispatchCooldown then
        DispatchCooldowns[src] = now
        local msg = Locale('ems_dispatch_msg',
            string.format('%.0f, %.0f', coords.x, coords.y))
        TriggerClientEvent('hbs_ambulance:client:emsDispatch', -1, msg)
    end

    -- NPC auto-heal if no EMS online after delay
    if Config.NPCHealEnabled then
        SetTimeout(Config.NpcHealTime * 1000, function()
            if DownedPlayers[src] and Utils.CountOnlineEMS() < Config.MinEmsOnline then
                TriggerEvent('hbs_ambulance:server:npcHeal', src)
            end
        end)
    end
end)

-- ── Respawn request ───────────────────────────────────────────────────────

RegisterNetEvent('hbs_ambulance:server:requestRespawn', function(willText)
    local src    = source
    local cid    = Utils.GetCitizenId(src)
    local Player = exports.qbx_core:GetPlayer(src)
    if not cid or not Player then return end

    DownedPlayers[src] = nil
    SB.Set(src, 'isDowned', false)

    -- Bill
    if Config.DeathBill.enabled then
        DB.AddBill(cid, Config.DeathBill.baseAmount, 'Hospital Respawn')
        TriggerClientEvent('hbs_ambulance:client:billSent', src, Config.DeathBill.baseAmount)
    end

    -- Clear injuries
    DB.ClearInjuries(cid)
    SB.Set(src, 'injuries', {})

    -- Teleport to nearest hospital spawn point
    local coords   = GetEntityCoords(GetPlayerPed(src))
    local hospital = Utils.GetNearestHospital(coords)
    if hospital then
        local sp = hospital.spawnCoord
        TriggerClientEvent('hbs_ambulance:client:respawnAt', src, {
            x = sp.x, y = sp.y, z = sp.z, w = sp.w,
        })
    end

    TriggerEvent('hbs_ambulance:server:broadcastDownedBlips')
end)

-- ── NPC auto-heal ─────────────────────────────────────────────────────────

AddEventHandler('hbs_ambulance:server:npcHeal', function(src)
    if not DownedPlayers[src] then return end
    local cid = Utils.GetCitizenId(src)
    if not cid then return end

    DownedPlayers[src] = nil
    SB.Set(src, 'isDowned', false)

    DB.AddBill(cid, Config.NpcHealCost, 'NPC Doctor Treatment')
    DB.ClearInjuries(cid)
    SB.Set(src, 'injuries', {})

    TriggerClientEvent('hbs_ambulance:client:billSent', src, Config.NpcHealCost)
    TriggerClientEvent('hbs_ambulance:client:hospitalHealed', src)

    local coords   = GetEntityCoords(GetPlayerPed(src))
    local hospital = Utils.GetNearestHospital(coords)
    if hospital then
        local sp = hospital.spawnCoord
        TriggerClientEvent('hbs_ambulance:client:respawnAt', src, {
            x = sp.x, y = sp.y, z = sp.z, w = sp.w,
        })
    end

    TriggerEvent('hbs_ambulance:server:broadcastDownedBlips')
end)

-- ── Broadcast downed player blips to all clients ──────────────────────────

AddEventHandler('hbs_ambulance:server:broadcastDownedBlips', function()
    local list = {}
    for srv, data in pairs(DownedPlayers) do
        table.insert(list, {
            src    = srv,
            x      = data.x,
            y      = data.y,
            z      = data.z,
            triage = SB.Get(srv, 'triage'),
        })
    end
    TriggerClientEvent('hbs_ambulance:client:updateDownedBlips', -1, list)
end)
