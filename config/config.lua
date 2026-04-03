HBSConfig = {}  -- namespace to avoid conflict with qbx config

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
HBSConfig.ReviveRequiresItem = false
HBSConfig.ReviveItem         = 'firstaid'

HBSConfig.DispatchCooldown = 30
HBSConfig.MinEmsOnline = 1

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
-- How addiction works:
--   1. Addictive items (morphine, painkiller) have a per-level chance to
--      increase addiction when used. Level 0 = no addiction yet.
--   2. Addiction builds from level 0 → 4 over repeated use.
--   3. After withdrawalDelay minutes from last use, withdrawal effects fire
--      every withdrawalTickRate seconds until addiction reaches 0.
--   4. Players self-treat with methadone (reduces 1 level) or painkiller
--      (suppresses withdrawal temporarily).
--   5. EMS can administer detox (Tier 3 unlock) or full detox (Tier 4).
--
-- Addictive consumables (defined in MedicalItems below):
--   • morphine    — high chance, escalates fast, very effective painkiller
--   • painkiller  — lower chance, slow escalation, also provides withdrawal relief
--
-- Treatment consumables:
--   • methadone   — reduces addiction level by 1, no withdrawal relief of its own
--   • painkiller  — withdrawal relief only (doesn't reduce addiction level)

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

    -- Addiction chance per use at each current level (0–4)
    -- Format: item name = { [currentLevel] = chance (0.0–1.0) }
    -- These mirror the per-item addictChance tables in MedicalItems below.
    -- Defined here for reference — actual values live on each item.
    chanceReference = {
        morphine   = { [0]=0.10, [1]=0.25, [2]=0.40, [3]=0.60, [4]=0.80 },
        painkiller = { [0]=0.05, [1]=0.15, [2]=0.25, [3]=0.40, [4]=0.60 },
    },
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

-- ── Crafting ──────────────────────────────────────────────────────────────────
-- Ingredients are ox_inventory item names
-- tier = minimum research tier required
-- craftTime = seconds for progress circle

HBSConfig.Crafting = {
    -- ── Tier 1: EMT ─────────────────────────────────────────────────────────
    bandage = {
        label     = 'Bandage',
        tier      = 1,
        craftTime = 10,
        output    = { item = 'bandage', amount = 3 },
        ingredients = {
            { item = 'med_gauze',   amount = 2 },
            { item = 'med_tape',    amount = 1 },
        },
    },
    painkiller = {
        label     = 'Painkiller',
        tier      = 1,
        craftTime = 8,
        output    = { item = 'painkiller', amount = 2 },
        ingredients = {
            { item = 'med_pills',   amount = 3 },
        },
    },

    -- ── Tier 2: Paramedic ────────────────────────────────────────────────────
    splint = {
        label     = 'Splint',
        tier      = 2,
        craftTime = 15,
        output    = { item = 'splint', amount = 1 },
        ingredients = {
            { item = 'med_gauze',   amount = 3 },
            { item = 'med_tape',    amount = 2 },
            { item = 'med_rod',     amount = 1 },
        },
    },
    morphine = {
        label     = 'Morphine Shot',
        tier      = 2,
        craftTime = 20,
        output    = { item = 'morphine', amount = 1 },
        ingredients = {
            { item = 'med_syringe', amount = 1 },
            { item = 'med_opioid',  amount = 2 },
        },
    },

    -- ── Tier 3: Senior Paramedic ─────────────────────────────────────────────
    firstaidkit = {
        label     = 'First Aid Kit',
        tier      = 3,
        craftTime = 25,
        output    = { item = 'firstaidkit', amount = 1 },
        ingredients = {
            { item = 'bandage',     amount = 2 },
            { item = 'med_gauze',   amount = 4 },
            { item = 'med_tape',    amount = 2 },
            { item = 'med_pills',   amount = 2 },
        },
    },
    methadone = {
        label     = 'Methadone (Detox)',
        tier      = 3,
        craftTime = 30,
        output    = { item = 'methadone', amount = 2 },
        ingredients = {
            { item = 'med_syringe', amount = 1 },
            { item = 'med_detox',   amount = 3 },
        },
    },
    bloodbag = {
        label     = 'Blood Bag',
        tier      = 3,
        craftTime = 20,
        output    = { item = 'bloodbag', amount = 1 },
        ingredients = {
            { item = 'med_bloodpack', amount = 1 },
            { item = 'med_tube',      amount = 1 },
        },
    },

    -- ── Tier 4: Lead Medic ───────────────────────────────────────────────────
    defibrillator = {
        label     = 'Defibrillator Charge',
        tier      = 4,
        craftTime = 40,
        output    = { item = 'defibrillator', amount = 1 },
        ingredients = {
            { item = 'med_defib_pad', amount = 2 },
            { item = 'med_battery',   amount = 1 },
            { item = 'med_tube',      amount = 1 },
        },
    },
    surgical_kit = {
        label     = 'Surgical Kit',
        tier      = 4,
        craftTime = 45,
        output    = { item = 'surgical_kit', amount = 1 },
        ingredients = {
            { item = 'med_scalpel',   amount = 1 },
            { item = 'med_gauze',     amount = 5 },
            { item = 'med_syringe',   amount = 2 },
            { item = 'med_opioid',    amount = 3 },
        },
    },

    -- ── Tier 5: Chief of Medicine ────────────────────────────────────────────
    advanced_surgical_pack = {
        label     = 'Advanced Surgical Pack',
        tier      = 5,
        craftTime = 60,
        output    = { item = 'advanced_surgical_pack', amount = 1 },
        ingredients = {
            { item = 'surgical_kit',  amount = 1 },
            { item = 'bloodbag',      amount = 1 },
            { item = 'morphine',      amount = 1 },
            { item = 'med_detox',     amount = 2 },
        },
    },
}

-- Crafting table location (ox_target zone at EMS base)
HBSConfig.CraftingTable = {
    coords   = vector3(297.7, -584.5, 43.3), -- Sandy Shores Medical (adjust to your server)
    heading  = 0.0,
    label    = 'Medical Crafting Table',
    radius   = 1.5,
}

-- Research terminal location (ox_target zone at EMS base)
-- This is where EMS view their tier, XP progress, and unlocked abilities
HBSConfig.ResearchTerminal = {
    coords   = vector3(295.2, -582.8, 43.3), -- Adjust to your server
    label    = 'EMS Research Terminal',
    radius   = 1.2,
}
