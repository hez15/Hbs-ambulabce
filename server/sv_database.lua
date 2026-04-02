-- Database helper functions (called by other server modules)
-- All functions are synchronous (use MySQL.await)

DB = {}

-- ── Injuries ──────────────────────────────────────────────────────────────

function DB.LoadInjuries(citizenid)
    local rows = MySQL.query.await(
        'SELECT body_part, severity FROM hbs_injuries WHERE citizenid = ?',
        { citizenid }
    )
    local t = {}
    for _, r in ipairs(rows or {}) do
        t[r.body_part] = r.severity
    end
    return t
end

function DB.SaveInjury(citizenid, bodyPart, severity)
    MySQL.query.await(
        'DELETE FROM hbs_injuries WHERE citizenid = ? AND body_part = ?',
        { citizenid, bodyPart }
    )
    if severity then
        MySQL.insert.await(
            'INSERT INTO hbs_injuries (citizenid, body_part, severity) VALUES (?, ?, ?)',
            { citizenid, bodyPart, severity }
        )
    end
end

function DB.ClearInjuries(citizenid)
    MySQL.query.await(
        'DELETE FROM hbs_injuries WHERE citizenid = ?',
        { citizenid }
    )
end

-- ── Stress ────────────────────────────────────────────────────────────────

function DB.LoadStress(citizenid)
    local row = MySQL.single.await(
        'SELECT stress FROM hbs_stress WHERE citizenid = ?',
        { citizenid }
    )
    return row and row.stress or 0
end

function DB.SaveStress(citizenid, stress)
    MySQL.query.await(
        'INSERT INTO hbs_stress (citizenid, stress) VALUES (?, ?) ON DUPLICATE KEY UPDATE stress = ?',
        { citizenid, stress, stress }
    )
end

-- ── Bills ─────────────────────────────────────────────────────────────────

function DB.AddBill(citizenid, amount, reason)
    MySQL.insert.await(
        'INSERT INTO hbs_bills (citizenid, amount, reason) VALUES (?, ?, ?)',
        { citizenid, amount, reason }
    )
end

function DB.GetUnpaidBills(citizenid)
    return MySQL.query.await(
        'SELECT id, amount, reason FROM hbs_bills WHERE citizenid = ? AND paid = 0',
        { citizenid }
    ) or {}
end

function DB.MarkBillPaid(id)
    MySQL.query.await(
        'UPDATE hbs_bills SET paid = 1 WHERE id = ?',
        { id }
    )
end

-- ── Addiction ─────────────────────────────────────────────────────────────

function DB.LoadAddiction(citizenid)
    local rows = MySQL.query.await(
        'SELECT substance, level, last_use FROM hbs_addiction WHERE citizenid = ?',
        { citizenid }
    )
    local t = {}
    for _, r in ipairs(rows or {}) do
        t[r.substance] = { level = r.level, lastUse = r.last_use }
    end
    return t
end

function DB.SaveAddiction(citizenid, substance, level, lastUse)
    MySQL.query.await([[
        INSERT INTO hbs_addiction (citizenid, substance, level, last_use, total_uses)
        VALUES (?, ?, ?, ?, 1)
        ON DUPLICATE KEY UPDATE
            level = ?,
            last_use = ?,
            total_uses = total_uses + 1
    ]], { citizenid, substance, level, lastUse, level, lastUse })
end

function DB.UpdateAddictionLevel(citizenid, substance, level)
    MySQL.query.await(
        'UPDATE hbs_addiction SET level = ? WHERE citizenid = ? AND substance = ?',
        { level, citizenid, substance }
    )
end
