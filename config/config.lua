Config = {}

--[[
    GENERAL
]]
Config.Debug = false
Config.EmsJob = 'ambulance'          -- Job name for EMS players
Config.MinEmsOnline = 1              -- Minimum EMS online before NPC doctors activate
Config.UseTarget = false             -- Use ox_target for interactions (false = key prompt)
Config.InteractKey = 38             -- E key

--[[
    DEATH / BLEEDOUT
]]
Config.BleedoutTime = 300            -- Seconds before death (5 min)
Config.LastStandTime = 60            -- Seconds of last-stand crawl before bleedout starts
Config.RespawnCooldown = 10          -- Seconds at hospital before respawn menu appears
Config.DeathBill = {
    enabled = true,
    baseAmount = 2500,               -- Base hospital bill on death
    emsBonusDiscount = 0.50,         -- 50% discount if revived by EMS (not self-respawn)
}
Config.DeathAnims = {                -- Anims played when going down
    dict = 'missambulance',
    anim = 'crash_ped_injured_idle',
}
Config.CrawlSpeed = 0.1              -- Movement speed multiplier while in last-stand

--[[
    INJURIES
]]
-- Body parts and their GTA bone IDs
Config.BodyParts = {
    head     = { bone = 31086, label = 'Head'      },
    torso    = { bone = 24818, label = 'Torso'     },
    leftArm  = { bone = 18905, label = 'Left Arm'  },
    rightArm = { bone = 57005, label = 'Right Arm' },
    leftLeg  = { bone = 58271, label = 'Left Leg'  },
    rightLeg = { bone = 51826, label = 'Right Leg' },
}

Config.InjurySeverity = {
    scratch  = { label = 'Scratch',        bleedRate = 0,    healthDrain = 0   },
    minor    = { label = 'Minor Wound',    bleedRate = 1,    healthDrain = 0.5 },
    fracture = { label = 'Fracture',       bleedRate = 0,    healthDrain = 0   },
    critical = { label = 'Critical Wound', bleedRate = 3,    healthDrain = 2   },
}

-- Damage thresholds → injury severity
Config.DamageThresholds = {
    { min = 1,  max = 10, severity = 'scratch'  },
    { min = 11, max = 30, severity = 'minor'    },
    { min = 31, max = 60, severity = 'fracture' },
    { min = 61, max = 999,severity = 'critical' },
}

-- Effects per body part + severity
Config.InjuryEffects = {
    leftLeg  = { limp = true,       speedMult = 0.6 },
    rightLeg = { limp = true,       speedMult = 0.6 },
    leftArm  = { weaponSway = true, reloadSlow = true },
    rightArm = { weaponSway = true, reloadSlow = true },
    torso    = { breathingImpaired = true, speedMult = 0.8 },
    head     = { blurredVision = true, controlsReduced = true },
}

--[[
    EMS
]]
Config.ReviveTime = 8                -- Seconds to revive
Config.TreatTime = 5                 -- Seconds to treat a wound
Config.CarryOffset = vector3(0.5, 0.0, 0.0)  -- Attach offset when carrying
Config.DownedBlipColor = 1           -- Red blips for downed players on EMS map
Config.DownedBlipSprite = 153        -- Heart blip sprite
Config.DispatchAlert = true          -- Alert EMS when player goes down

--[[
    HOSPITAL LOCATIONS
]]
Config.Hospitals = {
    {
        name       = 'Pillbox Medical Center',
        blipCoords = vector3(295.6, -584.4, 43.3),
        enterCoords= vector3(295.6, -584.4, 43.3),
        bedCoords  = {
            vector4(340.6, -585.4, 29.3, 340.0),
            vector4(344.6, -585.4, 29.3, 340.0),
            vector4(348.6, -585.4, 29.3, 340.0),
        },
        spawnCoord = vector4(307.5, -600.1, 43.3, 255.0),
        npcCoord   = vector4(307.2, -570.0, 43.3, 255.0),
        npcModel   = 's_m_m_doctor_01',
    },
    {
        name       = 'Sandy Shores Medical',
        blipCoords = vector3(1839.6, 3672.4, 34.3),
        enterCoords= vector3(1839.6, 3672.4, 34.3),
        bedCoords  = {
            vector4(1839.6, 3672.4, 34.3, 25.0),
        },
        spawnCoord = vector4(1839.6, 3680.4, 34.3, 200.0),
        npcCoord   = vector4(1833.0, 3668.0, 34.3, 60.0),
        npcModel   = 's_m_m_doctor_01',
    },
    {
        name       = 'Paleto Bay Medical',
        blipCoords = vector3(-246.0, 6331.0, 32.4),
        enterCoords= vector3(-246.0, 6331.0, 32.4),
        bedCoords  = {
            vector4(-246.0, 6331.0, 32.4, 0.0),
        },
        spawnCoord = vector4(-240.0, 6340.0, 32.4, 180.0),
        npcCoord   = vector4(-250.0, 6325.0, 32.4, 90.0),
        npcModel   = 's_m_m_doctor_01',
    },
}

Config.HospitalZoneRadius = 30.0
Config.NpcHealTime = 120             -- Seconds for NPC to heal player (if no EMS)
Config.NpcHealCost = 1500            -- Base cost for NPC treatment
Config.BedInteractRadius = 2.0

