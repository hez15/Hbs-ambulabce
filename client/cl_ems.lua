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
    if HasUnlock('hands_only_revive') and
       (not Config.ReviveRequiresItem or exports.ox_inventory:Search('count', Config.ReviveItem) < 1)
    then
        if HandsOnlyRevive then HandsOnlyRevive(targetSrc) end
        return
    end

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

-- ── ox_target: add / remove options on a downed ped ──────────────────────

local function AddDownedTargets(ped, serverId)
    exports.ox_target:addEntity(ped, {
        {
            label       = 'Revive Patient',
            icon        = 'fas fa-heartbeat',
            distance    = 3.0,
            canInteract = function() return IsEMS() end,
            onSelect    = function() Revive(serverId, ped) end,
        },
        {
            label       = 'Carry Patient',
            icon        = 'fas fa-hands-holding',
            distance    = 3.0,
            canInteract = function() return IsEMS() and not carryActive end,
            onSelect    = function() StartCarry(serverId, ped) end,
        },
        {
            label       = 'Treat Wounds',
            icon        = 'fas fa-band-aid',
            distance    = 3.0,
            canInteract = function() return IsEMS() end,
            onSelect    = function() TreatWounds(serverId) end,
        },
        {
            label       = 'Triage Patient',
            icon        = 'fas fa-triangle-exclamation',
            distance    = 3.0,
            canInteract = function() return IsEMS() end,
            onSelect    = function()
                lib.registerContext({
                    id      = 'hbs_triage_' .. serverId,
                    title   = 'Triage Patient',
                    options = {
                        {
                            title       = '🔴 Critical',
                            description = 'Immediately life-threatening',
                            onSelect    = function()
                                TriggerServerEvent('hbs_ambulance:server:triagePatient', serverId, 'critical')
                            end,
                        },
                        {
                            title       = '🟠 Moderate',
                            description = 'Serious but stable',
                            onSelect    = function()
                                TriggerServerEvent('hbs_ambulance:server:triagePatient', serverId, 'moderate')
                            end,
                        },
                        {
                            title       = '🟡 Minor',
                            description = 'Walking wounded / low priority',
                            onSelect    = function()
                                TriggerServerEvent('hbs_ambulance:server:triagePatient', serverId, 'minor')
                            end,
                        },
                    },
                })
                lib.showContext('hbs_triage_' .. serverId)
            end,
        },
        {
            label       = 'Examine Patient',
            icon        = 'fas fa-stethoscope',
            distance    = 3.0,
            canInteract = function() return IsEMS() and HasUnlock('patient_examine') end,
            onSelect    = function()
                if ExaminePatient then ExaminePatient(serverId, ped) end
            end,
        },
        {
            label       = 'Administer Medication',
            icon        = 'fas fa-syringe',
            distance    = 3.0,
            canInteract = function() return IsEMS() and HasUnlock('administer_meds') end,
            onSelect    = function()
                if AdministerMeds then AdministerMeds(serverId) end
            end,
        },
        {
            label       = 'Full Surgery',
            icon        = 'fas fa-user-md',
            distance    = 3.0,
            canInteract = function() return IsEMS() and HasUnlock('full_surgery') end,
            onSelect    = function()
                if FullSurgery then FullSurgery(serverId) end
            end,
        },
    })
end

local function RemoveDownedTargets(ped)
    exports.ox_target:removeEntity(ped, {
        'Revive Patient', 'Carry Patient', 'Treat Wounds', 'Triage Patient',
        'Examine Patient', 'Administer Medication', 'Full Surgery',
    })
end

-- ── Track downed state changes via state bags ─────────────────────────────

AddStateBagChangeHandler(SB.Keys.isDowned, nil, function(bagName, _, value)
    local serverId = tonumber(bagName:match('player:(%d+)'))
    if not serverId then return end
    local localId = GetPlayerFromServerId(serverId)
    if localId < 0 or localId == PlayerId() then return end
    local ped = GetPlayerPed(localId)
    if not DoesEntityExist(ped) then return end

    if value then
        AddDownedTargets(ped, serverId)
    else
        RemoveDownedTargets(ped)
    end
end)

-- Scan already-downed players when EMS loads in
AddEventHandler('hbs_ambulance:client:stateLoaded', function()
    if not IsEMS() then return end
    Wait(500)  -- let state bags settle
    for _, pid in ipairs(GetActivePlayers()) do
        if pid ~= PlayerId() then
            local srv = GetPlayerServerId(pid)
            if GetStateBagValue('player:' .. srv, SB.Keys.isDowned) then
                local ped = GetPlayerPed(pid)
                if DoesEntityExist(ped) then
                    AddDownedTargets(ped, srv)
                end
            end
        end
    end
end)

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
