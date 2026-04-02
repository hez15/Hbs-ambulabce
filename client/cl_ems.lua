-- EMS job actions: revive, treat, carry/drag, downed blips, dispatch display

local carriedPed    = nil
local carriedSrc    = nil
local carryActive   = false
local downedBlips   = {}   -- { [serverId] = blipHandle }

-- ── Job check ─────────────────────────────────────────────────────────────

local function IsEMS()
    local pd = exports.qbx_core:GetPlayerData()
    return pd and pd.job and pd.job.name == Config.EmsJob
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
    -- Item check (defib)
    if Config.ReviveRequiresItem then
        if exports.ox_inventory:Search('count', Config.ReviveItem) < 1 then
            Notify(Locale('revive_no_item'), 'error')
            return
        end
    end

    RequestAnimDict('mini@repair')
    while not HasAnimDictLoaded('mini@repair') do Wait(10) end

    lib.progressBar({
        duration     = Config.ReviveTime * 1000,
        label        = Locale('revive_progress'),
        useWhileDead = false,
        canCancel    = true,
        anim         = { dict = 'mini@repair', clip = 'fixing_a_ped', flag = 16 },
    }, function(completed)
        if completed then
            TriggerServerEvent('hbs_ambulance:server:revivePlayer', targetSrc)
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
    carryActive = true
    carriedPed  = targetPed
    carriedSrc  = targetSrc

    local myPed     = PlayerPedId()
    local boneIndex = GetPedBoneIndex(myPed, 57005)  -- right hand

    AttachEntityToEntity(
        targetPed, myPed, boneIndex,
        Config.CarryOffset.x, Config.CarryOffset.y, Config.CarryOffset.z,
        0.0, 0.0, 0.0,
        true, true, false, true, 1, true
    )
    TriggerServerEvent('hbs_ambulance:server:setCarried', targetSrc, true, GetPlayerServerId(PlayerId()))
    Notify(Locale('carry_start'), 'inform')
end

local function StopCarry()
    if not carryActive then return end
    if carriedPed then DetachEntity(carriedPed, true, true) end
    TriggerServerEvent('hbs_ambulance:server:setCarried', carriedSrc, false, nil)
    carryActive = false
    carriedPed  = nil
    carriedSrc  = nil
    Notify(Locale('carry_stop'), 'inform')
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
            lib.showTextUI(Locale('ems_interact_hint'), { position = 'top-center' })

            if IsControlJustPressed(0, 38) then         -- E → Revive
                lib.hideTextUI()
                Revive(targetSrc, targetPed)
            elseif IsControlJustPressed(0, 47) then     -- G → Carry
                lib.hideTextUI()
                if carryActive then StopCarry() else StartCarry(targetSrc, targetPed) end
            elseif IsControlJustPressed(0, 74) then     -- H → Treat
                lib.hideTextUI()
                TreatWounds(targetSrc)
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
            title    = Locale('ems_dispatch_title'),
            description = msg,
            type     = 'error',
            duration = 12000,
        })
    end
end)
