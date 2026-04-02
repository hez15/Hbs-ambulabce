-- EMS server: revive, treat, carry state, patient transport
-- Integrates with sv_ems_research.lua for XP awards and unlock-gated effects

-- ── Helper: check if EMS has a specific unlock (or mentor boost) ──────────

local function HasUnlock(src, ability)
    local unlocks    = SB.Get(src, 'emsUnlocks') or {}
    local mentorTier = SB.Get(src, 'mentorTier')
    if Utils.TableContains(unlocks, ability) then return true end
    if mentorTier then
        local abCfg = Config.EMSResearch.abilities[ability]
        if abCfg and abCfg.tier <= mentorTier then return true end
    end
    return false
end

-- ── Revive by EMS ─────────────────────────────────────────────────────────

RegisterNetEvent('hbs_ambulance:server:revivePlayer', function(targetSrc)
    local src = source
    if not Utils.IsEMS(src) then return end

    -- Delegate to shared revive logic in sv_ems_research
    TriggerEvent('hbs_ambulance:server:performRevive', src, targetSrc, true)

    -- Award XP
    TriggerEvent('hbs_ambulance:server:awardEMSXP', src, Config.EMSResearch.xpRewards.revive)

    Utils.Debug('EMS', src, 'revived player', targetSrc)
end)

-- ── Treat wounds (EMS) ────────────────────────────────────────────────────

RegisterNetEvent('hbs_ambulance:server:treatPlayer', function(targetSrc)
    local src = source
    if not Utils.IsEMS(src) then return end

    local targetCid = Utils.GetCitizenId(targetSrc)
    if not targetCid then return end

    local injuries    = DB.LoadInjuries(targetCid)
    local traumaSplint= HasUnlock(src, 'trauma_splint')

    -- With trauma_splint: treat fractures too; without: only scratch/minor
    for part, sev in pairs(injuries) do
        local shouldHeal = sev == 'scratch' or sev == 'minor'
        if traumaSplint and sev == 'fracture' then shouldHeal = true end
        if shouldHeal then
            DB.SaveInjury(targetCid, part, nil)
        end
    end

    -- IV Therapy unlock: restore 75 HP to target
    if HasUnlock(src, 'iv_therapy') then
        local ped = GetPlayerPed(targetSrc)
        SetEntityHealth(ped, math.min(200, GetEntityHealth(ped) + 75))
    end

    local updated = DB.LoadInjuries(targetCid)
    SB.Set(targetSrc, 'injuries', updated)
    TriggerClientEvent('hbs_ambulance:client:applyInjuryEffects', targetSrc)

    -- Award XP
    TriggerEvent('hbs_ambulance:server:awardEMSXP', src, Config.EMSResearch.xpRewards.treat)
end)

-- ── Carry state ───────────────────────────────────────────────────────────

RegisterNetEvent('hbs_ambulance:server:setCarried', function(targetSrc, isCarried, carrierSrc)
    SB.Set(targetSrc, 'isCarried',  isCarried)
    SB.Set(targetSrc, 'carrierSrc', carrierSrc)
end)

-- ── Ambulance patient load/unload ─────────────────────────────────────────

RegisterNetEvent('hbs_ambulance:server:loadPatient', function(targetSrc, plate)
    SB.Set(targetSrc, 'isCarried', true)
    Utils.Debug('Patient', targetSrc, 'loaded into', plate)
end)

RegisterNetEvent('hbs_ambulance:server:unloadPatient', function(targetSrc)
    SB.Set(targetSrc, 'isCarried', false)
    TriggerClientEvent('hbs_ambulance:client:patientUnloaded', source)
    -- Award transport XP to the unloading EMS
    TriggerEvent('hbs_ambulance:server:awardEMSXP', source, Config.EMSResearch.xpRewards.transport)
end)
