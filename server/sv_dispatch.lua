-- HBS Dispatch — ps-dispatch and lb-phone integration
-- All calls are guarded by HBSConfig.Integrations toggles.
-- Called from sv_main_hbs.lua and sv_ems.lua; never registered as net events.

HBSDispatch = {}

-- ── Internal helpers ──────────────────────────────────────────────────────

-- Collect server IDs of all on-duty EMS players
local function GetOnDutyEMS()
    local result = {}
    local players = exports.qbx_core:GetQBPlayers()
    for _, v in pairs(players) do
        if v.PlayerData.job and v.PlayerData.job.type == 'ems' and v.PlayerData.job.onduty then
            result[#result + 1] = v.PlayerData.source
        end
    end
    return result
end

-- Send a ps-dispatch call if the integration is enabled
local function SendPsDispatch(callCfg, coords, extraData)
    if not HBSConfig.Integrations.psDispatch then return end
    local ok, err = pcall(function()
        local payload = {
            message  = callCfg.message,
            codeName = callCfg.codeName,
            code     = callCfg.code,
            icon     = callCfg.icon,
            priority = callCfg.priority,
            color    = callCfg.color,
            coords   = vector3(coords.x, coords.y, coords.z),
            jobs     = callCfg.jobs,
            blip     = callCfg.blip,
        }
        -- Merge any extra key/value metadata (shown in dispatch card)
        if extraData then
            payload.playerList = extraData
        end
        exports['ps-dispatch']:CallBlip(payload)
    end)
    if not ok then
        HBSLog('dispatch', 'ps-dispatch error: ' .. tostring(err))
    end
end

-- Send a lb-phone push notification to all on-duty EMS
local function SendLbPhoneToEMS(title, content, excludeSrc)
    if not HBSConfig.Integrations.lbPhone then return end
    local emsList = GetOnDutyEMS()
    for _, emsSrc in ipairs(emsList) do
        if emsSrc ~= excludeSrc then
            local ok, err = pcall(function()
                exports['lb-phone']:SendNotification(emsSrc, {
                    app     = 'Dispatch',
                    title   = title,
                    content = content,
                })
            end)
            if not ok then
                HBSLog('dispatch', 'lb-phone error for src=' .. tostring(emsSrc) .. ': ' .. tostring(err))
                break  -- if the first call fails the export probably isn't available; stop spamming
            end
        end
    end
end

-- ── Public API ────────────────────────────────────────────────────────────

-- Called when any player goes downed (civilian or EMS patient).
-- coords: vector3 or table {x,y,z}
function HBSDispatch.CivilianDown(src, coords)
    local cfg = HBSConfig.Dispatch.civilianDown
    local streetName = GetStreetNameAtCoord(coords.x, coords.y, coords.z, Citizen.ResultAsString())
    local extra = {
        { key = 'Location', value = streetName or ('%.0f, %.0f'):format(coords.x, coords.y) },
    }

    SendPsDispatch(cfg, coords, extra)

    local phoneMsg = ('Civilian down — %s'):format(
        streetName or ('%.0f, %.0f'):format(coords.x, coords.y))
    SendLbPhoneToEMS('🚨 Medical Emergency', phoneMsg)

    HBSLog('dispatch', ('CivilianDown: src=%s coords=%.0f,%.0f'):format(tostring(src), coords.x, coords.y))
end

-- Called when an EMS broadcasts a Mass Casualty Incident.
function HBSDispatch.MassCasualty(src, coords, callerName)
    local cfg = HBSConfig.Dispatch.massCasualty
    local streetName = GetStreetNameAtCoord(coords.x, coords.y, coords.z, Citizen.ResultAsString())
    local extra = {
        { key = 'Declared by', value = callerName or 'Unknown EMS' },
        { key = 'Location',    value = streetName or ('%.0f, %.0f'):format(coords.x, coords.y) },
    }

    SendPsDispatch(cfg, coords, extra)

    local phoneMsg = ('%s declared a Mass Casualty Event — %s'):format(
        callerName or 'EMS', streetName or ('%.0f, %.0f'):format(coords.x, coords.y))
    SendLbPhoneToEMS('🚨 MASS CASUALTY EVENT', phoneMsg, src)

    HBSLog('dispatch', ('MassCasualty: src=%s caller=%s'):format(tostring(src), tostring(callerName)))
end
