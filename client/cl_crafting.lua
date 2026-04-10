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
    table.sort(abilities, function(a, b)
        if a.unlocked ~= b.unlocked then return a.unlocked end
        return a.requiredTier < b.requiredTier
    end)

    -- Fetch live research progress + outbreak counts from server
    local serverData = lib.callback.await('hbs_ambulance:server:getResearchData', false) or {}
    local research   = serverData.research  or {}
    local outbreaks  = serverData.outbreaks or {}

    -- Build disease list for NUI
    local diseases = {}
    for diseaseId, cfg in pairs(HBSConfig.Diseases or {}) do
        local debuffs = {}
        if cfg.symptoms then
            local seen = {}
            for s = 1, cfg.stages or 3 do
                local sym = cfg.symptoms[s]
                if sym then
                    if sym.speedMult and sym.speedMult < 1.0 and not seen.speed then
                        seen.speed = true
                        debuffs[#debuffs + 1] = ('Speed -%d%%'):format(math.floor((1.0 - sym.speedMult) * 100))
                    end
                    if sym.cough       and not seen.cough  then seen.cough  = true; debuffs[#debuffs + 1] = 'Coughing'     end
                    if sym.screenShake and not seen.shake  then seen.shake  = true; debuffs[#debuffs + 1] = 'Screen Shake' end
                    if sym.fever       and not seen.fever  then seen.fever  = true; debuffs[#debuffs + 1] = 'Fever'        end
                end
            end
        end
        diseases[#diseases + 1] = {
            id             = diseaseId,
            label          = cfg.label or diseaseId,
            stages         = cfg.stages or 3,
            spreads        = (cfg.spreadRadius or 0) > 0,
            treatItem      = cfg.treatItem or 'antibiotic',
            sampleItem     = cfg.sampleItem or 'disease_sample',
            researchTarget = cfg.researchTarget or 5,
            researched     = research[diseaseId]  or 0,
            outbreak       = outbreaks[diseaseId] or 0,
            debuffs        = debuffs,
        }
    end
    table.sort(diseases, function(a, b) return a.label < b.label end)

    SendNUIMessage({
        action     = 'showResearchTerminal',
        tier       = tier,
        xp         = xp,
        tierLabel  = tierCfg and tierCfg.label or 'EMT',
        nextTier   = nextCfg and nextCfg.tier or nil,
        nextXP     = nextCfg and nextCfg.xpRequired or nil,
        nextLabel  = nextCfg and nextCfg.label or nil,
        abilities  = abilities,
        diseases   = diseases,
    })
    SetNuiFocus(true, true)

    HBSUtils.Debug('research', ('research terminal opened: tier=%d xp=%d'):format(tier, xp))
end

RegisterNuiCallback('closeResearchTerminal', function(_, cb)
    SetNuiFocus(false, false)
    HBSUtils.Debug('research', 'research terminal closed')
    cb('ok')
end)

-- Sent when EMS clicks "Analyze Sample" on the disease tab
RegisterNuiCallback('analyzeSample', function(data, cb)
    TriggerServerEvent('hbs_ambulance:server:analyzeSample', data.disease)
    cb('ok')
end)

-- Server broadcasts updated research data after a sample is analyzed
RegisterNetEvent('hbs_ambulance:client:researchUpdate', function(research)
    -- Forward to NUI so the open terminal refreshes its progress bars
    SendNUIMessage({ action = 'updateResearch', research = research })
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
