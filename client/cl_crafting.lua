-- HBS Research Terminal — EMS tier/XP/ability viewer (NUI)

local function OpenResearchMenu()
    if not HBSIsEMS() then
        HBSNotify('error', 'EMS only.')
        return
    end

    local tier    = HBSState.emsTier or 1
    local xp      = HBSState.emsXP   or 0
    local tierCfg = HBSConfig.EMSResearch.tiers[tier]
    local nextCfg = HBSConfig.EMSResearch.tiers[tier + 1]

    -- Build sorted ability list for NUI
    local abilities = {}
    for abilityId, ab in pairs(HBSConfig.EMSResearch.abilities) do
        abilities[#abilities + 1] = {
            id           = abilityId,
            label        = ab.label,
            desc         = ab.desc or '',
            requiredTier = ab.tier,
            unlocked     = tier >= ab.tier,
        }
    end
    -- Unlocked first, then sorted by required tier
    table.sort(abilities, function(a, b)
        if a.unlocked ~= b.unlocked then return a.unlocked end
        return a.requiredTier < b.requiredTier
    end)

    SendNUIMessage({
        action     = 'showResearchTerminal',
        tier       = tier,
        xp         = xp,
        tierLabel  = tierCfg and tierCfg.label or 'EMT',
        nextTier   = nextCfg and nextCfg.tier or nil,
        nextXP     = nextCfg and nextCfg.xpRequired or nil,
        nextLabel  = nextCfg and nextCfg.label or nil,
        abilities  = abilities,
    })
    SetNuiFocus(true, true)

    HBSUtils.Debug('research', ('research terminal opened: tier=%d xp=%d'):format(tier, xp))
end

RegisterNuiCallback('closeResearchTerminal', function(_, cb)
    SetNuiFocus(false, false)
    HBSUtils.Debug('research', 'research terminal closed')
    cb('ok')
end)

CreateThread(function()
    Wait(5000)
    if not HBSConfig.ResearchTerminal then return end

    exports.ox_target:addSphereZone({
        coords  = HBSConfig.ResearchTerminal.coords,
        radius  = HBSConfig.ResearchTerminal.radius,
        options = {
            {
                name        = 'hbs_research_terminal',
                icon        = 'fa-solid fa-computer',
                label       = HBSConfig.ResearchTerminal.label,
                canInteract = function() return HBSIsEMS() end,
                onSelect    = function()
                    OpenResearchMenu()
                end,
            },
        },
    })
end)

-- Note: emsResearchUpdate is handled in cl_ems.lua which syncs all HBSState fields.
