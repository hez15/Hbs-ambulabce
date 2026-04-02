-- Hospital zones, NPC spawn, check-in via ox_target, beds via zone interaction

local hospitalNPCs = {}
local activeZones  = {}

-- ── Spawn NPC doctor and attach ox_target ─────────────────────────────────

local function SpawnNPC(hospital)
    local npc   = hospital.npc
    local model = GetHashKey(npc.model)
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(10) end

    local ped = CreatePed(4, model,
        npc.coords.x, npc.coords.y, npc.coords.z, npc.coords.w,
        false, true
    )
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanRagdoll(ped, false)
    FreezeEntityPosition(ped, true)
    SetModelAsNoLongerNeeded(model)

    -- Attach ox_target interactions to the NPC ped
    exports.ox_target:addLocalEntity(ped, {
        {
            label    = 'See Doctor',
            icon     = 'fas fa-user-doctor',
            distance = 3.0,
            onSelect = function()
                lib.progressBar({
                    duration     = Config.NpcHealTime * 1000,
                    label        = Locale('hospital_healing'),
                    useWhileDead = false,
                    canCancel    = true,
                }, function(completed)
                    if completed then
                        TriggerServerEvent('hbs_ambulance:server:hospitalHeal')
                    end
                end)
            end,
        },
        {
            label    = 'Pay Bills',
            icon     = 'fas fa-file-invoice-dollar',
            distance = 3.0,
            onSelect = function()
                TriggerServerEvent('hbs_ambulance:server:payBills')
            end,
        },
        {
            label       = 'Rehabilitation',
            icon        = 'fas fa-pills',
            distance    = 3.0,
            description = string.format('Addiction treatment — $%s', Config.Addiction.treatment.cost),
            onSelect    = function()
                TriggerEvent('hbs_ambulance:client:startRehab')
            end,
        },
    })

    return ped
end

-- ── Bed interaction zones (coordinate-based, no target entity) ───────────

local function CreateBedZones(hospital)
    for _, bedCoord in ipairs(hospital.bedCoords or {}) do
        local zone = lib.zones.sphere({
            coords  = vector3(bedCoord.x, bedCoord.y, bedCoord.z),
            radius  = Config.BedInteractRadius,
            debug   = Config.Debug,
            onEnter = function()
                lib.showTextUI(Locale('hospital_bed_hint'), { position = 'top-center' })
            end,
            onExit  = function()
                lib.hideTextUI()
            end,
            inside  = function()
                if IsControlJustPressed(0, 38) then   -- E
                    lib.hideTextUI()
                    lib.progressBar({
                        duration     = Config.NpcHealTime * 1000,
                        label        = Locale('hospital_healing'),
                        useWhileDead = false,
                        canCancel    = true,
                    }, function(done)
                        if done then
                            TriggerServerEvent('hbs_ambulance:server:hospitalHeal')
                        end
                    end)
                end
            end,
        })
        table.insert(activeZones, zone)
    end
end

-- ── Hospital blip ─────────────────────────────────────────────────────────

local function AddHospitalBlip(hospital)
    local blip = AddBlipForCoord(hospital.blipCoords.x, hospital.blipCoords.y, hospital.blipCoords.z)
    SetBlipSprite(blip, Config.HospitalBlip.sprite)
    SetBlipColour(blip, Config.HospitalBlip.color)
    SetBlipScale(blip, Config.HospitalBlip.scale)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(hospital.name)
    EndTextCommandSetBlipName(blip)
end

-- ── Initialise all hospitals ──────────────────────────────────────────────

CreateThread(function()
    Wait(3000)   -- wait for world to settle
    for i, hospital in ipairs(Config.Hospitals) do
        hospitalNPCs[i] = SpawnNPC(hospital)
        CreateBedZones(hospital)
        AddHospitalBlip(hospital)
    end
end)

-- ── Clean up on resource stop ─────────────────────────────────────────────

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    for _, ped in ipairs(hospitalNPCs) do
        if DoesEntityExist(ped) then DeleteEntity(ped) end
    end
    hospitalNPCs = {}
end)

-- ── Net events ────────────────────────────────────────────────────────────

RegisterNetEvent('hbs_ambulance:client:hospitalHealed', function()
    TriggerEvent('hbs_ambulance:client:clearInjuries')
    TriggerEvent('hbs_ambulance:client:setStress', 0)
    SetEntityHealth(PlayerPedId(), 200)
    Notify(Locale('hospital_healed'), 'success', 6000)
end)

RegisterNetEvent('hbs_ambulance:client:billSent', function(amount)
    Notify(Locale('hospital_bill_sent', amount), 'error', 8000)
end)

-- ── Rehab event ───────────────────────────────────────────────────────────

AddEventHandler('hbs_ambulance:client:startRehab', function()
    local hasAddiction = false
    for _, level in pairs(LocalState.addiction or {}) do
        if level > 0 then hasAddiction = true; break end
    end
    if not hasAddiction then
        Notify('You have no addiction to treat.', 'inform')
        return
    end
    TriggerServerEvent('hbs_ambulance:server:startRehab')
end)
