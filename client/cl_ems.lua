-- HBS EMS: ox_target actions, revive/treat with research unlocks, downed blips

local downedBlips = {}
local carryActive = false
local carriedPed  = nil
local carriedSrc  = nil

-- ── Helpers ───────────────────────────────────────────────────────────────

local function PedToServerId(ped)
    for _, pid in ipairs(GetActivePlayers()) do
        if GetPlayerPed(pid) == ped then
            return GetPlayerServerId(pid)
        end
    end
end

local function PedIsDowned(ped)
    local srv = PedToServerId(ped)
    if not srv then return false end
    return GetStateBagValue('player:' .. srv, HBS.Keys.isDowned) == true
end

-- ── Revive ────────────────────────────────────────────────────────────────

local function Revive(targetSrc)
    if HBSConfig.ReviveRequiresItem and not HBSHasUnlock('hands_only_revive') then
        if exports.ox_inventory:Search('count', HBSConfig.ReviveItem) < 1 then
            exports.qbx_core:Notify('You need a ' .. HBSConfig.ReviveItem .. '.', 'error')
            return
        end
    end

    local reviveTime = HBSHasUnlock('rapid_revive') and math.floor(HBSConfig.ReviveTime * 0.7) or HBSConfig.ReviveTime

    RequestAnimDict('mini@repair')
    while not HasAnimDictLoaded('mini@repair') do Wait(10) end

    if lib.progressCircle({
        duration     = reviveTime * 1000,
        label        = 'Reviving patient...',
        useWhileDead = false,
        canCancel    = true,
        disable      = { move = false, car = false, combat = true },
        anim         = { dict = 'mini@repair', clip = 'fixing_a_ped', flag = 16 },
    }) then
        TriggerServerEvent('hbs_ambulance:server:emsRevive', targetSrc)
    end
end

-- ── Treat wounds ──────────────────────────────────────────────────────────

local function TreatWounds(targetSrc)
    RequestAnimDict('mini@repair')
    while not HasAnimDictLoaded('mini@repair') do Wait(10) end

    if lib.progressCircle({
        duration     = HBSConfig.TreatTime * 1000,
        label        = 'Treating wounds...',
        useWhileDead = false,
        canCancel    = true,
        disable      = { move = false, car = false, combat = true },
        anim         = { dict = 'mini@repair', clip = 'fixing_a_ped', flag = 16 },
    }) then
        TriggerServerEvent('hbs_ambulance:server:emsTreat', targetSrc)
        exports.qbx_core:Notify('Wounds treated.', 'success')
    end
end

-- ── Carry ─────────────────────────────────────────────────────────────────

local StopCarry  -- forward declaration so StartCarry's closure can reference it

local function StartCarry(targetSrc, targetPed)
    if carryActive then return end
    carryActive = true
    carriedPed  = targetPed
    carriedSrc  = targetSrc

    local myPed     = cache.ped
    local boneIndex = GetPedBoneIndex(myPed, 57005)
    AttachEntityToEntity(targetPed, myPed, boneIndex, 0.5, 0.0, 0.0, 0.0, 0.0, 0.0, true, true, false, true, 1, true)

    TriggerServerEvent('hbs_ambulance:server:setCarried', targetSrc, true)

    -- Add ox_target option on the carried ped to put them down
    exports.ox_target:addLocalEntity(targetPed, {
        {
            name     = 'hbs_put_down_' .. targetSrc,
            icon     = 'fa-solid fa-person-walking-arrow-right',
            label    = 'Put Down Patient',
            distance = 2.0,
            onSelect = function()
                StopCarry()
            end,
        },
    })
end

StopCarry = function()
    if not carryActive then return end
    if carriedPed then
        exports.ox_target:removeLocalEntity(carriedPed, { 'hbs_put_down_' .. (carriedSrc or '') })
        DetachEntity(carriedPed, true, true)
    end
    TriggerServerEvent('hbs_ambulance:server:setCarried', carriedSrc, false)
    carryActive = false
    carriedPed  = nil
    carriedSrc  = nil
end

-- ── ox_target global player options ───────────────────────────────────────

