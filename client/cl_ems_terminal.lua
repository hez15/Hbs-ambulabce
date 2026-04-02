-- EMS Research Terminal — spawns a computer prop at each hospital, ox_target opens research menu

local terminalProps = {}

-- ── Helpers ───────────────────────────────────────────────────────────────

local function IsEMS()
    local pd = exports.qbx_core:GetPlayerData()
    return pd and pd.job and pd.job.name == Config.EmsJob
end

-- ── Spawn a single terminal prop ─────────────────────────────────────────

local function SpawnTerminalProp(coord)
    local model = Config.EMSResearch.terminalModel
    RequestModel(model)
    local timeout = 0
    while not HasModelLoaded(model) and timeout < 100 do
        Wait(10)
        timeout = timeout + 1
    end
    if not HasModelLoaded(model) then
        Utils.Debug('EMS terminal: failed to load model', model)
        return nil
    end

    local prop = CreateObjectNoOffset(model, coord.x, coord.y, coord.z, false, false, false)
    SetEntityHeading(prop, coord.w or 0.0)
    FreezeEntityPosition(prop, true)
    SetEntityCollision(prop, true, true)
    PlaceObjectOnGroundProperly(prop)
    SetModelAsNoLongerNeeded(model)
    return prop
end

-- ── Attach ox_target to terminal prop ────────────────────────────────────

local function AttachTerminalTarget(prop, hospitalName)
    exports.ox_target:addLocalEntity(prop, {
        {
            label       = 'EMS Research Terminal',
            icon        = 'fas fa-microscope',
            distance    = Config.EMSResearch.terminalRadius,
            canInteract = function() return IsEMS() end,
            onSelect    = function()
                if OpenEMSResearchMenu then OpenEMSResearchMenu() end
            end,
        },
    })
end

-- ── Initialise all terminals on player load ───────────────────────────────

AddEventHandler('hbs_ambulance:client:stateLoaded', function()
    if not IsEMS() then return end

    for _, hospital in ipairs(Config.Hospitals) do
        local coord = hospital.researchTerminalCoord
        if coord then
            local prop = SpawnTerminalProp(coord)
            if prop then
                table.insert(terminalProps, prop)
                AttachTerminalTarget(prop, hospital.name)
            end
        end
    end
    Utils.Debug('EMS terminals spawned:', #terminalProps)
end)

-- ── Clean up props on resource stop ──────────────────────────────────────

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    for _, prop in ipairs(terminalProps) do
        if DoesEntityExist(prop) then DeleteEntity(prop) end
    end
    terminalProps = {}
end)
