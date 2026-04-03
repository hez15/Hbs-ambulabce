return {
    doctorCallCooldown = 1, -- Time in minutes for cooldown between doctors calls
    wipeInvOnRespawn = true, -- Enable to disable removing all items from player on respawn
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
    end
}