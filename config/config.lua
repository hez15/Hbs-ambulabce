HBSConfig = {}  -- namespace to avoid conflict with qbx config

-- Set true to enable debug prints in server console and client F8
HBSConfig.Debug = false

-- Body parts matching GTA bone IDs
HBSConfig.BodyParts = {
    head      = { bone = 31086, label = 'Head' },
    torso     = { bone = 24818, label = 'Torso' },
    left_arm  = { bone = 58271, label = 'Left Arm' },
    right_arm = { bone = 57005, label = 'Right Arm' },
    left_leg  = { bone = 36864, label = 'Left Leg' },
    right_leg = { bone = 16335, label = 'Right Leg' },
}

HBSConfig.DamageThresholds = {
    { min = 1,  max = 18,  severity = 'scratch'  },
    { min = 19, max = 40,  severity = 'minor'    },
    { min = 41, max = 70,  severity = 'fracture' },
    { min = 71, max = 999, severity = 'critical' },
}

HBSConfig.InjurySeverity = {
    scratch  = { label = 'Scratch',        bleedRate = 0, healthDrain = 0   },
    minor    = { label = 'Minor Wound',    bleedRate = 1, healthDrain = 0.5 },
    fracture = { label = 'Fracture',       bleedRate = 0, healthDrain = 0   },
    critical = { label = 'Critical Wound', bleedRate = 3, healthDrain = 2   },
}

HBSConfig.InjuryEffects = {
    left_leg  = { limp = true, speedMult = 0.6 },
    right_leg = { limp = true, speedMult = 0.6 },
    left_arm  = { weaponSway = true },
    right_arm = { weaponSway = true },
    torso     = { breathingImpaired = true, speedMult = 0.8 },
    head      = { blurredVision = true },
}

HBSConfig.ReviveTime  = 8
HBSConfig.TreatTime   = 5
HBSConfig.ReviveRequiresItem = true
HBSConfig.ReviveItem         = 'defibrillator'

HBSConfig.DispatchCooldown = 30
HBSConfig.MinEmsOnline = 1

-- ── Third-party integrations ──────────────────────────────────────────────────
-- Set to false if you don't have the resource installed.

HBSConfig.Integrations = {
    psDispatch = true,   -- ps-dispatch: creates blip + card in the dispatch MDT
    lbPhone    = true,   -- lb-phone: push notification to all on-duty EMS phones
}

-- ── Dispatch call definitions ─────────────────────────────────────────────────
-- Each entry maps to a ps-dispatch CallBlip payload.
-- jobs: which job types receive the call in ps-dispatch.
-- blip.time: how long the blip stays on the map (ms).

HBSConfig.Dispatch = {
    civilianDown = {
        message  = 'Civilian Requires Medical Attention',
        codeName = 'hbsCivilianDown',
        code     = '10-52',
        icon     = 'fas fa-ambulance',
        priority = 1,
        color    = '#e74c3c',
        jobs     = { 'ambulance' },
        blip     = {
            sprite  = 153,
            scale   = 1.2,
            colour  = 1,
            flashes = true,
            text    = 'Civilian Down',
            time    = 180000,   -- 3 minutes
            radius  = 0,
        },
    },
    massCasualty = {
        message  = 'MASS CASUALTY EVENT — Multiple casualties reported',
        codeName = 'hbsMassCasualty',
        code     = 'MCI',
        icon     = 'fas fa-hospital',
        priority = 1,
        color    = '#c0392b',
        jobs     = { 'ambulance' },
        blip     = {
            sprite  = 153,
            scale   = 1.5,
            colour  = 1,
            flashes = true,
            text    = 'Mass Casualty Event',
            time    = 300000,   -- 5 minutes
            radius  = 0,
        },
    },
}

HBSConfig.Stress = {
    max = 100,
    naturalDecay = 1,
    tickRate = 30,
    sources = {
        combat       = 2,
        injury       = 15,
        vehicleCrash = 12,
        crashDelta   = 60.0,
    },
    effects = {
        [25] = { screenShake = 'SMALL_EXPLOSION_SHAKE',  shakeAmp = 0.02 },
        [50] = { screenShake = 'SMALL_EXPLOSION_SHAKE',  shakeAmp = 0.05, staminaDrain = true },
        [75] = { screenShake = 'MEDIUM_EXPLOSION_SHAKE', shakeAmp = 0.08, staminaDrain = true, reducedAccuracy = true },
        [90] = { screenShake = 'LARGE_EXPLOSION_SHAKE',  shakeAmp = 0.12, staminaDrain = true, reducedAccuracy = true, panic = true },
    },
}

-- ── Addiction System ──────────────────────────────────────────────────────────

