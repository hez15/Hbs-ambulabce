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

HBSConfig.Addiction = {
    withdrawalDelay    = 30,
    withdrawalTickRate = 60,
    levelLabels = { [0]='None', [1]='Developing', [2]='Moderate', [3]='Severe', [4]='Critical' },
    effects = {
        [1] = { moodSwing = true },
        [2] = { handTremors = true, speedMult = 0.95 },
        [3] = { handTremors = true, speedMult = 0.90, visualDistortion = true },
        [4] = { handTremors = true, speedMult = 0.80, visualDistortion = true, vomit = true, healthDrain = 0.5 },
    },
    treatment = { cost = 5000, duration = 30, reduceTo = 1 },
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
        rapid_revive     = { tier = 2, label = 'Rapid Revive',        desc = 'Revive speed -30%' },
        patient_examine  = { tier = 2, label = 'Patient Examination',  desc = 'See injuries/stress/addiction on examine' },
        trauma_splint    = { tier = 3, label = 'Trauma Splint',        desc = 'Treat fractures without a splint item' },
        iv_therapy       = { tier = 3, label = 'IV Therapy',           desc = 'Treatment restores 75 HP to patient' },
        full_surgery     = { tier = 4, label = 'Full Surgery',         desc = 'Clear ALL injuries (20s procedure)' },
        adrenaline_revive= { tier = 4, label = 'Adrenaline Revive',   desc = 'Revived player gets 20s adrenaline boost' },
        hands_only_revive= { tier = 5, label = 'Hands-Only Revive',   desc = 'Revive without item (3 min cooldown)' },
        mass_casualty    = { tier = 5, label = 'Mass Casualty Alert',  desc = 'Broadcast emergency to all EMS' },
    },
}
