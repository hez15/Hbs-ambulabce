-- HBS Diseases — client: load state, apply symptom effects, HUD icon

-- ── Load diseases on state load ───────────────────────────────────────────

AddEventHandler('hbs:client:stateLoaded', function()
    -- Preload symptom animation dicts so cough/animations play immediately
    CreateThread(function()
        RequestAnimDict('mp_player_int_upperbody_cough_1_p')
    end)

    local diseases = HBS.GetRemote(cache.serverId or GetPlayerServerId(PlayerId()), 'diseases') or {}
    HBSState.diseases = diseases
    ApplyDiseaseEffects()
    UpdateDiseaseIcon()
    HBSUtils.Debug('disease', ('loaded %d active disease(s)'):format(
        (function() local n=0; for _ in pairs(diseases) do n=n+1 end; return n end)()))
end)

-- ── Server updates diseases ───────────────────────────────────────────────

RegisterNetEvent('hbs_ambulance:client:diseasesUpdate', function(diseases)
    HBSState.diseases = diseases or {}
    HBS.SetLocal('diseases', HBSState.diseases)
    ApplyDiseaseEffects()
    UpdateDiseaseIcon()
end)

-- ── Apply symptom effects ─────────────────────────────────────────────────

function ApplyDiseaseEffects()
    local ped = cache.ped
    local worstSpeed = 1.0
    local hasShake   = false

    for disease, stage in pairs(HBSState.diseases or {}) do
        local cfg = HBSConfig.Diseases and HBSConfig.Diseases[disease]
        if cfg and cfg.symptoms and cfg.symptoms[stage] then
            local sym = cfg.symptoms[stage]
            if sym.speedMult and sym.speedMult < worstSpeed then
                worstSpeed = sym.speedMult
            end
            if sym.screenShake then hasShake = true end
        end
    end

    -- Apply speed (stack with injury effects by taking worst)
    -- Note: injury effects also call SetRunSprintMultiplierForPlayer; disease compounds it.
    -- We just set ours here; they'll re-set theirs on next injury tick.
    if worstSpeed < 1.0 then
        local current = GetRunSprintMultiplierForPlayer(PlayerId())
        if worstSpeed < current then
            SetRunSprintMultiplierForPlayer(PlayerId(), worstSpeed)
        end
    end

    if hasShake then
        ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', 0.12)
    else
        StopGameplayCamShaking(false)
    end

    HBSUtils.Debug('disease', ('effects applied: speed=%.2f shake=%s'):format(worstSpeed, tostring(hasShake)))
end

-- ── HUD disease icon ──────────────────────────────────────────────────────

function UpdateDiseaseIcon()
    local hasDisease = false
    for _ in pairs(HBSState.diseases or {}) do
        hasDisease = true; break
    end
    SendNUIMessage({ action = 'setIcon', icon = 'disease', visible = hasDisease })
end

-- ── Symptom tick (cough animation, health drain) ──────────────────────────

CreateThread(function()
    while true do
        Wait(5000)
        if not IsHBSLoaded() or HBSState.isDowned then goto diseasecontinue end

        for disease, stage in pairs(HBSState.diseases or {}) do
            local cfg = HBSConfig.Diseases and HBSConfig.Diseases[disease]
            if not cfg or not cfg.symptoms then goto nextSymptom end
            local sym = cfg.symptoms[stage]
            if not sym then goto nextSymptom end

            -- Health drain
            if sym.healthDrain and sym.healthDrain > 0 then
                local ped = cache.ped
                local hp  = GetEntityHealth(ped)
                if hp > 101 then
                    SetEntityHealth(ped, math.max(101, hp - sym.healthDrain))
                end
            end

            -- Cough animation (plays once per tick, non-blocking)
            if sym.cough and math.random() < 0.4 then
                local dict = 'mp_player_int_upperbody_cough_1_p'
                local clip = 'mp_player_int_cough'
                if not HasAnimDictLoaded(dict) then
                    RequestAnimDict(dict)
                    local t = 0
                    while not HasAnimDictLoaded(dict) and t < 15 do Wait(100); t = t + 1 end
                end
                if HasAnimDictLoaded(dict) then
                    TaskPlayAnim(cache.ped, dict, clip, 3.0, -3.0, 1800, 48, 0, false, false, false)
                end
            end

            -- Fever visual
            if sym.fever and math.random() < 0.2 then
                SetTimecycleModifier('drug_flying_in_sky')
                SetTimecycleModifierStrength(0.15)
                Wait(2000)
                ClearTimecycleModifier()
            end

            ::nextSymptom::
        end

        ::diseasecontinue::
    end
end)
