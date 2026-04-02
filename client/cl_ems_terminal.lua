-- EMS Research Terminal — spawns a computer prop at each hospital and opens the research menu

local terminalProps = {}   -- { propHandle, ... }

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

-- ── Create interaction zone for one terminal ──────────────────────────────

local function CreateTerminalZone(hospitalName, coord)
    lib.zones.sphere({
        coords  = vector3(coord.x, coord.y, coord.z),
        radius  = Config.EMSResearch.terminalRadius,
        debug   = Config.Debug,
        onEnter = function()
            if not IsEMS() then return end
            lib.showTextUI('[E] EMS Research Terminal — ' .. hospitalName, { position = 'top-center' })
        end,
        onExit  = function()
            lib.hideTextUI()
        end,
        inside  = function()
            if not IsEMS() then return end
            if IsControlJustPressed(0, 38) then   -- E key
                lib.hideTextUI()
                -- OpenResearchMenu is defined in cl_ems_research.lua (loaded before this file)
                if OpenResearchMenu then
                    OpenResearchMenu()
                end
            end
        end,
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
            end
            CreateTerminalZone(hospital.name, coord)
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
