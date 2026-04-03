return {
    doctorCallCooldown = 1, -- Time in minutes for cooldown between doctors calls
    wipeInvOnRespawn = false, -- Set true to wipe player inventory on hospital respawn
    depositSociety = function(society, amount)
        -- Adjust this to your banking resource.
        -- Renewed-Banking:
        local ok = pcall(function()
            exports['Renewed-Banking']:addAccountMoney(society, amount)
        end)
        -- Fallback: ox_banking / qbx_core bank (uncomment if not using Renewed-Banking)
        -- if not ok then
        --     exports['ox_banking']:addAccountBalance(society, amount)
        -- end
    end,

    -- ── Drug script compatibility ─────────────────────────────────────────────
    -- We don't manage drug USE — your existing drug script handles that.
    -- We only hook in to apply addiction + withdrawal effects on top.
    --
    -- Set the event your drug script fires when a player successfully uses a drug.
    -- The event must pass: source (net source), itemName (string matching HBSConfig.Drugs key)
    --
    -- Examples:
    --   md-drugs typically fires: 'md-drugs:server:drugConsumed'
    --   with args: (source, drugName)
    --
    -- Set to nil to disable (use our own HBSConfig.Drugs item system instead)
    drugConsumedEvent = 'md-drugs:server:drugConsumed',

    -- Map md-drugs item names → HBSConfig.Drugs keys if they differ
    -- e.g. md-drugs calls it 'coke' but our config key is 'cocaine'
    drugNameMap = {
        ['coke']   = 'cocaine',
        ['crack']  = 'cocaine',
        ['meth']   = 'meth',
        ['heroin'] = 'heroin',
        ['weed']   = 'weed',
        ['xtc']    = 'ecstasy',
        ['mdma']   = 'ecstasy',
    },
}