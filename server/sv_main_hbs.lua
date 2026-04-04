-- HBS Server bootstrap: tables, global state, player load callbacks

DownedPlayers    = {}
DispatchCooldowns = {}

-- ── Create tables on startup ──────────────────────────────────────────────

CreateThread(function()
    MySQL.query([[CREATE TABLE IF NOT EXISTS `hbs_injuries` (
        `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `citizenid`  VARCHAR(50)  NOT NULL,
        `body_part`  VARCHAR(20)  NOT NULL,
        `severity`   VARCHAR(20)  NOT NULL,
        `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`), KEY `idx_cid` (`citizenid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])

    MySQL.query([[CREATE TABLE IF NOT EXISTS `hbs_stress` (
        `citizenid`  VARCHAR(50)      NOT NULL,
        `stress`     TINYINT UNSIGNED NOT NULL DEFAULT 0,
        `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (`citizenid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])

    MySQL.query([[CREATE TABLE IF NOT EXISTS `hbs_addiction` (
        `citizenid`  VARCHAR(50) NOT NULL,
        `substance`  VARCHAR(50) NOT NULL,
        `level`      TINYINT(1)  NOT NULL DEFAULT 0,
        `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (`citizenid`, `substance`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])

    MySQL.query([[CREATE TABLE IF NOT EXISTS `hbs_ems_research` (
        `citizenid`  VARCHAR(50) NOT NULL,
        `tier`       TINYINT     NOT NULL DEFAULT 1,
        `xp`         INT         NOT NULL DEFAULT 0,
        `unlocks`    TEXT        NULL,
        `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (`citizenid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
end)

-- ── Player state callback ─────────────────────────────────────────────────

lib.callback.register('hbs_ambulance:server:getPlayerState', function(source)
    local src = source
    local cid = HBSUtils.GetCitizenId(src)
    if not cid then return nil end

    local injuries    = DB.LoadInjuries(cid)
    local stress      = DB.LoadStress(cid)
    local addiction   = DB.LoadAddiction(cid)
    local emsResearch = DB.LoadEMSResearch(cid)

    HBS.Set(src, 'injuries',   injuries)
    HBS.Set(src, 'stress',     stress)
    HBS.Set(src, 'addiction',  addiction)
    HBS.Set(src, 'emsTier',    emsResearch.tier)
    HBS.Set(src, 'emsXP',      emsResearch.xp)
    HBS.Set(src, 'emsUnlocks', emsResearch.unlocks)

    HBSLog('getPlayerState', ('cid=%s stress=%d tier=%d xp=%d injuries=%d'):format(
        cid, stress, emsResearch.tier, emsResearch.xp, (function() local n=0; for _ in pairs(injuries) do n=n+1 end; return n end)()))

    return {
        injuries    = injuries,
        stress      = stress,
        addiction   = addiction,
        emsResearch = emsResearch,
    }
end)

-- ── EMS count callback ────────────────────────────────────────────────────

lib.callback.register('hbs_ambulance:server:getEMSCount', function()
    return HBSUtils.CountOnlineEMS()
end)

-- ── qbx_medical integration — keep HBS state in sync ─────────────────────
-- These events come directly from qbx_medical so we don't depend on the
-- client firing playerDowned. This makes HBS + qbx_medical one unified system.

AddEventHandler('qbx_medical:server:onPlayerLaststand', function()
    local src = source
    if DownedPlayers[src] then return end
    local cid = HBSUtils.GetCitizenId(src)
    if not cid then return end
    local coords = GetEntityCoords(GetPlayerPed(src))
    DownedPlayers[src] = { x = coords.x, y = coords.y, z = coords.z, citizenid = cid }
    HBS.Set(src, 'isDowned', true)
    TriggerEvent('hbs:server:broadcastDownedBlips')
    HBSLog('qbx_medical laststand', ('player %s (%s) → downed'):format(GetPlayerName(src), cid))
end)

AddEventHandler('qbx_medical:server:playerDied', function()
    local src = source
    if DownedPlayers[src] then return end
    local cid = HBSUtils.GetCitizenId(src)
    if not cid then return end
    local coords = GetEntityCoords(GetPlayerPed(src))
    DownedPlayers[src] = { x = coords.x, y = coords.y, z = coords.z, citizenid = cid }
    HBS.Set(src, 'isDowned', true)
    TriggerEvent('hbs:server:broadcastDownedBlips')
    HBSLog('qbx_medical playerDied', ('player %s (%s) → downed'):format(GetPlayerName(src), cid))
end)

AddEventHandler('qbx_medical:server:playerRespawned', function()
    local src = source
    DownedPlayers[src] = nil
    HBS.Set(src, 'isDowned', false)
    HBS.Set(src, 'triage', nil)
    local cid = HBSUtils.GetCitizenId(src)
    if cid then DB.ClearInjuries(cid) end
    HBS.Set(src, 'injuries', {})
    TriggerEvent('hbs:server:broadcastDownedBlips')
    TriggerClientEvent('hbs_ambulance:client:clearInjuries', src)
    HBSLog('qbx_medical playerRespawned', ('player %s cleared'):format(GetPlayerName(src)))
end)

-- ── Player downed ─────────────────────────────────────────────────────────

RegisterNetEvent('hbs_ambulance:server:playerDowned', function()
    local src = source
    local cid = HBSUtils.GetCitizenId(src)
    if not cid or DownedPlayers[src] then return end

    local coords = GetEntityCoords(GetPlayerPed(src))
    DownedPlayers[src] = { x = coords.x, y = coords.y, z = coords.z, citizenid = cid }
    HBS.Set(src, 'isDowned', true)

    TriggerEvent('hbs:server:broadcastDownedBlips')

    -- Dispatch alert with cooldown
    local now  = os.time()
    local last = DispatchCooldowns[src] or 0
    if (now - last) >= (HBSConfig.DispatchCooldown or 30) then
        DispatchCooldowns[src] = now
        -- Also use qbx alert
        local msg = string.format('Civilian down at %.0f, %.0f', coords.x, coords.y)
        local players = exports.qbx_core:GetQBPlayers()
        for _, v in pairs(players) do
            if v.PlayerData.job.type == 'ems' and v.PlayerData.job.onduty then
                TriggerClientEvent('hospital:client:ambulanceAlert', v.PlayerData.source, coords, msg)
            end
        end
    end
end)

-- ── Respawn request ───────────────────────────────────────────────────────

RegisterNetEvent('hbs_ambulance:server:requestRespawn', function()
    local src = source
    local cid = HBSUtils.GetCitizenId(src)
    if not cid then return end

    DownedPlayers[src] = nil
    HBS.Set(src, 'isDowned', false)
    DB.ClearInjuries(cid)
    HBS.Set(src, 'injuries', {})

    -- Bill player
    local Player = exports.qbx_core:GetPlayer(src)
    if Player then
        Player.Functions.RemoveMoney('bank', 2500, 'hospital-respawn')
    end

    -- Find nearest hospital check-in point and teleport there
    local pedCoords   = GetEntityCoords(GetPlayerPed(src))
    local sharedConfig = require 'config.shared'
    local nearest, bestDist = nil, math.huge

    for _, hospital in pairs(sharedConfig.locations.hospitals or {}) do
        local checkIn = hospital.checkIn
        if checkIn then
            -- checkIn may be a single vec3 or a table of vec3s
            local points = type(checkIn[1]) == 'table' and checkIn or { checkIn }
            for _, pt in ipairs(points) do
                local d = #(pedCoords - vector3(pt.x, pt.y, pt.z))
                if d < bestDist then bestDist = d; nearest = pt end
            end
        end
    end

    local spawnCoords = nearest
        or { x = 308.19, y = -595.35, z = 43.29, w = 0.0 } -- Pillbox fallback

    TriggerClientEvent('hbs_ambulance:client:respawnAt', src, spawnCoords)

    TriggerEvent('hbs:server:broadcastDownedBlips')
end)

-- ── Broadcast downed blips ────────────────────────────────────────────────

AddEventHandler('hbs:server:broadcastDownedBlips', function()
    local list = {}
    for srv, data in pairs(DownedPlayers) do
        table.insert(list, {
            src    = srv,
            x      = data.x, y = data.y, z = data.z,
            triage = HBS.Get(srv, 'triage'),
        })
    end
    TriggerClientEvent('hbs_ambulance:client:updateDownedBlips', -1, list)
end)

-- ── Triage ────────────────────────────────────────────────────────────────

RegisterNetEvent('hbs_ambulance:server:triagePatient', function(targetSrc, level)
    local src = source
    if not HBSUtils.IsEMS(src) then return end
    HBS.Set(targetSrc, 'triage', level)
    TriggerEvent('hbs:server:broadcastDownedBlips')
end)

-- ── Carry state ───────────────────────────────────────────────────────────

RegisterNetEvent('hbs_ambulance:server:setCarried', function(targetSrc, isCarried)
    HBS.Set(targetSrc, 'isCarried', isCarried)
end)

-- ── Admin /revive ─────────────────────────────────────────────────────────

RegisterCommand('revive', function(src, args)
    -- Console (src=0) or EMS job in-game
    if src ~= 0 and not HBSUtils.IsEMS(src) then
        TriggerClientEvent('hbs_ambulance:client:notify', src, 'error', 'Only EMS can use this.')
        return
    end
    local targetId = tonumber(args[1]) or src
    if not GetPlayerPed(targetId) then return end

    DownedPlayers[targetId] = nil
    HBS.Set(targetId, 'isDowned', false)
    HBS.Set(targetId, 'triage', nil)

    local cid = HBSUtils.GetCitizenId(targetId)
    if cid then DB.ClearInjuries(cid) end
    HBS.Set(targetId, 'injuries', {})

    TriggerClientEvent('qbx_medical:client:playerRevived', targetId)
    TriggerClientEvent('hbs_ambulance:client:revived', targetId)
    TriggerEvent('hbs:server:broadcastDownedBlips')
    HBSLog('revive command', ('src=%s revived target=%s'):format(tostring(src), tostring(targetId)))
end, false)
