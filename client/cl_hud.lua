-- HBS HUD: sends state to the NUI SVG body diagram

local _hudVisible   = false
local _hudHideAt    = 0   -- GetGameTimer() timestamp after which to auto-hide
local HUD_HIDE_DELAY = 8000  -- ms of no damage + no injuries before hiding

local function GetHealthPct()
    local ped = PlayerPedId()
    if not ped or ped == 0 then return 0 end

    local hp    = GetEntityHealth(ped)    or 0
    local maxHp = GetEntityMaxHealth(ped) or 200

    -- Death floor for player peds is 100; avoid division by zero
    if maxHp <= 100 or hp <= 100 then return 0 end

    local pct = ((hp - 100) / (maxHp - 100)) * 100
    pct = math.max(0, math.min(100, pct))
    HBSUtils.Debug('hud', ('health: raw=%d max=%d pct=%.1f'):format(hp, maxHp, pct))
    return pct
end

local function HasActiveInjuries()
    if not HBSState or not HBSState.injuries then return false end
    for _ in pairs(HBSState.injuries) do return true end
    return false
end

local function ShowHud()
    if _hudVisible then return end
    _hudVisible = true
    SendNUIMessage({ action = 'showHud' })
end

local function HideHud()
    if not _hudVisible then return end
    _hudVisible = false
    SendNUIMessage({ action = 'hideHud' })
end

local function BumpHudTimer()
    ShowHud()
    _hudHideAt = GetGameTimer() + HUD_HIDE_DELAY
end

local function UpdateHud()
    SendNUIMessage({
        action    = 'updateHud',
        health    = GetHealthPct(),
        injuries  = HBSState.injuries,
        stress    = HBSState.stress,
        inPain    = HBSState.inPain,
        bloodloss = HBSState.bloodloss,
        addiction = HBSState.addiction,
    })
end

AddEventHandler('hbs:client:hudUpdate', function()
    BumpHudTimer()
    UpdateHud()
end)

-- Show and populate HUD only after state has fully loaded from server
AddEventHandler('hbs:client:stateLoaded', function()
    if HasActiveInjuries() then
        ShowHud()
    else
        HideHud()
    end
    UpdateHud()
    HBSUtils.Debug('hud', 'HUD initialised on state load')
end)

RegisterNetEvent('hbs_ambulance:client:applyInjuryEffects', function()
    BumpHudTimer()
    UpdateHud()
end)

-- ── Auto-hide tick ────────────────────────────────────────────────────────────

CreateThread(function()
    local lastPct = -1
    while true do
        Wait(500)
        if not HBSState.loaded then goto hudcontinue end

        local pct = GetHealthPct()

        -- Bump timer any time health drops
        if pct < lastPct then
            BumpHudTimer()
        end

        -- Send health update only when value changes
        if pct ~= lastPct then
            lastPct = pct
            SendNUIMessage({ action = 'updateHealth', value = pct })
        end

        -- Auto-hide: HUD visible, no injuries, downed, and timer elapsed
        if _hudVisible
            and not HBSState.isDowned
            and not HasActiveInjuries()
            and GetGameTimer() >= _hudHideAt
        then
            HideHud()
        end

        ::hudcontinue::
    end
end)

-- Hide HUD on unload (show is handled by hbs:client:stateLoaded above)
AddEventHandler('QBCore:Client:OnPlayerUnloaded', function() HideHud() end)
AddEventHandler('qbx_core:playerUnloaded',         function() HideHud() end)
