-- Vehicle interactions: stretcher loading, ambulance door lock, heli EMS

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

local function IsHeliModel(veh)
    local model = GetEntityModel(veh)
    for _, m in ipairs(Config.HelicopterModels) do
        if model == GetHashKey(m) then return true end
    end
    return false
end

local function IsDriverSeat(veh)
    local ped = PlayerPedId()
    return GetPedInVehicleSeat(veh, -1) == ped
end

local function InAmbulance()
    local veh = GetCurrentVehicle()
    return veh and IsAmbulanceModel(veh) and IsDriverSeat(veh)
end

-- ── Find nearest downed player ────────────────────────────────────────────

local function GetNearestDowned(maxDist)
    maxDist = maxDist or Config.MaxStretcherDist
    local myCoords = GetEntityCoords(PlayerPedId())
    for _, pid in ipairs(GetActivePlayers()) do
        if pid ~= PlayerId() then
            local srv  = GetPlayerServerId(pid)
            local ped  = GetPlayerPed(pid)
            if GetStateBagValue('player:' .. srv, SB.Keys.isDowned) then
                if #(GetEntityCoords(ped) - myCoords) <= maxDist then
                    return srv, ped
                end
            end
        end
    end
    return nil, nil
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
        -- Put patient into back seat
        SetPedIntoVehicle(targetPed, veh, 1)
        loadedPatient = targetSrc

        if Config.AmbulanceLockOnLoad then
            SetVehicleDoorsLocked(veh, 3)   -- all locked except driver
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

-- ── Interaction thread ────────────────────────────────────────────────────

CreateThread(function()
    while true do
        Wait(0)
        if not IsPlayerLoaded() then Wait(2000); goto continue end
        if not InAmbulance() then Wait(1000); goto continue end

        local targetSrc, targetPed = GetNearestDowned()

        if targetSrc and not loadedPatient then
            lib.showTextUI(Locale('stretcher_load_hint'), { position = 'top-center' })
            if IsControlJustPressed(0, 38) then   -- E
                lib.hideTextUI()
                LoadPatient(targetSrc, targetPed)
            end
        elseif loadedPatient then
            lib.showTextUI(Locale('stretcher_unload_hint'), { position = 'top-center' })
            if IsControlJustPressed(0, 38) then
                lib.hideTextUI()
                UnloadPatient()
            end
        else
            lib.hideTextUI()
        end
        ::continue::
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
