-- EMS job actions: revive, treat, carry/drag, downed blips, dispatch display
-- Uses ox_target on downed player peds for all interactions

local carryActive    = false
local carriedPed     = nil
local carriedSrc     = nil
local carryStartTime = nil
local downedBlips    = {}   -- { [serverId] = blipHandle }

-- ── Job / unlock helpers ───────────────────────────────────────────────────

local function IsEMS()
    local pd = exports.qbx_core:GetPlayerData()
    return pd and pd.job and pd.job.name == Config.EmsJob
end

local function HasUnlock(ability)
    if not EMSResearch then return false end
    if Utils.TableContains(EMSResearch.unlocks, ability) then return true end
    local abCfg = Config.EMSResearch.abilities[ability]
    return abCfg and (EMSResearch.mentorTier or 0) >= abCfg.tier
end

-- ── Revive ────────────────────────────────────────────────────────────────

local function Revive(targetSrc, targetPed)
    -- Hands-only revive unlock: skip item check, trigger dedicated server event
    if HasUnlock('hands_only_revive') then
        RequestAnimDict('mini@repair')
        while not HasAnimDictLoaded('mini@repair') do Wait(10) end
        local reviveTime = GetReviveTime and GetReviveTime() or Config.ReviveTime
        lib.progressBar({
            duration     = reviveTime * 1000,
            label        = Locale('revive_progress'),
            useWhileDead = false,
            canCancel    = true,
            anim         = { dict = 'mini@repair', clip = 'fixing_a_ped', flag = 16 },
        }, function(completed)
            if completed then
                TriggerServerEvent('hbs_ambulance:server:handsOnlyRevive', targetSrc)
                if CheckFirstResponder then CheckFirstResponder(targetSrc) end
            end
        end)
        return
    end

    -- Standard revive: optionally require defibrillator item
    if Config.ReviveRequiresItem then
        if exports.ox_inventory:Search('count', Config.ReviveItem) < 1 then
            Notify(Locale('revive_no_item'), 'error')
            return
        end
    end

    RequestAnimDict('mini@repair')
    while not HasAnimDictLoaded('mini@repair') do Wait(10) end

    local reviveTime = GetReviveTime and GetReviveTime() or Config.ReviveTime

    lib.progressBar({
        duration     = reviveTime * 1000,
        label        = Locale('revive_progress'),
        useWhileDead = false,
        canCancel    = true,
        anim         = { dict = 'mini@repair', clip = 'fixing_a_ped', flag = 16 },
    }, function(completed)
        if completed then
            TriggerServerEvent('hbs_ambulance:server:revivePlayer', targetSrc)
            if CheckFirstResponder then CheckFirstResponder(targetSrc) end
        end
    end)
end

-- ── Treat wounds ──────────────────────────────────────────────────────────

local function TreatWounds(targetSrc)
    RequestAnimDict('mini@repair')
    while not HasAnimDictLoaded('mini@repair') do Wait(10) end

    lib.progressBar({
        duration     = Config.TreatTime * 1000,
        label        = Locale('treat_progress'),
        useWhileDead = false,
        canCancel    = true,
        anim         = { dict = 'mini@repair', clip = 'fixing_a_ped', flag = 16 },
    }, function(completed)
        if completed then
            TriggerServerEvent('hbs_ambulance:server:treatPlayer', targetSrc)
            Notify(Locale('treat_success'), 'success')
        end
    end)
end

-- ── Carry / drag ──────────────────────────────────────────────────────────

local function StartCarry(targetSrc, targetPed)
    if carryActive then return end
    carryActive    = true
    carriedPed     = targetPed
    carriedSrc     = targetSrc
    carryStartTime = GetGameTimer()

    local myPed     = PlayerPedId()
    local boneIndex = GetPedBoneIndex(myPed, 57005)

    AttachEntityToEntity(
        targetPed, myPed, boneIndex,
        Config.CarryOffset.x, Config.CarryOffset.y, Config.CarryOffset.z,
        0.0, 0.0, 0.0, true, true, false, true, 1, true
    )

    if HasUnlock('advanced_carry') then
        SetPlayerSprint(myPed, true)
    end

    TriggerServerEvent('hbs_ambulance:server:setCarried', targetSrc, true, GetPlayerServerId(PlayerId()))
    Notify(Locale('carry_start'), 'inform')
end

local function StopCarry()
    if not carryActive then return end
    if carriedPed then DetachEntity(carriedPed, true, true) end

    if carryStartTime and (GetGameTimer() - carryStartTime) >= 30000 then
        TriggerServerEvent('hbs_ambulance:server:awardEMSXP',
            Config.EMSResearch.xpRewards and Config.EMSResearch.xpRewards.treat or 20)
    end

    TriggerServerEvent('hbs_ambulance:server:setCarried', carriedSrc, false, nil)
    carryActive    = false
    carriedPed     = nil
    carriedSrc     = nil
    carryStartTime = nil
    Notify(Locale('carry_stop'), 'inform')
end

-- ── Helpers ───────────────────────────────────────────────────────────────

local function PedToServerId(ped)
    for _, pid in ipairs(GetActivePlayers()) do
        if GetPlayerPed(pid) == ped then
            return GetPlayerServerId(pid)
        end
    end
    return nil
end

local function PedIsDowned(ped)
    local srv = PedToServerId(ped)
    if not srv then return false end
    return GetStateBagValue('player:' .. srv, SB.Keys.isDowned) == true
end

-- ── ox_target: global player targets for EMS ─────────────────────────────
-- These show on ANY player ped; canInteract gates visibility per option.