HBSConfig.Addiction = {
    withdrawalDelay    = 30,  -- minutes after last use before withdrawal starts
    withdrawalTickRate = 60,  -- seconds between each withdrawal effect tick

    levelLabels = { [0]='None', [1]='Developing', [2]='Moderate', [3]='Severe', [4]='Critical' },

    -- Effects applied each withdrawal tick per level
    effects = {
        [1] = { moodSwing = true },
        [2] = { handTremors = true, speedMult = 0.95 },
        [3] = { handTremors = true, speedMult = 0.90, visualDistortion = true },
        [4] = { handTremors = true, speedMult = 0.80, visualDistortion = true, vomit = true, healthDrain = 0.5 },
    },
}

-- ── Substances ────────────────────────────────────────────────────────────────
-- Single source of truth for ALL addictive substances.
--
-- itemAliases: all ox_inventory item names that should trigger this substance.
--   Used for auto-mapping from external drug scripts.
-- addictChance: per-current-level (0–4) roll chance on each use.
--
-- To add a new substance (e.g. whippets):
--   1. Add an entry here.
--   2. Add the item to ox_inventory.
--   3. Optionally add drug effects to HBSConfig.Drugs.
-- No other files need to change.

HBSConfig.Substances = {
    cocaine    = {
        label        = 'Cocaine',
        addictChance = { [0]=0.20, [1]=0.40, [2]=0.60, [3]=0.80, [4]=0.95 },
        itemAliases  = { 'cocaine', 'coke_bag', 'coke' },
    },
    meth       = {
        label        = 'Methamphetamine',
        addictChance = { [0]=0.30, [1]=0.55, [2]=0.75, [3]=0.90, [4]=0.98 },
        itemAliases  = { 'meth', 'methamphetamine', 'crystal_meth' },
    },
    heroin     = {
        label        = 'Heroin',
        addictChance = { [0]=0.35, [1]=0.60, [2]=0.80, [3]=0.92, [4]=0.99 },
        itemAliases  = { 'heroin', 'smack' },
    },
    weed       = {
        label        = 'Cannabis',
        addictChance = { [0]=0.03, [1]=0.08, [2]=0.15, [3]=0.25, [4]=0.40 },
        itemAliases  = { 'weed', 'marijuana', 'joint', 'cannabis' },
    },
    ecstasy    = {
        label        = 'Ecstasy',
        addictChance = { [0]=0.10, [1]=0.25, [2]=0.45, [3]=0.65, [4]=0.85 },
        itemAliases  = { 'ecstasy', 'mdma', 'xtc', 'pill' },
    },
    morphine   = {
        label        = 'Morphine',
        addictChance = { [0]=0.10, [1]=0.25, [2]=0.40, [3]=0.60, [4]=0.80 },
        itemAliases  = { 'morphine' },
    },
    painkiller = {
        label        = 'Painkiller',
        addictChance = { [0]=0.05, [1]=0.15, [2]=0.25, [3]=0.40, [4]=0.60 },
        itemAliases  = { 'painkiller' },
    },
    nitrous    = {
        label        = 'Nitrous (Whippets)',
        addictChance = { [0]=0.05, [1]=0.10, [2]=0.20, [3]=0.35, [4]=0.55 },
        itemAliases  = { 'whippet', 'nitrous', 'nos' },
    },
}

-- ── SubstanceEventHooks ───────────────────────────────────────────────────────
-- Config-driven hooks into external drug script events.
-- Key   = the server event name fired by your drug script when a player uses a drug.
-- Value = function(src, ...) that receives the event args and returns a substance key
--         (matching HBSConfig.Substances) or nil to skip.
--
-- Example for md-drugs:
--   ['md-drugs:server:drugConsumed'] = function(src, itemName) return itemName end,
--
-- Example for a script that passes drugType as second arg:
--   ['myDrugScript:server:used'] = function(src, drugType, qty) return drugType end,

HBSConfig.SubstanceEventHooks = {
    -- Uncomment and adjust for your drug script:
    -- ['md-drugs:server:drugConsumed'] = function(src, itemName) return itemName end,
}

