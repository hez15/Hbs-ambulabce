-- HBS Drug compatibility — hooks into your existing drug script.
-- We do NOT handle drug use/effects here; your drug script does that.
-- This file ONLY applies HBS addiction rolls + withdrawal on drug use.

local ServerConfig = lib.load('config/server')

-- ── Addiction roll helper (shared with sv_items) ──────────────────────────────

local function RollAddiction(src, drugKey)
    local cfg = HBSConfig.Drugs[drugKey]
    if not cfg or not cfg.addictive or not cfg.substance then return end

    local cid = HBSUtils.GetCitizenId(src)
    if not cid then return end

    local addiction = DB.LoadAddiction(cid)
    local curLevel  = addiction[cfg.substance] or 0
    local chance    = cfg.addictChance and cfg.addictChance[curLevel] or 0.10

    if math.random() < chance then
        local newLevel = math.min(4, curLevel + 1)
        DB.SaveAddiction(cid, cfg.substance, newLevel)
        local updated = DB.LoadAddiction(cid)
        HBS.Set(src, 'addiction', updated)
        TriggerClientEvent('hbs_ambulance:client:addictionUpdate', src, updated)

        -- Notify player if addiction increased
        if newLevel > curLevel then
            local label = HBSConfig.Addiction.levelLabels[newLevel] or 'Unknown'
            TriggerClientEvent('hbs_ambulance:client:notify', src, 'error',
                ('You feel a growing dependence. (%s: %s)'):format(cfg.substance, label))
        end
    end

    -- Also apply stress reduction client-side if defined
    if cfg.effects and cfg.effects.stressReduce then
        TriggerClientEvent('hbs_ambulance:client:addStress', src, -cfg.effects.stressReduce)
        local stress = DB.LoadStress(cid)
        DB.SaveStress(cid, math.max(0, stress - cfg.effects.stressReduce))
    end

    -- Tell client to start the high (visual effects, speed boost etc.)
    TriggerClientEvent('hbs_ambulance:client:drugEffect', src, drugKey)
end

-- ── Hook into drug script event ───────────────────────────────────────────────

local eventName = ServerConfig and ServerConfig.drugConsumedEvent
local nameMap   = (ServerConfig and ServerConfig.drugNameMap) or {}

if eventName then
    -- Listen for the drug script's consumed event
    -- Expected args: (source, itemName)
    AddEventHandler(eventName, function(src, itemName)
        if not src or not itemName then return end

        -- Resolve name through map first, then try direct match
        local drugKey = nameMap[itemName] or nameMap[itemName:lower()] or itemName:lower()

        if HBSConfig.Drugs[drugKey] then
            RollAddiction(src, drugKey)
        end
    end)

    HBSLog('drugscompat', ('listening on "%s"'):format(eventName))
else
    HBSLog('drugscompat', 'no drugConsumedEvent set — using HBS item system only.')
end
