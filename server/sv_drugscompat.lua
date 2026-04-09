-- HBS Drug compatibility — config-driven hooks into external drug scripts.
-- We do NOT handle drug use/effects here; your drug script does that.
-- This file ONLY applies HBS addiction rolls on drug consumption events.
--
-- To hook a new drug script: add an entry to HBSConfig.SubstanceEventHooks in config.lua.
-- No changes to this file are needed.

-- ── Register all configured event hooks ───────────────────────────────────────

local hookCount = 0

for eventName, resolver in pairs(HBSConfig.SubstanceEventHooks or {}) do
    if type(resolver) == 'function' then
        AddEventHandler(eventName, function(...)
            local src = source
            -- resolver receives (src, ...) and returns a substance/item key or nil
            local substanceKey = resolver(src, ...)
            if substanceKey and type(substanceKey) == 'string' then
                RollAddiction(src, substanceKey)
                HBSLog('drugscompat', ('hook "%s": src=%s substance=%s'):format(eventName, tostring(src), substanceKey))
            end
        end)
        hookCount = hookCount + 1
        HBSLog('drugscompat', ('registered hook: "%s"'):format(eventName))
    else
        HBSLog('drugscompat', ('WARNING: hook for "%s" is not a function, skipped'):format(eventName))
    end
end

if hookCount == 0 then
    HBSLog('drugscompat', 'no SubstanceEventHooks configured — external drug scripts must call exports.hbs_ambulance:consumeSubstance()')
else
    HBSLog('drugscompat', ('registered %d event hook(s)'):format(hookCount))
end
