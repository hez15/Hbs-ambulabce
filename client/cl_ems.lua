-- EMS job actions: revive, treat, carry/drag, downed blips, dispatch display
-- Integrates with cl_ems_research.lua for tier-gated controls

local carriedPed    = nil
local carriedSrc    = nil
local carryActive   = false
local downedBlips   = {}   -- { [serverId] = blipHandle }

-- Carry timer for XP (30s carry = XP award)
local carryStartTime = nil

-- ── Job check ─────────────────────────────────────────────────────────────

local function IsEMS()
    local pd = exports.qbx_core:GetPlayerData()
    return pd and pd.job and pd.job.name == Config.EmsJob
end

-- ── Tier label for TextUI ─────────────────────────────────────────────────

local function GetTierLabel()
    local tier = (EMSResearch and EMSResearch.tier) or 1
    for _, t in ipairs(Config.EMSResearch.tiers) do
        if t.tier == tier then return '[' .. t.label .. '] ' end
    end
    return '[EMT] '
end

-- ── Unlock check (delegates to cl_ems_research) ────────────────────────

local function HasUnlock(ability)
    if not EMSResearch then return false end
    return Utils.TableContains(EMSResearch.unlocks, ability)
        or (EMSResearch.mentorTier and (Config.EMSResearch.abilities[ability] or {}).tier or 99) <= (EMSResearch.mentorTier or 0)
end

-- ── Find nearest downed player ─────────────────────────────────────────────

local function GetNearestDowned(maxDist)
    maxDist = maxDist or 3.0
    local myCoords  = GetEntityCoords(PlayerPedId())
    local bestSrc, bestPed, bestDist = nil, nil, maxDist

    for _, pid in ipairs(GetActivePlayers()) do
        if pid ~= PlayerId() then
            local srv  = GetPlayerServerId(pid)
            local ped  = GetPlayerPed(pid)
            local down = GetStateBagValue('player:' .. srv, SB.Keys.isDowned)
            if down then
                local d = #(GetEntityCoords(ped) - myCoords)
                if d < bestDist then
                    bestDist = d
                    bestSrc  = srv
                    bestPed  = ped
                end
            end
        end
    end
    return bestSrc, bestPed
end

-- ── Revive ────────────────────────────────────────────────────────────────

local function Revive(targetSrc, targetPed)
    -- Hands-only revive path (Tier 5, no item needed)
    if HasUnlock('hands_only_revive') and
       (not Config.ReviveRequiresItem or exports.ox_inventory:Search('count', Config.ReviveItem) < 1)
    then
        HandsOnlyRevive(targetSrc)
        return
    end

    -- Standard defib revive
    if Config.ReviveRequiresItem then
        if exports.ox_inventory:Search('count', Config.ReviveItem) < 1 then
            Notify(Locale('revive_no_item'), 'error')
            return
        end
    end

    RequestAnimDict('mini@repair')
    while not HasAnimDictLoaded('mini@repair') do Wait(10) end

    -- rapid_revive reduces time by 30%
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
            -- First responder XP check
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
    local boneIndex = GetPedBoneIndex(myPed, 57005)  -- right hand

    AttachEntityToEntity(
        targetPed, myPed, boneIndex,
        Config.CarryOffset.x, Config.CarryOffset.y, Config.CarryOffset.z,
        0.0, 0.0, 0.0,
        true, true, false, true, 1, true
    )

    -- advanced_carry: allow sprinting while carrying
    if HasUnlock('advanced_carry') then
        SetPlayerSprint(myPed, true)
    end

    TriggerServerEvent('hbs_ambulance:server:setCarried', targetSrc, true, GetPlayerServerId(PlayerId()))
    Notify(Locale('carry_start'), 'inform')
end

local function StopCarry()
    if not carryActive then return end
    if carriedPed then DetachEntity(carriedPed, true, true) end

    -- Award carry XP if carried for 30+ seconds
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

-- ── Build interaction hint based on tier/unlocks ──────────────────────────

local function BuildInteractHint(targetSrc)
    local hint  = GetTierLabel()
    hint = hint .. '[E] Revive  [G] Carry  [H] Treat'

    if HasUnlock('patient_examine') then
        hint = hint .. '  [J] Examine'
    end
    if HasUnlock('administer_meds') then
        hint = hint .. '  [K] Administer'
    end
    if HasUnlock('full_surgery') then
        hint = hint .. '  [F] Surgery'
    end
    return hint
end

-- ── Downed blips (EMS only) ────────────────────────────────────────────────

local function UpdateDownedBlips(list)
    for _, blip in pairs(downedBlips) do RemoveBlip(blip) end
    downedBlips = {}
    if not IsEMS() then return end

    for _, entry in ipairs(list) do
        local blip = AddBlipForCoord(entry.x, entry.y, entry.z)
        SetBlipSprite(blip, Config.DownedBlipSprite)
        SetBlipColour(blip, Config.DownedBlipColor)
        SetBlipScale(blip, 0.85)
        SetBlipAsShortRange(blip, false)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName('Downed Player')
        EndTextCommandSetBlipName(blip)
        downedBlips[entry.src] = blip
    end
end

-- ── Interaction loop ──────────────────────────────────────────────────────

CreateThread(function()
    while true do
        Wait(0)
        if not IsPlayerLoaded() or not IsEMS() then
            Wait(2000)
            goto continue
        end

        local targetSrc, targetPed = GetNearestDowned(3.0)

        if targetSrc then
            lib.showTextUI(BuildInteractHint(targetSrc), { position = 'top-center' })

            if IsControlJustPressed(0, 38) then         -- E → Revive
                lib.hideTextUI()
                Revive(targetSrc, targetPed)

            elseif IsControlJustPressed(0, 47) then     -- G → Carry
                lib.hideTextUI()
                if carryActive then StopCarry() else StartCarry(targetSrc, targetPed) end

            elseif IsControlJustPressed(0, 74) then     -- H → Treat
                lib.hideTextUI()
                TreatWounds(targetSrc)

            elseif IsControlJustPressed(0, 311) then    -- J → Examine (Tier 2)
                lib.hideTextUI()
                if ExaminePatient then ExaminePatient(targetSrc, targetPed) end

            elseif IsControlJustPressed(0, 305) then    -- K → Administer (Tier 3)
                lib.hideTextUI()
                if AdministerMeds then AdministerMeds(targetSrc) end

            elseif IsControlJustPressed(0, 36) then     -- F → Surgery (Tier 4)
                lib.hideTextUI()
                if FullSurgery then FullSurgery(targetSrc) end
            end

        else
            if carryActive then
                lib.showTextUI('[G] Put Down Patient', { position = 'top-center' })
                if IsControlJustPressed(0, 47) then
                    lib.hideTextUI()
                    StopCarry()
                end
            else
                lib.hideTextUI()
            end
        end
        ::continue::
    end
end)

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