exports.ox_target:addGlobalPlayer({
    {
        label       = 'Revive Patient',
        icon        = 'fas fa-heartbeat',
        distance    = 3.0,
        canInteract = function(entity) return IsEMS() and PedIsDowned(entity) end,
        onSelect    = function(data)
            local srv = PedToServerId(data.entity)
            if srv then Revive(srv, data.entity) end
        end,
    },
    {
        label       = 'Carry Patient',
        icon        = 'fas fa-hands-holding',
        distance    = 3.0,
        canInteract = function(entity) return IsEMS() and PedIsDowned(entity) and not carryActive end,
        onSelect    = function(data)
            local srv = PedToServerId(data.entity)
            if srv then StartCarry(srv, data.entity) end
        end,
    },
    {
        label       = 'Treat Wounds',
        icon        = 'fas fa-band-aid',
        distance    = 3.0,
        canInteract = function(entity)
            if not IsEMS() then return false end
            local srv = PedToServerId(entity)
            if not srv then return false end
            -- Only show when the target actually has injuries
            local injuries = GetStateBagValue('player:' .. srv, SB.Keys.injuries) or {}
            return next(injuries) ~= nil
        end,
        onSelect    = function(data)
            local srv = PedToServerId(data.entity)
            if srv then TreatWounds(srv) end
        end,
    },
    {
        label       = 'Triage Patient',
        icon        = 'fas fa-triangle-exclamation',
        distance    = 3.0,
        canInteract = function(entity) return IsEMS() and PedIsDowned(entity) end,
        onSelect    = function(data)
            local srv = PedToServerId(data.entity)
            if not srv then return end
            lib.registerContext({
                id      = 'hbs_triage_' .. srv,
                title   = 'Triage Patient',
                options = {
                    {
                        title       = '🔴 Critical',
                        description = 'Immediately life-threatening',
                        onSelect    = function()
                            TriggerServerEvent('hbs_ambulance:server:triagePatient', srv, 'critical')
                        end,
                    },
                    {
                        title       = '🟠 Moderate',
                        description = 'Serious but stable',
                        onSelect    = function()
                            TriggerServerEvent('hbs_ambulance:server:triagePatient', srv, 'moderate')
                        end,
                    },
                    {
                        title       = '🟡 Minor',
                        description = 'Walking wounded / low priority',
                        onSelect    = function()
                            TriggerServerEvent('hbs_ambulance:server:triagePatient', srv, 'minor')
                        end,
                    },
                },
            })
            lib.showContext('hbs_triage_' .. srv)
        end,
    },
    {
        label       = 'Examine Patient',
        icon        = 'fas fa-stethoscope',
        distance    = 3.0,
        canInteract = function() return IsEMS() and HasUnlock('patient_examine') end,
        onSelect    = function(data)
            local srv = PedToServerId(data.entity)
            if srv and ExaminePatient then ExaminePatient(srv, data.entity) end
        end,
    },
    {
        label       = 'Administer Medication',
        icon        = 'fas fa-syringe',
        distance    = 3.0,
        canInteract = function() return IsEMS() and HasUnlock('administer_meds') end,
        onSelect    = function(data)
            local srv = PedToServerId(data.entity)
            if srv and AdministerMeds then AdministerMeds(srv) end
        end,
    },
    {
        label       = 'Full Surgery',
        icon        = 'fas fa-user-md',
        distance    = 3.0,
        canInteract = function(entity) return IsEMS() and PedIsDowned(entity) and HasUnlock('full_surgery') end,
        onSelect    = function(data)
            local srv = PedToServerId(data.entity)
            if srv and FullSurgery then FullSurgery(srv) end
        end,
    },
})

-- ── Carry stop — persistent textUI while carrying ─────────────────────────

CreateThread(function()
    while true do
        if carryActive then
            lib.showTextUI('[G] Put Down Patient', { position = 'top-center' })
            if IsControlJustPressed(0, 47) then   -- G
                lib.hideTextUI()
                StopCarry()
            end
            Wait(0)
        else
            lib.hideTextUI()
            Wait(500)
        end
    end
end)

-- ── Downed blips (EMS only) ────────────────────────────────────────────────

local function UpdateDownedBlips(list)
    for _, blip in pairs(downedBlips) do RemoveBlip(blip) end
    downedBlips = {}
    if not IsEMS() then return end

    for _, entry in ipairs(list) do
        local blip   = AddBlipForCoord(entry.x, entry.y, entry.z)
        local colour = (entry.triage and Config.TriageColours[entry.triage])
                       or Config.DownedBlipColor

        SetBlipSprite(blip, Config.DownedBlipSprite)
        SetBlipColour(blip, colour)
        SetBlipScale(blip, 0.85)
        SetBlipAsShortRange(blip, false)

        local triageLabel = entry.triage and (' [' .. entry.triage:sub(1,1):upper() .. entry.triage:sub(2) .. ']') or ''
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName('Downed Player' .. triageLabel)
        EndTextCommandSetBlipName(blip)

        downedBlips[entry.src] = blip
    end
end

-- ── Net events ────────────────────────────────────────────────────────────

RegisterNetEvent('hbs_ambulance:client:updateDownedBlips', function(list)
    UpdateDownedBlips(list)
end)

RegisterNetEvent('hbs_ambulance:client:emsDispatch', function(msg)
    if IsEMS() then
        lib.notify({
            title       = Locale('ems_dispatch_title'),
            description = msg,
            type        = 'error',
            duration    = 12000,
        })
    end
end)
