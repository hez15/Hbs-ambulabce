-- Shared utilities and state bag keys

HBSUtils = {}

-- Debug logging — gated by HBSConfig.Debug
function HBSUtils.Debug(category, ...)
    if not HBSConfig or not HBSConfig.Debug then return end
    local args = { ... }
    for i, v in ipairs(args) do args[i] = tostring(v) end
    print(('[hbs][%s] %s'):format(category, table.concat(args, ' | ')))
end

-- Convenience alias used throughout server files
function HBSLog(...)
    HBSUtils.Debug('server', ...)
end

function HBSUtils.TableContains(tbl, val)
    for _, v in ipairs(tbl) do
        if v == val then return true end
    end
    return false
end

function HBSUtils.Clamp(val, min, max)
    if val < min then return min end
    if val > max then return max end
    return val
end

-- Server-only helpers
if IsDuplicityVersion() then
    function HBSUtils.IsEMS(src)
        local Player = exports.qbx_core:GetPlayer(src)
        return Player and Player.PlayerData.job.type == 'ems'
    end

    function HBSUtils.CountOnlineEMS()
        return exports.qbx_core:GetDutyCountType('ems')
    end

    function HBSUtils.GetCitizenId(src)
        local Player = exports.qbx_core:GetPlayer(src)
        return Player and Player.PlayerData.citizenid or nil
    end
end

-- ── Injury definitions ────────────────────────────────────────────────────

InjuryDefs = {}

InjuryDefs.BoneMap = {
    [31086] = 'head',      [23553] = 'head',
    [57597] = 'torso',     [24818] = 'torso',     [11816] = 'torso',    [6442] = 'torso',
    [40269] = 'left_arm',  [58271] = 'left_arm',  [36029] = 'left_arm',
    [28252] = 'right_arm', [43298] = 'right_arm', [57005] = 'right_arm',
    [63931] = 'left_leg',  [36864] = 'left_leg',  [14201] = 'left_leg',
    [52301] = 'right_leg', [16335] = 'right_leg', [20781] = 'right_leg',
}

InjuryDefs.Ranks = { scratch=1, minor=2, fracture=3, critical=4 }

function InjuryDefs.BoneToBodyPart(boneHash)
    return InjuryDefs.BoneMap[boneHash] or 'torso'
end

function InjuryDefs.IsWorse(new, existing)
    return (InjuryDefs.Ranks[new] or 0) > (InjuryDefs.Ranks[existing] or 0)
end

function InjuryDefs.DamageToSeverity(dmg)
    if HBSConfig and HBSConfig.DamageThresholds then
        for _, t in ipairs(HBSConfig.DamageThresholds) do
            if dmg >= t.min and dmg <= t.max then return t.severity end
        end
    end
    if dmg < 19 then return 'scratch'
    elseif dmg < 41 then return 'minor'
    elseif dmg < 71 then return 'fracture'
    else return 'critical' end
end

-- ── State bag keys ────────────────────────────────────────────────────────

HBS = {}  -- namespace for state bag helpers

HBS.Keys = {
    isDowned   = 'hbs:isDowned',
    injuries   = 'hbs:injuries',
    stress     = 'hbs:stress',
    addiction  = 'hbs:addiction',
    diseases   = 'hbs:diseases',
    triage     = 'hbs:triage',
    emsTier    = 'hbs:emsTier',
    emsXP      = 'hbs:emsXP',
    emsUnlocks = 'hbs:emsUnlocks',
    isCarried  = 'hbs:isCarried',
}

function HBS.SetLocal(key, value)
    if IsDuplicityVersion() then return end
    LocalPlayer.state:set(HBS.Keys[key] or key, value, true)
end

function HBS.Set(src, key, value)
    if not IsDuplicityVersion() then return end
    Player(src).state:set(HBS.Keys[key] or key, value, true)
end

function HBS.Get(src, key)
    if not IsDuplicityVersion() then return end
    if not src or src <= 0 then return nil end
    return Player(src).state[HBS.Keys[key] or key]
end

function HBS.GetRemote(serverId, key)
    return GetStateBagValue('player:' .. serverId, HBS.Keys[key] or key)
end
