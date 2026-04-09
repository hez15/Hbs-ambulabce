-- HBS Addiction — central roll + persistence
-- RollAddiction is a global so sv_items.lua and sv_drugscompat.lua can call it.

-- ── Build item→substance lookup from HBSConfig.Substances ────────────────────

local _itemToSubstance = {}

CreateThread(function()
    -- Populate after config is loaded (substances may reference config at init)
    for substanceKey, cfg in pairs(HBSConfig.Substances or {}) do
        -- The substance key itself is also a valid alias
        _itemToSubstance[substanceKey] = substanceKey
        for _, alias in ipairs(cfg.itemAliases or {}) do
            _itemToSubstance[alias:lower()] = substanceKey
        end
    end
    HBSLog('addiction', ('item→substance map built: %d aliases'):format(
        (function() local n=0; for _ in pairs(_itemToSubstance) do n=n+1 end; return n end)()))
end)

-- ── Central addiction roll ────────────────────────────────────────────────────

-- substanceKey: key in HBSConfig.Substances (e.g. 'cocaine', 'morphine')
-- Can also pass an item name — will be resolved via _itemToSubstance map.
function RollAddiction(src, substanceKey)
    -- Resolve item aliases to substance key
    local resolved = _itemToSubstance[substanceKey] or _itemToSubstance[substanceKey:lower()]
    substanceKey = resolved or substanceKey

    local cfg = HBSConfig.Substances and HBSConfig.Substances[substanceKey]
    if not cfg then
        HBSLog('addiction', ('RollAddiction: unknown substance "%s"'):format(substanceKey))
        return
    end

    local cid = HBSUtils.GetCitizenId(src)
    if not cid then return end

    local addiction = DB.LoadAddiction(cid)
    local curLevel  = addiction[substanceKey] or 0
    local chance    = cfg.addictChance and cfg.addictChance[curLevel] or 0.10

    HBSLog('addiction', ('roll: cid=%s substance=%s curLevel=%d chance=%.2f'):format(
        cid, substanceKey, curLevel, chance))

    if math.random() < chance then
        local newLevel = math.min(4, curLevel + 1)
        DB.SaveAddiction(cid, substanceKey, newLevel)
        local updated = DB.LoadAddiction(cid)
        HBS.Set(src, 'addiction', updated)
        TriggerClientEvent('hbs_ambulance:client:addictionUpdate', src, updated)

        HBSLog('addiction', ('increased: cid=%s %s %d→%d'):format(cid, substanceKey, curLevel, newLevel))

        local label = HBSConfig.Addiction.levelLabels[newLevel] or 'Unknown'
        TriggerClientEvent('hbs_ambulance:client:notify', src, 'error',
            ('You feel a growing dependence. (%s: %s)'):format(cfg.label or substanceKey, label))
    else
        HBSLog('addiction', ('no increase: cid=%s %s (rolled above %.2f)'):format(cid, substanceKey, chance))
    end
end

-- ── Client save event (self-use items trigger client → server) ────────────────

RegisterNetEvent('hbs_ambulance:server:saveAddiction', function(substance, level)
    local src = source
    local cid = HBSUtils.GetCitizenId(src)
    if not cid then return end
    DB.SaveAddiction(cid, substance, level)
    HBS.Set(src, 'addiction', DB.LoadAddiction(cid))
end)

-- ── Export: external scripts call this directly ───────────────────────────────
-- Usage from another resource:
--   exports.hbs_ambulance:consumeSubstance(source, 'cocaine')
-- or with an item name:
--   exports.hbs_ambulance:consumeSubstance(source, 'coke_bag')

exports('consumeSubstance', function(src, substanceOrItem)
    if not src or not substanceOrItem then return end
    RollAddiction(src, substanceOrItem)
end)
