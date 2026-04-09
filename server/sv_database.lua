-- HBS Database helpers

DB = {}

-- ── Injuries ──────────────────────────────────────────────────────────────

function DB.LoadInjuries(cid)
    local rows = MySQL.query.await('SELECT body_part, severity FROM hbs_injuries WHERE citizenid = ?', { cid })
    local result = {}
    for _, row in ipairs(rows or {}) do
        result[row.body_part] = row.severity
    end
    return result
end

function DB.SaveInjury(cid, part, severity)
    MySQL.query.await('DELETE FROM hbs_injuries WHERE citizenid = ? AND body_part = ?', { cid, part })
    if severity then
        MySQL.insert.await('INSERT INTO hbs_injuries (citizenid, body_part, severity) VALUES (?, ?, ?)', { cid, part, severity })
    end
end

function DB.ClearInjuries(cid)
    MySQL.query.await('DELETE FROM hbs_injuries WHERE citizenid = ?', { cid })
end

-- ── Stress ────────────────────────────────────────────────────────────────

function DB.LoadStress(cid)
    local row = MySQL.single.await('SELECT stress FROM hbs_stress WHERE citizenid = ?', { cid })
    return row and row.stress or 0
end

function DB.SaveStress(cid, stress)
    MySQL.query.await('INSERT INTO hbs_stress (citizenid, stress) VALUES (?, ?) ON DUPLICATE KEY UPDATE stress = ?', { cid, stress, stress })
end

-- ── Addiction ─────────────────────────────────────────────────────────────

function DB.LoadAddiction(cid)
    local rows = MySQL.query.await('SELECT substance, level FROM hbs_addiction WHERE citizenid = ?', { cid })
    local result = {}
    for _, row in ipairs(rows or {}) do
        result[row.substance] = row.level  -- plain number: { morphine = 2 }
    end
    return result
end

function DB.SaveAddiction(cid, substance, level)
    MySQL.query.await('INSERT INTO hbs_addiction (citizenid, substance, level) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE level = ?', { cid, substance, level, level })
end

-- ── EMS Research ──────────────────────────────────────────────────────────

function DB.LoadEMSResearch(cid)
    local row = MySQL.single.await('SELECT tier, xp, unlocks FROM hbs_ems_research WHERE citizenid = ?', { cid })
    if not row then return { tier = 1, xp = 0, unlocks = {} } end
    local unlocks = {}
    if row.unlocks and row.unlocks ~= '' then
        for ability in row.unlocks:gmatch('[^,]+') do
            table.insert(unlocks, ability)
        end
    end
    return { tier = row.tier, xp = row.xp, unlocks = unlocks }
end

function DB.SaveEMSResearch(cid, tier, xp, unlocks)
    local unlocksStr = table.concat(unlocks or {}, ',')
    MySQL.query.await('INSERT INTO hbs_ems_research (citizenid, tier, xp, unlocks) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE tier = ?, xp = ?, unlocks = ?',
        { cid, tier, xp, unlocksStr, tier, xp, unlocksStr })
end

-- ── Diseases ──────────────────────────────────────────────────────────────

function DB.LoadDiseases(cid)
    local rows = MySQL.query.await('SELECT disease, stage FROM hbs_diseases WHERE citizenid = ?', { cid })
    local result = {}
    for _, row in ipairs(rows or {}) do
        result[row.disease] = row.stage
    end
    return result
end

function DB.SaveDisease(cid, disease, stage)
    MySQL.query.await(
        'INSERT INTO hbs_diseases (citizenid, disease, stage) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE stage = ?',
        { cid, disease, stage, stage }
    )
end

function DB.ClearDisease(cid, disease)
    MySQL.query.await('DELETE FROM hbs_diseases WHERE citizenid = ? AND disease = ?', { cid, disease })
end

function DB.ClearAllDiseases(cid)
    MySQL.query.await('DELETE FROM hbs_diseases WHERE citizenid = ?', { cid })
end
