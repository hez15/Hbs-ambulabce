-- HBS Migrations — versioned schema management
-- Runs on every resource start; each migration is applied exactly once.
-- The hbs_meta table stores the current schema version.

local RESOURCE = GetCurrentResourceName()

-- ── All migrations in order ────────────────────────────────────────────────
-- To add a new migration: append an entry to this table, increment the version.

local MIGRATIONS = {
    {
        version = 1,
        label   = 'initial schema',
        up      = {
            [[CREATE TABLE IF NOT EXISTS `hbs_injuries` (
                `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
                `citizenid`  VARCHAR(50)  NOT NULL,
                `body_part`  VARCHAR(20)  NOT NULL,
                `severity`   VARCHAR(20)  NOT NULL,
                `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                PRIMARY KEY (`id`),
                KEY `idx_cid` (`citizenid`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],

            [[CREATE TABLE IF NOT EXISTS `hbs_stress` (
                `citizenid`  VARCHAR(50)      NOT NULL,
                `stress`     TINYINT UNSIGNED NOT NULL DEFAULT 0,
                `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                PRIMARY KEY (`citizenid`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],

            [[CREATE TABLE IF NOT EXISTS `hbs_addiction` (
                `citizenid`  VARCHAR(50) NOT NULL,
                `substance`  VARCHAR(50) NOT NULL,
                `level`      TINYINT(1)  NOT NULL DEFAULT 0,
                `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                PRIMARY KEY (`citizenid`, `substance`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],

            [[CREATE TABLE IF NOT EXISTS `hbs_wills` (
                `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
                `citizenid`  VARCHAR(50)  NOT NULL,
                `last_words` TEXT         NOT NULL,
                `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                PRIMARY KEY (`id`),
                KEY `idx_cid` (`citizenid`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],

            [[CREATE TABLE IF NOT EXISTS `hbs_ems_research` (
                `citizenid`  VARCHAR(50) NOT NULL,
                `tier`       TINYINT     NOT NULL DEFAULT 1,
                `xp`         INT         NOT NULL DEFAULT 0,
                `unlocks`    TEXT        NULL,
                `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                PRIMARY KEY (`citizenid`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
        },
    },

    -- Future migrations go here, e.g.:
    -- {
    --     version = 2,
    --     label   = 'add patient records table',
    --     up = {
    --         [[CREATE TABLE IF NOT EXISTS `hbs_patient_records` (...)]],
    --     },
    -- },
}

local LATEST_VERSION = MIGRATIONS[#MIGRATIONS].version

-- ── Bootstrap meta table ───────────────────────────────────────────────────

local function EnsureMetaTable()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `hbs_meta` (
            `key`        VARCHAR(64)  NOT NULL,
            `value`      VARCHAR(255) NOT NULL,
            `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`key`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])
end

local function GetSchemaVersion()
    local rows = MySQL.query.await(
        'SELECT `value` FROM `hbs_meta` WHERE `key` = ?',
        { 'schema_version' }
    )
    if rows and rows[1] then
        return tonumber(rows[1].value) or 0
    end
    return 0
end

local function SetSchemaVersion(version)
    MySQL.query.await(
        'INSERT INTO `hbs_meta` (`key`, `value`) VALUES (?, ?) '
     .. 'ON DUPLICATE KEY UPDATE `value` = VALUES(`value`)',
        { 'schema_version', tostring(version) }
    )
end

-- ── Migration runner ───────────────────────────────────────────────────────

CreateThread(function()
    EnsureMetaTable()

    local current = GetSchemaVersion()

    if current >= LATEST_VERSION then
        print(('^2[%s] DB schema up to date (v%d)^0'):format(RESOURCE, current))
        return
    end

    print(('^3[%s] DB schema at v%d, latest is v%d — applying migrations...^0'):format(
        RESOURCE, current, LATEST_VERSION))

    local applied = 0
    for _, migration in ipairs(MIGRATIONS) do
        if migration.version > current then
            print(('^3[%s]   → Applying migration v%d: %s^0'):format(
                RESOURCE, migration.version, migration.label))

            for _, sql in ipairs(migration.up) do
                MySQL.query.await(sql)
            end

            SetSchemaVersion(migration.version)
            applied = applied + 1

            print(('^2[%s]   ✓ Migration v%d applied^0'):format(RESOURCE, migration.version))
        end
    end

    print(('^2[%s] Migrations complete — %d applied, schema now at v%d^0'):format(
        RESOURCE, applied, LATEST_VERSION))
end)
