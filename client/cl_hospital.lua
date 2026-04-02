-- Hospital zones, NPC spawn, check-in, beds, rehab

local hospitalNPCs  = {}
local activeZones   = {}

-- ── Spawn NPC doctor ──────────────────────────────────────────────────────

local function SpawnNPC(hospital)
    local npc    = hospital.npc
    local model  = GetHashKey(npc.model)
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
    return ped
end

-- ── Hospital check-in menu ────────────────────────────────────────────────

local function OpenHospitalMenu(hospital)
    lib.registerContext({
        id    = 'hbs_hospital_menu',
        title = hospital.name,
        options = {
            {
                title       = Locale('hospital_see_doctor'),
                description = Locale('hospital_see_doctor_desc'),
                onSelect    = function()
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
                title       = Locale('hospital_pay_bills'),
                description = Locale('hospital_pay_bills_desc'),
                onSelect    = function()
                    TriggerServerEvent('hbs_ambulance:server:payBills')
                end,
            },
            {
                title       = Locale('hospital_rehab_title'),
                description = Locale('hospital_rehab_desc', Config.Addiction.treatment.cost),
                onSelect    = function()
                    TriggerEvent('hbs_ambulance:client:startRehab')
                end,
            },
        },
    })
    lib.showContext('hbs_hospital_menu')
end

-- ── Create zones ──────────────────────────────────────────────────────────

local function CreateZones()
    for i, hospital in ipairs(Config.Hospitals) do
        -- Check-in zone
        local zone = lib.zones.sphere({
            coords  = vector3(hospital.checkin.x, hospital.checkin.y, hospital.checkin.z),
            radius  = Config.CheckInRadius,
            debug   = Config.Debug,
            onEnter = function()
                lib.showTextUI(Locale('hospital_checkin_hint'), { position = 'top-center' })
            end,
            onExit  = function()
                lib.hideTextUI()
            end,
            inside  = function()
                if IsControlJustPressed(0, 38) then   -- E
                    lib.hideTextUI()
                    OpenHospitalMenu(hospital)
                end
            end,
        })
        table.insert(activeZones, zone)

        -- Bed zones
        for _, bedCoord in ipairs(hospital.beds or {}) do
            local bedZone = lib.zones.sphere({
                coords  = bedCoord,
                radius  = Config.BedRadius,
                debug   = Config.Debug,
                onEnter = function()
                    lib.showTextUI(Locale('hospital_bed_hint'), { position = 'top-center' })
                end,
                onExit  = function()
                    lib.hideTextUI()
                end,
                inside  = function()
                    if IsControlJustPressed(0, 38) then
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
            table.insert(activeZones, bedZone)
        end

        -- Spawn NPC
        hospitalNPCs[i] = SpawnNPC(hospital)

        -- Hospital blip
        local blip = AddBlipForCoord(hospital.coords.x, hospital.coords.y, hospital.coords.z)
        SetBlipSprite(blip, Config.HospitalBlip.sprite)
        SetBlipColour(blip, Config.HospitalBlip.color)
        SetBlipScale(blip, Config.HospitalBlip.scale)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(hospital.name)
        EndTextCommandSetBlipName(blip)
    end
end

CreateThread(function()
    Wait(3000)   -- wait for world to settle
    CreateZones()
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

-- ── Rehab event (addiction module hooks into this) ────────────────────────

AddEventHandler('hbs_ambulance:client:startRehab', function()
    -- Check if player actually has any addiction
    local hasAddiction = false
    for _, level in pairs(LocalState.addiction) do
        if level > 0 then hasAddiction = true; break end
    end
    if not hasAddiction then
        Notify('You have no addiction to treat.', 'inform')
        return
    end
    TriggerServerEvent('hbs_ambulance:server:startRehab')
end)
