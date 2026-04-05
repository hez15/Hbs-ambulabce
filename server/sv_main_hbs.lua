-- HBS Server bootstrap: tables, global state, player load callbacks

DownedPlayers    = {}
DispatchCooldowns = {}

-- ── Set state bags on server-side player load ─────────────────────────────
-- This runs BEFORE the client's lib.callback fires, so HasUnlock() works
-- from the very first server event the player triggers (e.g. first revive).

local function ApplyPlayerStateBags(src, cid)
    local emsResearch = DB.LoadEMSResearch(cid)
    local injuries    = DB.LoadInjuries(cid)
    local stress      = DB.LoadStress(cid)
    local addiction   = DB.LoadAddiction(cid)
    HBS.Set(src, 'emsTier',    emsResearch.tier)
    HBS.Set(src, 'emsXP',      emsResearch.xp)
    HBS.Set(src, 'emsUnlocks', emsResearch.unlocks)
    HBS.Set(src, 'injuries',   injuries)
    HBS.Set(src, 'stress',     stress)
    HBS.Set(src, 'addiction',  addiction)
    HBSLog('ApplyPlayerStateBags', ('cid=%s tier=%d xp=%d'):format(cid, emsResearch.tier, emsResearch.xp))
end

AddEventHandler('QBCore:Server:PlayerLoaded', function(player)
    local src = player.PlayerData.source
    local cid = player.PlayerData.citizenid
    if not cid then return end
    ApplyPlayerStateBags(src, cid)
end)

-- ── Player state callback ─────────────────────────────────────────────────

lib.callback.register('hbs_ambulance:server:getPlayerState', function(source)
    local src = source

    -- QBX may not have registered the player yet on the very first login tick;
    -- retry up to 5 times with a short wait before giving up.
    local cid = nil
    for i = 1, 5 do
        local player = exports.qbx_core:GetPlayer(src)
        if player then
            cid = player.PlayerData.citizenid
            break
        end
        Wait(400)
    end
    if not cid then
        HBSLog('getPlayerState', ('WARNING: could not resolve cid for src=%s after retries'):format(tostring(src)))
        return nil
    end

    -- Re-apply state bags (handles cases where QBCore:Server:PlayerLoaded fired before DB was ready)
    ApplyPlayerStateBags(src, cid)

    local injuries    = HBS.Get(src, 'injuries')   or {}
    local stress      = HBS.Get(src, 'stress')     or 0
    local addiction   = HBS.Get(src, 'addiction')  or {}
    local emsResearch = {
        tier    = HBS.Get(src, 'emsTier')    or 1,
        xp      = HBS.Get(src, 'emsXP')      or 0,
        unlocks = HBS.Get(src, 'emsUnlocks') or {},
    }

    HBSLog('getPlayerState', ('cid=%s stress=%d tier=%d xp=%d'):format(
        cid, stress, emsResearch.tier, emsResearch.xp))

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

RegisterNetEvent('hbs_ambulance:server:requestRespawn', function(lastWords)
    local src = source
    local cid = HBSUtils.GetCitizenId(src)
    if not cid then return end

    -- Save last words if provided
    if lastWords and type(lastWords) == 'string' and #lastWords > 0 then
        local trimmed = lastWords:sub(1, 280)  -- cap at textarea maxlength
        MySQL.insert('INSERT INTO hbs_wills (citizenid, last_words) VALUES (?, ?)', { cid, trimmed })
        HBSLog('requestRespawn', ('saved last words for cid=%s (%d chars)'):format(cid, #trimmed))
    end

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