HBSConfig.MedicalItems = {
    bandage = {
        label = 'Bandage', useTime = 5,
        heals = { 'scratch', 'minor' }, healParts = { 'any' },
        animation = { dict = 'mp_suicide', anim = 'pill', flag = 49 },
    },
    firstaidkit = {
        label = 'First Aid Kit', useTime = 10,
        heals = { 'scratch', 'minor', 'fracture' }, healParts = { 'any' },
        healthRestore = 30,
        canCivilianRevive = true,   -- civilians can use this on downed players
        civilianReviveTime = 20,    -- seconds (longer than EMS defibrillator)
        animation = { dict = 'mini@crate_search@std@ps', anim = 'crate_search_ps_std', flag = 49 },
    },
    bloodbag = {
        label = 'Blood Bag', useTime = 15, healthRestore = 50,
        animation = { dict = 'mp_suicide', anim = 'pill', flag = 49 },
    },
    defibrillator = {
        label = 'Defibrillator', useTime = 8, canRevive = true,
        animation = { dict = 'missambulance', anim = 'amb_action_treat_b_doctor', flag = 49 },
    },
    morphine = {
        label = 'Morphine', useTime = 4,
        heals = { 'critical', 'fracture' }, healParts = { 'any' },
        stressReduce = 30, healthRestore = 20,
        addictive = true, substance = 'morphine',
        addictChance = { [0]=0.10, [1]=0.25, [2]=0.40, [3]=0.60, [4]=0.80 },
        animation = { dict = 'mp_suicide', anim = 'pill', flag = 49 },
    },
    painkiller = {
        label = 'Painkiller', useTime = 3,
        stressReduce = 15, healthRestore = 10,
        addictive = true, substance = 'painkiller',
        addictChance = { [0]=0.05, [1]=0.15, [2]=0.25, [3]=0.40, [4]=0.60 },
        withdrawalRelief = true,
        animation = { dict = 'mp_suicide', anim = 'pill', flag = 49 },
    },
    splint = {
        label = 'Splint', useTime = 8,
        heals = { 'fracture' }, healParts = { 'left_leg', 'right_leg', 'left_arm', 'right_arm' },
        animation = { dict = 'mini@crate_search@std@ps', anim = 'crate_search_ps_std', flag = 49 },
    },
    methadone = {
        label = 'Methadone', useTime = 5,
        withdrawalRelief = true, addictionReduce = true, reduceAmount = 1,
        animation = { dict = 'mp_suicide', anim = 'pill', flag = 49 },
    },
}

-- EMS Research Tiers
HBSConfig.EMSResearch = {
    tiers = {
        { tier = 1, label = 'EMT',              xpRequired = 0    },
        { tier = 2, label = 'Paramedic',         xpRequired = 500  },
        { tier = 3, label = 'Senior Paramedic',  xpRequired = 1500 },
        { tier = 4, label = 'Lead Medic',        xpRequired = 3500 },
        { tier = 5, label = 'Chief of Medicine', xpRequired = 7000 },
    },
    xpRewards = {
        revive = 75, treat = 30, transport = 50,
    },
    abilities = {
        rapid_revive      = { tier = 2, label = 'Rapid Revive',         desc = 'Revive speed -30%' },
        patient_examine   = { tier = 2, label = 'Patient Examination',  desc = 'See injuries/stress/addiction on examine' },
        trauma_splint     = { tier = 3, label = 'Trauma Splint',        desc = 'Treat fractures without a splint item' },
        iv_therapy        = { tier = 3, label = 'IV Therapy',           desc = 'Treatment restores 75 HP to patient' },
        addiction_therapy = { tier = 3, label = 'Addiction Therapy',    desc = 'Administer detox to reduce patient addiction by 1 level' },
        full_surgery      = { tier = 4, label = 'Full Surgery',         desc = 'Clear ALL injuries (20s procedure)' },
        adrenaline_revive = { tier = 4, label = 'Adrenaline Revive',   desc = 'Revived player gets -50 stress + full HP' },
        full_detox        = { tier = 4, label = 'Full Detox',           desc = 'Completely clear all addiction from patient' },
        hands_only_revive = { tier = 5, label = 'Hands-Only Revive',   desc = 'Revive without item (3 min cooldown)' },
        mass_casualty     = { tier = 5, label = 'Mass Casualty Alert',  desc = 'Broadcast emergency to all EMS' },
    },
}

-- ── Diseases ──────────────────────────────────────────────────────────────────
-- Each disease has configurable stages with per-stage symptoms.
-- Set spreadRadius = 0 to disable proximity spread.
-- treatItem: ox_inventory item name an EMS must use to treat this disease.
-- Set to nil to make the disease untreatable (natural progression only).

HBSConfig.Diseases = {
    flu = {
        label        = 'Influenza',
        stages       = 3,
        spreadRadius = 5.0,    -- metres, players within this range can contract it
        spreadChance = 0.015,  -- per proximity tick (every 60s)
        progressTime = 600,    -- seconds per stage advancement
        treatItem    = 'antibiotic',
        symptoms = {
            [1] = { cough=true, speedMult=0.97 },
            [2] = { cough=true, speedMult=0.93, healthDrain=0.5 },
            [3] = { cough=true, speedMult=0.88, healthDrain=1.5, screenShake=true },
        },
    },
    infection = {
        label        = 'Wound Infection',
        stages       = 2,
        spreadRadius = 0,      -- no person-to-person spread
        progressTime = 900,
        treatItem    = 'antibiotic',
        symptoms = {
            [1] = { healthDrain=0.5 },
            [2] = { healthDrain=2.0, fever=true },
        },
    },
}

