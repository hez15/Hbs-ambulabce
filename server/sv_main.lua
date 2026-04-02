-- Server bootstrap: create DB tables, global state, player load/unload

-- ── In-memory state ───────────────────────────────────────────────────────

DownedPlayers    = {}   -- { [src] = { x, y, z, citizenid } }
DispatchCooldowns = {}  -- { [src] = os.time() }
WithdrawalTimers = {}   -- { [src] = { [substance] = timer handle } }

-- ── Create tables on startup ──────────────────────────────────────────────

CreateThread(function()
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `hbs_injuries` (
            `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
            `citizenid`  VARCHAR(50)  NOT NULL,
            `body_part`  VARCHAR(20)  NOT NULL,
            `severity`   VARCHAR(20)  NOT NULL,
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            KEY `idx_citizenid` (`citizenid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `hbs_stress` (
            `citizenid`  VARCHAR(50)      NOT NULL,
            `stress`     TINYINT UNSIGNED NOT NULL DEFAULT 0,
            `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`citizenid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `hbs_bills` (
            `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
            `citizenid`  VARCHAR(50)  NOT NULL,
            `amount`     INT UNSIGNED NOT NULL,
            `reason`     VARCHAR(200) NOT NULL DEFAULT 'Hospital Bill',
            `paid`       TINYINT(1)   NOT NULL DEFAULT 0,
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            KEY `idx_cid_paid` (`citizenid`, `paid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `hbs_addiction` (
            `citizenid`  VARCHAR(50)  NOT NULL,
            `substance`  VARCHAR(50)  NOT NULL,
            `level`      TINYINT(1)   NOT NULL DEFAULT 0,
            `last_use`   TIMESTAMP    NULL DEFAULT NULL,
            `total_uses` INT(11)      NOT NULL DEFAULT 0,
            `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`citizenid`, `substance`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])
    Utils.Debug('hbs_ambulance: DB tables ready')
end)

-- ── Player loaded ─────────────────────────────────────────────────────────

AddEventHandler('QBCore:Server:PlayerLoaded', function(Player)
    local src = Player.PlayerData.source
    local cid = Player.PlayerData.citizenid
    if not cid then return end

    local injuries  = DB.LoadInjuries(cid)
    local stress    = DB.LoadStress(cid)
    local addictions= DB.LoadAddiction(cid)

    -- Build simple addiction level table { substance = level }
    local addLevel = {}
    for sub, data in pairs(addictions) do
        addLevel[sub] = data.level
    end

    SB.Set(src, 'injuries',  injuries)
    SB.Set(src, 'stress',    stress)
    SB.Set(src, 'isDowned',  false)
    SB.Set(src, 'addiction', addLevel)

    -- Schedule withdrawal timers for existing addictions
    TriggerEvent('hbs_ambulance:server:scheduleWithdrawal', src, cid, addictions)

    Utils.Debug('Player loaded:', cid, 'stress:', stress,
        'injuries:', Utils.TableLength(injuries))
end)

-- Compatibility for qbx_core event name
AddEventHandler('qbx_core:playerLoaded', function(Player)
    TriggerEvent('QBCore:Server:PlayerLoaded', Player)
end)

-- ── Player dropped ────────────────────────────────────────────────────────

AddEventHandler('playerDropped', function()
    local src = source
    DownedPlayers[src]     = nil
    DispatchCooldowns[src] = nil
    -- Cancel withdrawal timers
    if WithdrawalTimers[src] then
        WithdrawalTimers[src] = nil
    end
    TriggerEvent('hbs_ambulance:server:broadcastDownedBlips')
end)

-- ── Callback: get player state (called on client load) ────────────────────

lib.callback.register('hbs_ambulance:getPlayerState', function(source)
    local src = source
    local cid = Utils.GetCitizenId(src)
    if not cid then return nil end

    local injuries   = DB.LoadInjuries(cid)
    local stress     = DB.LoadStress(cid)
    local addictions = DB.LoadAddiction(cid)
    local addLevel   = {}
    for sub, data in pairs(addictions) do addLevel[sub] = data.level end

    SB.Set(src, 'injuries',  injuries)
    SB.Set(src, 'stress',    stress)
    SB.Set(src, 'addiction', addLevel)

    return {
        isDowned = SB.Get(src, 'isDowned') or false,
        injuries = injuries,
        stress   = stress,
        addiction= addLevel,
    }
end)
