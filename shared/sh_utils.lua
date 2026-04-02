-- Shared utilities, injury definitions, and state bag helpers
-- Loaded on both client and server

Utils = {}

-- ── Debug ──────────────────────────────────────────────────────────────────

function Utils.Debug(...)
    if Config and Config.Debug then
        print('[hbs_ambulance]', ...)
    end
end

-- ── Table helpers ──────────────────────────────────────────────────────────

function Utils.DeepCopy(orig)
    local copy = {}
    for k, v in pairs(orig) do
        copy[k] = (type(v) == 'table') and Utils.DeepCopy(v) or v
    end
    return copy
end

function Utils.TableContains(tbl, val)
    for _, v in ipairs(tbl) do
        if v == val then return true end
    end
    return false
end

function Utils.TableLength(tbl)
    local n = 0
    for _ in pairs(tbl) do n = n + 1 end
    return n
end

-- ── Math helpers ───────────────────────────────────────────────────────────

function Utils.Clamp(val, min, max)
    if val < min then return min end
    if val > max then return max end
    return val
end

function Utils.FormatTime(seconds)
    local m = math.floor(seconds / 60)
    local s = seconds % 60
    return string.format('%02d:%02d', m, s)
end

function Utils.Round(val, decimals)
    local factor = 10 ^ (decimals or 0)
    return math.floor(val * factor + 0.5) / factor
end

-- ── Server-only helpers ────────────────────────────────────────────────────

if IsDuplicityVersion then
    function Utils.IsEMS(src)
        local Player = exports.qbx_core:GetPlayer(src)
        return Player and Player.PlayerData.job.name == Config.EmsJob
    end

    function Utils.CountOnlineEMS()
        local count   = 0
        local players = exports.qbx_core:GetQBPlayers()
        for _, player in pairs(players) do
            if player.PlayerData.job.name == Config.EmsJob then
                count = count + 1
            end
        end
        return count
    end

    function Utils.GetCitizenId(src)
        local Player = exports.qbx_core:GetPlayer(src)
        return Player and Player.PlayerData.citizenid or nil
    end
end

-- ── Nearest hospital (shared) ──────────────────────────────────────────────

function Utils.GetNearestHospital(coords)
    local nearest, dist = nil, math.huge
    for _, hospital in ipairs(Config.Hospitals) do
        local hc = hospital.blipCoords
        local d  = #(vector3(coords.x, coords.y, coords.z) -
                     vector3(hc.x, hc.y, hc.z))
        if d < dist then dist = d; nearest = hospital end
    end
    return nearest
end

-- ════════════════════════════════════════════════════════════════════════════
-- INJURY DEFINITIONS
-- ════════════════════════════════════════════════════════════════════════════

InjuryDefs = {}

InjuryDefs.BodyParts = {
    'head', 'torso', 'left_arm', 'right_arm', 'left_leg', 'right_leg'
}

-- Numeric rank for severity comparison
InjuryDefs.Ranks = {
    scratch        = 1,
    minor          = 2,
    fracture       = 3,
    critical       = 4,
}

-- GTA bone hash → body part
InjuryDefs.BoneMap = {
    [31086] = 'head',       -- SKEL_Head
    [23553] = 'head',       -- SKEL_Neck_1
    [57597] = 'torso',      -- SKEL_Spine3
    [24818] = 'torso',      -- SKEL_Spine2
    [11816] = 'torso',      -- SKEL_Spine1
    [6442]  = 'torso',      -- SKEL_Spine0
    [40269] = 'left_arm',   -- SKEL_L_UpperArm
    [58271] = 'left_arm',   -- SKEL_L_Forearm
    [36029] = 'left_arm',   -- SKEL_L_Hand
    [28252] = 'right_arm',  -- SKEL_R_UpperArm
    [43298] = 'right_arm',  -- SKEL_R_Forearm
    [57005] = 'right_arm',  -- SKEL_R_Hand
    [63931] = 'left_leg',   -- SKEL_L_Thigh
    [36864] = 'left_leg',   -- SKEL_L_Calf
    [14201] = 'left_leg',   -- SKEL_L_Foot
    [52301] = 'right_leg',  -- SKEL_R_Thigh
    [16335] = 'right_leg',  -- SKEL_R_Calf
    [20781] = 'right_leg',  -- SKEL_R_Foot
}

function InjuryDefs.BoneToBodyPart(boneHash)
    return InjuryDefs.BoneMap[boneHash] or 'torso'
end

function InjuryDefs.GetRank(severity)
    return InjuryDefs.Ranks[severity] or 0
end

function InjuryDefs.IsWorse(new, existing)
    return InjuryDefs.GetRank(new) > InjuryDefs.GetRank(existing)
end

-- Damage amount → severity string
function InjuryDefs.DamageToSeverity(dmg)
    if dmg < 10  then return 'scratch'
    elseif dmg < 25 then return 'minor'
    elseif dmg < 50 then return 'fracture'
    else                 return 'critical' end
end

-- ════════════════════════════════════════════════════════════════════════════
-- STATE BAG KEYS
-- ════════════════════════════════════════════════════════════════════════════

SB = {}

SB.Keys = {
    isDowned   = 'hbs:isDowned',
    injuries   = 'hbs:injuries',
    stress     = 'hbs:stress',
    isCarried  = 'hbs:isCarried',
    carrierSrc = 'hbs:carrierSrc',
    inPain     = 'hbs:inPain',
    bloodloss  = 'hbs:bloodloss',
    addiction  = 'hbs:addiction',
    triage     = 'hbs:triage',
    -- EMS research progression
    emsTier    = 'hbs:emsTier',
    emsXP      = 'hbs:emsXP',
    emsUnlocks = 'hbs:emsUnlocks',
    onDuty     = 'hbs:onDuty',
    -- Temporary mentor boost (set on boosted EMS)
    mentorTier = 'hbs:mentorTier',
}

-- Client-side: set own player state bag (broadcast = true for cross-client sync)
function SB.SetLocal(key, value)
    if IsDuplicityVersion() then return end
    LocalPlayer.state:set(SB.Keys[key] or key, value, true)
end

-- Server-side: set a player's state bag
function SB.Set(src, key, value)
    if not IsDuplicityVersion() then return end
    Player(src).state:set(SB.Keys[key] or key, value, true)
end

-- Client-side: read a remote player's state bag by their server id
function SB.GetRemote(serverId, key)
    return GetStateBagValue('player:' .. serverId, SB.Keys[key] or key)
end

-- Server-side: read a player's state bag
function SB.Get(src, key)
    if not IsDuplicityVersion() then return end
    return Player(src).state[SB.Keys[key] or key]
end
