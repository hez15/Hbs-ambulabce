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

local function StartCarry(targetSrc, targetPed)
    if carryActive then return end
    carryActive = true
    carriedPed  = targetPed
    carriedSrc  = targetSrc

    local myPed     = cache.ped
    local boneIndex = GetPedBoneIndex(myPed, 57005)
    AttachEntityToEntity(targetPed, myPed, boneIndex, 0.5, 0.0, 0.0, 0.0, 0.0, 0.0, true, true, false, true, 1, true)

    TriggerServerEvent('hbs_ambulance:server:setCarried', targetSrc, true)
    exports.qbx_core:Notify('Now carrying patient. [G] to put down.', 'inform')
end

local function StopCarry()
    if not carryActive then return end
    if carriedPed then DetachEntity(carriedPed, true, true) end
    TriggerServerEvent('hbs_ambulance:server:setCarried', carriedSrc, false)
    carryActive = false
    carriedPed  = nil
    carriedSrc  = nil
    exports.qbx_core:Notify('Patient put down.', 'inform')
end

CreateThread(function()
    while true do
        if carryActive then
            lib.showTextUI('[G] Put Down Patient', { position = 'top-center' })
            if IsControlJustPressed(0, 47) then
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
                    { title = '🔴 Critical', onSelect = function() TriggerServerEvent('hbs_ambulance:server:triagePatient', srv, 'critical') end },
                    { title = '🟠 Moderate', onSelect = function() TriggerServerEvent('hbs_ambulance:server:triagePatient', srv, 'moderate') end },
                    { title = '🟡 Minor',    onSelect = function() TriggerServerEvent('hbs_ambulance:server:triagePatient', srv, 'minor')    end },
                },
            })
            lib.showContext('hbs_triage_' .. srv)
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