--[[
    MEDICAL ITEMS
]]
Config.MedicalItems = {
    bandage = {
        label       = 'Bandage',
        useTime     = 5,
        heals       = { 'scratch', 'minor' },
        healParts   = { 'any' },
        animation   = { dict = 'mp_suicide', anim = 'pill', flag = 49 },
        notification= 'You applied a bandage.',
    },
    firstaidkit = {
        label       = 'First Aid Kit',
        useTime     = 10,
        heals       = { 'scratch', 'minor', 'fracture' },
        healParts   = { 'any' },
        healthRestore = 30,
        animation   = { dict = 'mini@crate_search@std@ps', anim = 'crate_search_ps_std', flag = 49 },
        notification= 'You used a first aid kit.',
    },
    bloodbag = {
        label       = 'Blood Bag',
        useTime     = 15,
        healthRestore = 50,
        canRevive   = false,
        animation   = { dict = 'mp_suicide', anim = 'pill', flag = 49 },
        notification= 'You received a blood transfusion.',
    },
    defibrillator = {
        label        = 'Defibrillator',
        useTime      = 8,
        canRevive    = true,
        requiresEms  = false,        -- set true to require EMS job
        animation    = { dict = 'missambulance', anim = 'amb_action_treat_b_doctor', flag = 49 },
        notification = 'You used the defibrillator.',
    },
    morphine = {
        label         = 'Morphine',
        useTime       = 4,
        heals         = { 'critical', 'fracture' },
        healParts     = { 'any' },
        stressReduce  = 30,
        healthRestore = 20,
        addictive     = true,
        substance     = 'morphine',
        addictChance  = { [0]=0.10, [1]=0.25, [2]=0.40, [3]=0.60, [4]=0.80 },
        animation     = { dict = 'mp_suicide', anim = 'pill', flag = 49 },
        notification  = 'You administered morphine.',
    },
    painkiller = {
        label        = 'Painkiller',
        useTime      = 3,
        stressReduce = 15,
        healthRestore= 10,
        addictive    = true,
        substance    = 'painkiller',
        addictChance = { [0]=0.05, [1]=0.15, [2]=0.25, [3]=0.40, [4]=0.60 },
        withdrawalRelief = true,
        animation    = { dict = 'mp_suicide', anim = 'pill', flag = 49 },
        notification = 'You took a painkiller.',
    },
    splint = {
        label      = 'Splint',
        useTime    = 8,
        heals      = { 'fracture' },
        healParts  = { 'leftLeg', 'rightLeg', 'leftArm', 'rightArm' },
        animation  = { dict = 'mini@crate_search@std@ps', anim = 'crate_search_ps_std', flag = 49 },
        notification = 'You applied a splint.',
    },
    methadone = {
        label            = 'Methadone',
        useTime          = 5,
        withdrawalRelief = true,
        addictionReduce  = true,
        reduceAmount     = 1,
        animation        = { dict = 'mp_suicide', anim = 'pill', flag = 49 },
        notification     = 'You took methadone.',
    },
}

--[[
    STRESS / TRAUMA
]]
Config.Stress = {
    max          = 100,
    tickRate     = 30,               -- Seconds between stress ticks
    naturalDecay = 1,                -- Stress reduction per second when calm
    sources    = {
        combat       = 2,            -- Per second in combat
        injury       = 15,           -- Receiving an injury (applied via event)
        witnessedDeath = 10,         -- Seeing another player die nearby
        vehicleCrash = 12,           -- High speed vehicle impact
        crashDelta   = 60.0,         -- km/h speed drop threshold to count as crash
        sprint       = 0,
    },
    effects    = {
        [25] = { screenShake = 'SMALL_EXPLOSION_SHAKE', shakeAmp = 0.02 },
        [50] = { screenShake = 'SMALL_EXPLOSION_SHAKE', shakeAmp = 0.05, staminaDrain = true },
        [75] = { screenShake = 'MEDIUM_EXPLOSION_SHAKE', shakeAmp = 0.08, staminaDrain = true, reducedAccuracy = true },
        [90] = { screenShake = 'LARGE_EXPLOSION_SHAKE', shakeAmp = 0.12, staminaDrain = true, reducedAccuracy = true, panic = true },
    },
}

--[[
    ADDICTION
]]
Config.Addiction = {
    withdrawalDelay = 30,            -- Minutes after last use before withdrawal begins
    withdrawalTickRate = 60,         -- Seconds between withdrawal effect ticks
    levelLabels = {
        [0] = 'None',
        [1] = 'Developing',
        [2] = 'Moderate',
        [3] = 'Severe',
        [4] = 'Critical',
    },
    effects = {
        [1] = { moodSwing = true },
        [2] = { handTremors = true, speedMult = 0.95 },
        [3] = { handTremors = true, speedMult = 0.90, visualDistortion = true },
        [4] = { handTremors = true, speedMult = 0.80, visualDistortion = true, vomit = true, healthDrain = 0.5 },
    },
    treatment = {
        cost     = 5000,             -- Hospital rehab cost
        duration = 30,               -- Minutes for rehab
        reduceTo = 1,                -- Level after rehab (not instant cure)
    },
}

--[[
    VEHICLES
]]
Config.AmbulanceModels = {
    'ambulance', 'lguard',
}
Config.HelicopterModels = {
    'polmav', 'buzzard', 'buzzard2',
}
Config.StretcherModel    = 'prop_t20_bag_01'    -- Placeholder; swap for actual stretcher prop
Config.MaxStretcherDist  = 5.0                  -- Max distance to load a patient
Config.StretcherLoadTime = 5                     -- Seconds to load patient into vehicle

--[[
    BLIPS
]]
Config.HospitalBlip = {
    sprite = 61,
    color  = 49,
    scale  = 0.8,
}