exports.ox_target:addGlobalPlayer({
    {
        label       = 'Revive Patient',
        icon        = 'fas fa-heartbeat',
        distance    = 3.0,
        canInteract = function(entity) return HBSIsEMS() and PedIsDowned(entity) end,
        onSelect    = function(data)
            local srv = PedToServerId(data.entity)
            if srv then CreateThread(function() Revive(srv) end) end
        end,
    },
    {
        label       = 'Treat Wounds',
        icon        = 'fas fa-band-aid',
        distance    = 3.0,
        canInteract = function() return HBSIsEMS() end,
        onSelect    = function(data)
            local srv = PedToServerId(data.entity)
            if srv then CreateThread(function() TreatWounds(srv) end) end
        end,
    },
    {
        label       = 'Carry Patient',
        icon        = 'fas fa-hands-holding',
        distance    = 3.0,
        canInteract = function(entity) return HBSIsEMS() and PedIsDowned(entity) and not carryActive end,
        onSelect    = function(data)
            local srv = PedToServerId(data.entity)
            if srv then CreateThread(function() StartCarry(srv, data.entity) end) end
        end,
    },
    {
        label       = 'Triage Patient',
        icon        = 'fas fa-triangle-exclamation',
        distance    = 3.0,
        canInteract = function(entity) return HBSIsEMS() and PedIsDowned(entity) end,
        onSelect    = function(data)
            local srv = PedToServerId(data.entity)
            if not srv then return end
            lib.registerContext({
                id      = 'hbs_triage_' .. srv,
                title   = 'Triage Patient',
                options = {
                    { title = 'Critical', onSelect = function() TriggerServerEvent('hbs_ambulance:server:triagePatient', srv, 'critical') end },
                    { title = 'Moderate', onSelect = function() TriggerServerEvent('hbs_ambulance:server:triagePatient', srv, 'moderate') end },
                    { title = 'Minor',    onSelect = function() TriggerServerEvent('hbs_ambulance:server:triagePatient', srv, 'minor')    end },
                },
            })
            lib.showContext('hbs_triage_' .. srv)
        end,
    },
    {
        label       = 'Administer Detox',
        icon        = 'fas fa-flask-vial',
        distance    = 3.0,
        canInteract = function() return HBSIsEMS() and HBSHasUnlock('addiction_therapy') end,
        onSelect    = function(data)
            local srv = PedToServerId(data.entity)
            if not srv then return end
            CreateThread(function()
                local completed = lib.progressCircle({
                    duration     = 10000,
                    label        = 'Administering Detox...',
                    useWhileDead = false,
                    canCancel    = true,
                    disable      = { move = false, car = true, combat = true },
                    anim         = { dict = 'mp_suicide', clip = 'pill', flag = 49 },
                })
                if completed then
                    TriggerServerEvent('hbs_ambulance:server:administerDetox', srv)
                end
            end)
        end,
    },
    {
        label       = 'Full Detox Treatment',
        icon        = 'fas fa-shield-virus',
        distance    = 3.0,
        canInteract = function() return HBSIsEMS() and HBSHasUnlock('full_detox') end,
        onSelect    = function(data)
            local srv = PedToServerId(data.entity)
            if not srv then return end
            CreateThread(function()
                local completed = lib.progressCircle({
                    duration     = 25000,
                    label        = 'Full Detox Treatment...',
                    useWhileDead = false,
                    canCancel    = true,
                    disable      = { move = true, car = true, combat = true },
                    anim         = { dict = 'mini@crate_search@std@ps', clip = 'crate_search_ps_std', flag = 49 },
                })
                if completed then
                    TriggerServerEvent('hbs_ambulance:server:fullDetox', srv)
                end
            end)
        end,
    },
})

-- ── Downed blips (EMS only) ───────────────────────────────────────────────

RegisterNetEvent('hbs_ambulance:client:updateDownedBlips', function(list)
    for _, b in pairs(downedBlips) do RemoveBlip(b) end
    downedBlips = {}
    if not HBSIsEMS() then return end

    for _, entry in ipairs(list) do
        local blip = AddBlipForCoord(entry.x, entry.y, entry.z)
        SetBlipSprite(blip, 153)
        SetBlipColour(blip, entry.triage and HBSConfig.InjurySeverity and 1 or 1)
        SetBlipScale(blip, 0.8)
        SetBlipAsShortRange(blip, false)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName('Downed Player')
        EndTextCommandSetBlipName(blip)
        downedBlips[entry.src] = blip
    end
end)

-- ── EMS XP / research state sync ─────────────────────────────────────────

RegisterNetEvent('hbs_ambulance:client:emsResearchUpdate', function(data)
    HBSState.emsResearch = data
end)