-- Research terminal location (ox_target zone at EMS base)
-- This is where EMS view their tier, XP progress, and unlocked abilities
HBSConfig.ResearchTerminal = {
    coords   = vector3(295.2, -582.8, 43.3), -- Adjust to your server
    label    = 'EMS Research Terminal',
    radius   = 1.2,
}

-- ── Drug Items ────────────────────────────────────────────────────────────────
-- Drugs plug into the same addiction system as medical items.
-- Each drug has a timed HIGH (duration seconds) with screen/stat effects,
-- followed by a COME-DOWN that wears off naturally.
-- Addiction escalates with repeated use — withdrawal fires via the
-- standard HBSConfig.Addiction withdrawal tick.
--
-- isDrug = true   → handled by the drug effect system, not the medical item system
-- substance       → key used in hbs_addiction DB table
-- addictChance    → per-current-level chance to increase addiction on use
-- duration        → seconds the high lasts
-- effects table:
--   speedMult       → sprint speed multiplier while high (>1.0 = faster)
--   stressReduce    → stress points removed on use
--   healthRegen     → if true: slowly restores HP while high
--   screenEffect    → timecycle modifier name applied while high
--   postFx          → AnimPostFx name played on use (brief visual pop)
--   paranoia        → if true: random cam shake bursts while high
--   sedation        → if true: movement slowed during come-down phase

HBSConfig.Drugs = {

    cocaine = {
        label    = 'Cocaine',
        useTime  = 2,
        isDrug   = true,
        substance = 'cocaine',
        addictive = true,
        addictChance = { [0]=0.20, [1]=0.40, [2]=0.60, [3]=0.80, [4]=0.95 },
        duration = 300, -- 5 minute high
        comeDown = 120, -- 2 minute come-down (speed reduced)
        effects = {
            speedMult    = 1.18,
            stressReduce = 30,
            screenEffect = 'drug_driving',
            postFx       = 'DrugsMichaelAliensFight',
            paranoia     = true,
        },
        animation = { dict = 'mp_suicide', anim = 'pill', flag = 49 },
    },

    meth = {
        label    = 'Methamphetamine',
        useTime  = 4,
        isDrug   = true,
        substance = 'meth',
        addictive = true,
        addictChance = { [0]=0.30, [1]=0.55, [2]=0.75, [3]=0.90, [4]=0.98 },
        duration = 600, -- 10 minute high
        comeDown = 300, -- 5 minute come-down
        effects = {
            speedMult    = 1.25,
            stressReduce = 10,
            healthRegen  = true,  -- slow HP tick while high
            screenEffect = 'drug_flying_in_sky',
            postFx       = 'DrugsMichaelAliensFight',
            paranoia     = true,
        },
        animation = { dict = 'mp_suicide', anim = 'pill', flag = 49 },
    },

    heroin = {
        label    = 'Heroin',
        useTime  = 5,
        isDrug   = true,
        substance = 'heroin',
        addictive = true,
        addictChance = { [0]=0.35, [1]=0.60, [2]=0.80, [3]=0.92, [4]=0.99 },
        duration = 480, -- 8 minute high
        comeDown = 240, -- 4 minute come-down
        effects = {
            speedMult    = 0.85, -- slowed while high
            stressReduce = 50,
            painRelief   = true, -- heals scratch/minor injuries on use
            screenEffect = 'Oxy_overdose',
            sedation     = true, -- come-down also sedated
        },
        animation = { dict = 'mp_suicide', anim = 'pill', flag = 49 },
    },

    weed = {
        label    = 'Weed',
        useTime  = 6,
        isDrug   = true,
        substance = 'weed',
        addictive = true,
        addictChance = { [0]=0.03, [1]=0.08, [2]=0.15, [3]=0.25, [4]=0.40 },
        duration = 240, -- 4 minute high
        comeDown = 60,
        effects = {
            speedMult    = 0.92,
            stressReduce = 40,
            screenEffect = 'drug_wobbly_vision',
            postFx       = 'Spectator3',
        },
        animation = { dict = 'amb@world_human_smoking@male@idle_a', anim = 'idle_a', flag = 49 },
    },

    ecstasy = {
        label    = 'Ecstasy',
        useTime  = 3,
        isDrug   = true,
        substance = 'ecstasy',
        addictive = true,
        addictChance = { [0]=0.10, [1]=0.25, [2]=0.45, [3]=0.65, [4]=0.85 },
        duration = 420, -- 7 minute high
        comeDown = 180, -- 3 minute come-down
        effects = {
            speedMult    = 1.10,
            stressReduce = 60,
            screenEffect = 'drug_wobbly_vision',
            postFx       = 'DrugsMichaelAliensFight',
        },
        animation = { dict = 'mp_suicide', anim = 'pill', flag = 49 },
    },
}
