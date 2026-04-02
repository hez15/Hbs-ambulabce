-- English locale for hbs_ambulance
-- Access strings via Locale(key) or Locale(key, ...)

local L = {
    -- ── Death / Bleedout ─────────────────────────────────────────────────
    death_screen_title      = 'YOU ARE DOWN',
    death_screen_subtitle   = 'Wait for EMS or respawn at the hospital',
    bleedout_label          = 'Bleedout in:',
    last_stand_msg          = 'You are barely alive — crawl for help!',
    respawn_btn             = 'Respawn at Hospital',
    last_words_placeholder  = 'Leave your last words...',
    force_respawn_msg       = 'You have died.',

    -- ── Injuries ──────────────────────────────────────────────────────────
    injury_scratch          = 'Scratch',
    injury_minor            = 'Minor Wound',
    injury_fracture         = 'Fracture',
    injury_critical         = 'Critical Wound',
    body_head               = 'Head',
    body_torso              = 'Torso',
    body_left_arm           = 'Left Arm',
    body_right_arm          = 'Right Arm',
    body_left_leg           = 'Left Leg',
    body_right_leg          = 'Right Leg',

    -- ── EMS ───────────────────────────────────────────────────────────────
    revive_progress         = 'Reviving patient...',
    revive_success          = 'Patient revived successfully.',
    revive_no_item          = 'You need a defibrillator.',
    revive_not_ems          = 'Only EMS can perform this action.',
    treat_progress          = 'Treating wounds...',
    treat_success           = 'Wounds treated.',
    carry_start             = 'Carrying patient.',
    carry_stop              = 'Patient set down.',
    ems_interact_hint       = '[E] Revive   [G] Carry   [H] Treat',
    ems_dispatch_title      = 'EMS Dispatch',
    ems_dispatch_msg        = 'Person down near %s. Respond immediately!',
    no_ems_online           = 'No EMS available. NPC doctor on the way.',

    -- ── Hospital ──────────────────────────────────────────────────────────
    hospital_checkin_hint   = '[E] Check In',
    hospital_bed_hint       = '[E] Use Bed',
    hospital_menu_title     = 'Hospital Services',
    hospital_see_doctor     = 'See Doctor',
    hospital_see_doctor_desc= 'Get treated by the hospital doctor',
    hospital_pay_bills      = 'Pay Bills',
    hospital_pay_bills_desc = 'Pay outstanding medical bills',
    hospital_healing        = 'Doctor is treating you...',
    hospital_healed         = 'You have been treated and discharged.',
    hospital_bill_sent      = 'You have been billed $%s for medical services.',
    hospital_bill_paid      = 'Hospital bill of $%s paid.',
    hospital_bill_none      = 'You have no outstanding bills.',
    hospital_bill_no_funds  = 'Insufficient funds to pay bill ($%s).',
    hospital_rehab_title    = 'Addiction Rehab',
    hospital_rehab_desc     = 'Undergo treatment to reduce addiction (Cost: $%s)',
    hospital_rehab_progress = 'Undergoing rehabilitation...',
    hospital_rehab_done     = 'Rehabilitation complete. Stay clean.',

    -- ── Items ─────────────────────────────────────────────────────────────
    item_bandage_use        = 'Applying bandage...',
    item_firstaidkit_use    = 'Using first aid kit...',
    item_bloodbag_use       = 'Administering blood bag...',
    item_defibrillator_use  = 'Using defibrillator...',
    item_morphine_use       = 'Administering morphine...',
    item_painkiller_use     = 'Taking painkiller...',
    item_splint_use         = 'Applying splint...',
    item_methadone_use      = 'Taking methadone...',
    item_cooldown           = 'Wait before using this again.',
    item_no_injuries        = 'You have no treatable injuries.',
    item_not_downed         = 'Nobody downed nearby.',
    item_used               = 'Used %s.',

    -- ── Stress ────────────────────────────────────────────────────────────
    stress_high             = 'Your stress level is dangerously high!',
    adrenaline_start        = 'Adrenaline surge!',
    adrenaline_end          = 'Adrenaline wearing off...',

    -- ── Addiction ─────────────────────────────────────────────────────────
    addiction_level_none      = 'None',
    addiction_level_developing= 'Developing',
    addiction_level_moderate  = 'Moderate',
    addiction_level_severe    = 'Severe',
    addiction_level_critical  = 'Critical',
    addiction_increased       = 'You feel a growing dependency on %s.',
    withdrawal_starting       = 'You are experiencing withdrawal symptoms.',
    withdrawal_severe         = 'Severe withdrawal! You need your fix.',
    addiction_reduced         = 'Your addiction has decreased.',

    -- ── Vehicle ───────────────────────────────────────────────────────────
    stretcher_load_hint     = '[E] Load Patient',
    stretcher_unload_hint   = '[E] Unload Patient',
    stretcher_loaded        = 'Patient loaded into ambulance.',
    stretcher_unloaded      = 'Patient removed from ambulance.',
    ambulance_locked        = 'Ambulance locked — patient in transport.',
    ambulance_no_patient    = 'No patient to unload.',
}

-- Global locale accessor
function Locale(key, ...)
    local str = L[key] or ('[hbs:' .. key .. ']')
    if ... then return string.format(str, ...) end
    return str
end
