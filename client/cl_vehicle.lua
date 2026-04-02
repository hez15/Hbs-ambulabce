-- Vehicle interactions: stretcher loading/unloading via ox_target, ambulance door lock

local loadedPatient   = nil   -- server src of loaded patient
local ambulanceLocked = false

-- ── Helpers ───────────────────────────────────────────────────────────────

local function GetCurrentVehicle()
    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped, false) then return nil end
    return GetVehiclePedIsIn(ped, false)
end

local function IsAmbulanceModel(veh)
    local model = GetEntityModel(veh)
    for _, m in ipairs(Config.AmbulanceModels) do
        if model == GetHashKey(m) then return true end
    end
    return false
end

local function InAmbulance()
    local veh = GetCurrentVehicle()
    if not veh then return false end
    if not IsAmbulanceModel(veh) then return false end
    return GetPedInVehicleSeat(veh, -1) == PlayerPedId()
end

-- ── Load patient into ambulance ───────────────────────────────────────────

local function LoadPatient(targetSrc, targetPed)
    local veh = GetCurrentVehicle()
    if not veh then return end

    lib.progressBar({
        duration     = Config.StretcherLoadTime * 1000,
        label        = 'Loading patient...',
        useWhileDead = false,
        canCancel    = true,
    }, function(done)
        if not done then return end
        SetPedIntoVehicle(targetPed, veh, 1)
        loadedPatient = targetSrc

        if Config.AmbulanceLockOnLoad then
            SetVehicleDoorsLocked(veh, 3)
            ambulanceLocked = true
        end

        TriggerServerEvent('hbs_ambulance:server:loadPatient', targetSrc,
            GetVehicleNumberPlateText(veh))
        Notify(Locale('stretcher_loaded'), 'success')
    end)
end

-- ── Unload patient ────────────────────────────────────────────────────────

local function UnloadPatient()
    if not loadedPatient then
        Notify(Locale('ambulance_no_patient'), 'error')
        return
    end
    local veh = GetCurrentVehicle()
    TriggerServerEvent('hbs_ambulance:server:unloadPatient', loadedPatient)
    loadedPatient = nil

    if ambulanceLocked and veh then
        SetVehicleDoorsLocked(veh, 1)
        ambulanceLocked = false
    end
    Notify(Locale('stretcher_unloaded'), 'success')
end

-- ── ox_target: add / remove stretcher-load option on downed peds ─────────

local function AddStretcherTarget(ped, serverId)
    exports.ox_target:addEntity(ped, {
        {
            label       = 'Load into Ambulance',
            icon        = 'fas fa-ambulance',
            distance    = Config.MaxStretcherDist,
            canInteract = function() return InAmbulance() and not loadedPatient end,
            onSelect    = function() LoadPatient(serverId, ped) end,
        },
    })
end

local function RemoveStretcherTarget(ped)
    exports.ox_target:removeEntity(ped, { 'Load into Ambulance' })
end

-- ── Track downed state changes ────────────────────────────────────────────

AddStateBagChangeHandler(SB.Keys.isDowned, nil, function(bagName, _, value)
    local serverId = tonumber(bagName:match('player:(%d+)'))
    if not serverId then return end
    local localId = GetPlayerFromServerId(serverId)
    if localId < 0 or localId == PlayerId() then return end
    local ped = GetPlayerPed(localId)
    if not DoesEntityExist(ped) then return end

    if value then
        AddStretcherTarget(ped, serverId)
    else
        RemoveStretcherTarget(ped)
    end
end)

-- ── Unload via textUI while patient is loaded (driver-side action) ────────

CreateThread(function()
    while true do
        if loadedPatient and InAmbulance() then
            lib.showTextUI(Locale('stretcher_unload_hint'), { position = 'top-center' })
            if IsControlJustPressed(0, 38) then   -- E
                lib.hideTextUI()
                UnloadPatient()
            end
            Wait(0)
        else
            lib.hideTextUI()
            Wait(500)
        end
    end
end)

-- ── Net events ────────────────────────────────────────────────────────────

RegisterNetEvent('hbs_ambulance:client:patientUnloaded', function()
    loadedPatient = nil
    local veh = GetCurrentVehicle()
    if ambulanceLocked and veh then
        SetVehicleDoorsLocked(veh, 1)
        ambulanceLocked = false
    end
end)
