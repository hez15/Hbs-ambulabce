# HBS Ambulance

A full-featured EMS resource built on top of **qbx_ambulancejob** — one standalone resource combining all qbx EMS functionality with an advanced HBS medical system including injuries, stress, addiction, diseases, research, and drug effects.

---

## Dependencies

| Resource | Purpose |
|----------|---------|
| `qbx_core` | Player data, jobs, notifications |
| `qbx_medical` | Ped death state, laststand, writhe |
| `ox_lib` | UI, progress circles, context menus |
| `ox_inventory` | Items, armory shop |
| `ox_target` | Player interaction zones |
| `oxmysql` | Database persistence |
| `ps-dispatch` *(optional)* | EMS dispatch blips / MDT cards |
| `lb-phone` *(optional)* | Push notifications to EMS phones |

---

## Installation

1. Place the resource folder in your `resources` directory and name it `hbs_ambulance`
2. Add `ensure hbs_ambulance` to `server.cfg` **after** all dependencies
3. Start the server — the migration runner creates all database tables automatically on first run
4. Add required items to your `ox_inventory` items config (see **Items** section below)
5. Configure `config/config.lua` to match your server's preferences

> **No manual SQL required.** The auto-migration runner handles all schema creation and upgrades on every resource start.

---

## Features

### Injury System

Injuries are detected in real time by monitoring HP changes. Each hit is mapped to a **body part** (via GTA bone ID) and a **severity level** based on the damage amount.

**Body parts tracked:**
- Head, Torso, Left Arm, Right Arm, Left Leg, Right Leg

**Severity levels:**

| Severity | Damage Range | Bleed (HP/5s) | Effects |
|----------|-------------|--------------|---------|
| Scratch | 1–18 | None | Minor visual only |
| Minor | 19–40 | 1 HP | Slight movement penalty |
| Fracture | 41–70 | None | Sprint/movement impaired |
| Critical | 71+ | 3 HP | Severe penalties + slow health drain |

**How it works:**
- Injuries only **upgrade** — a scratch can become a minor wound, but treating makes it downgrade step by step
- Bleed (from minor/critical wounds) drains HP every 5 seconds — untreated wounds kill slowly
- Movement speed penalties stack with other injuries and diseases, taking the worst multiplier
- Head injuries cause blurred vision (timecycle modifier)
- Leg injuries slow sprint speed
- Injuries persist across sessions via the database

**Melee Knockout:**
When a player receives 3+ rapid small hits (each <15 dmg) while their health is in the danger zone (101–115 GHP), they are knocked down briefly instead of triggering laststand. A full-screen **Knocked Out** NUI overlay appears (orbiting stars, pulsing title, recovery progress bar) for the duration of the daze — without taking NUI focus, so the player can still look around.

If the player takes **another hit** while dazed (i.e. before they fully recover), the knockout is immediately cancelled and qbx_medical triggers laststand/death normally from the HP drop. One punch-out = temporary daze. Second punch = they go down for real.

---

### Treatment System

EMS treat wounds via **ox_target** on any player. Treatment uses a per-severity item and a minigame. Each successful treatment **downgrades** the injury one step.

**Treatment path:**
```
Critical → (morphine + surgery minigame) → Fracture
Fracture → (splint + suture minigame)   → Minor
Minor    → (bandage + treat minigame)   → Scratch
Scratch  → (bandage + easy minigame)    → Healed
```

The treat item is **always consumed** whether the minigame passes or fails.

**On success:**
- Base HP restore: +15 HP
- IV Therapy unlock (Tier 3): +75 HP total (additional 60 HP)

**Self-treatment:**
Civilians can use bandage, firstaidkit, splint, morphine, and painkiller from their inventory. A progress circle plays with an appropriate animation before the effect applies.

---

### Stress System

Stress is a 0–100 meter that builds from combat, injuries, and vehicle crashes. It decays naturally over time.

| Source | Stress Added |
|--------|-------------|
| Combat (being shot) | +2/tick |
| Taking injury | +15 |
| Vehicle crash (hard impact) | +12 |

**Effects by threshold:**

| Stress | Effect |
|--------|--------|
| 25%+ | Subtle screen shake |
| 50%+ | Screen shake + stamina drain |
| 75%+ | Larger shake + reduced accuracy |
| 90%+ | Maximum shake + panic movement |

**Reducers:** Morphine (-30), Painkiller (-15), EMS IV Therapy

---

### Addiction System

Certain items carry addiction risk. Each use rolls against a per-level chance to increase addiction. Addiction has **4 levels** plus clean (0).

**Addiction levels:**

| Level | Label | Effects (each withdrawal tick) |
|-------|-------|-------------------------------|
| 0 | Clean | None |
| 1 | Developing | Random mood swings (brief screen flash) |
| 2 | Moderate | Hand tremors (screen jitter), -5% speed |
| 3 | Severe | Tremors, -10% speed, visual distortion |
| 4 | Critical | All above + -20% speed + health drain + vomiting |

**Withdrawal** starts after `withdrawalDelay` minutes (default: 30) since last use of that substance. Effects fire every `withdrawalTickRate` seconds (default: 60). Withdrawal stops when the player uses the substance again or reduces their addiction level.

**Addictive items and their substances:**

| Item | Substance | Addiction Chance (Level 0) |
|------|-----------|---------------------------|
| Morphine | morphine | 10% |
| Painkiller | painkiller | 5% |
| Cocaine | cocaine | 20% |
| Methamphetamine | meth | 30% |
| Heroin | heroin | 35% |
| Weed | weed | 3% |
| Ecstasy | ecstasy | 10% |
| Vodka | alcohol | 5% |
| Beer | alcohol | 2% |

Addiction chance **increases with existing level** — a level 3 addict has a much higher roll on each use.

**Treatment:**
- `methadone` (self-use) — reduces addiction by 1 level
- EMS **Administer Detox** (Tier 3) — reduces all substances by 1 (consumes 1 methadone)
- EMS **Full Detox Treatment** (Tier 4) — clears all addiction completely (consumes 2 methadone)

**External drug compatibility:**
`HBSConfig.SubstanceEventHooks` maps third-party drug script server events to HBS substances. Uncomment and configure the example to hook into `md-drugs`, `qb-drugs`, or any custom drug resource.

---

### Drug System

Drugs trigger a **timed high** followed by a **come-down**. Effects apply during the high and fade naturally.

| Drug | Duration | Come-Down | Key Effects |
|------|----------|-----------|-------------|
| Cocaine | 5 min | 2 min | +18% speed, -30 stress, paranoia |
| Meth | 10 min | 5 min | +25% speed, slow HP regen, paranoia |
| Heroin | 8 min | 4 min | -15% speed, -50 stress, heals scratches |
| Weed | 4 min | 1 min | -8% speed, -40 stress, wobbly vision |
| Ecstasy | 7 min | 3 min | +10% speed, -60 stress |
| Vodka | 4 min | 2 min | -18% speed, drunk walk clipset |
| Beer | 2 min | 1 min | -8% speed, mild drunk effect |

Drunk effects (vodka/beer) apply GTA's stumble walk clipset and the `DrunkEffect` animation post-FX.

---

### Disease System

Diseases spread between players and progress through stages, applying debuffs at each stage.

**Available diseases:**

| Disease | Stages | Spreads | Treat Item | Spread Radius |
|---------|--------|---------|------------|---------------|
| Influenza | 3 | Yes | antibiotic | 5m |
| Wound Infection | 2 | No | antibiotic | — |

**Wound infection** has a chance to trigger automatically after sustaining a critical (15%) or fracture (6%) injury.

**Disease progression:**
Each disease advances one stage every `progressTime` seconds (default: 10 min for flu, 15 min for infection) unless treated.

**Stage effects — Influenza:**
| Stage | Effects |
|-------|---------|
| 1 | Coughing, -3% speed |
| 2 | Coughing, -7% speed |
| 3 | Coughing, -12% speed, screen shake |

**Stage effects — Wound Infection:**
| Stage | Effects |
|-------|---------|
| 1 | -5% speed |
| 2 | -10% speed, fever flashes |

**EMS workflow:**
1. **Collect Disease Sample** (ox_target on any infected player — downed or standing)
2. Take sample to the **Research Terminal** at the EMS base
3. Analyze sample (consumes it, adds to server-wide research counter)
4. Once enough samples are collected, disease is fully researched
5. **Examine Patient** (Tier 2) — see active diseases and stages
6. **Treat** via the examine menu — consumes one antibiotic

---

### EMS Research System

EMS earn XP through medical work and progress through 5 tiers, unlocking advanced capabilities.

**XP Rewards:**
| Action | XP |
|--------|----|
| Revive patient | +75 |
| Treat wounds | +30 |
| Transport to hospital | +50 |

**Research Tiers:**

| Tier | Label | XP | Unlocks |
|------|-------|----|---------|
| 1 | EMT | 0 | Basic revive, armory access |
| 2 | Paramedic | 500 | Rapid Revive (-30% CPR taps), Patient Examination |
| 3 | Senior Paramedic | 1,500 | Trauma Splint, IV Therapy (+75 HP on treat), Addiction Therapy |
| 4 | Lead Medic | 3,500 | Full Surgery, Adrenaline Revive, Full Detox |
| 5 | Chief of Medicine | 7,000 | Hands-Only Revive (no defibrillator, 3 min cooldown), Mass Casualty Alert |

**Ability descriptions:**
- **Rapid Revive** — CPR compression target reduced from 12 to 8 presses
- **Patient Examination** — Inspect a player's injuries, stress, addiction, and diseases
- **Trauma Splint** — Treat fractures without a splint item
- **IV Therapy** — Successful treatment restores 75 HP (vs 15 base)
- **Addiction Therapy** — Administer detox injection; reduces patient addiction by 1 level per substance
- **Full Surgery** — Clears ALL injuries at once (hard 20s minigame)
- **Adrenaline Revive** — Revived player receives -50 stress + full HP instead of barely-alive
- **Full Detox** — Completely clears all substance addiction (hard minigame, costs 2 methadone)
- **Hands-Only Revive** — Revive without defibrillator; 3-minute cooldown
- **Mass Casualty Alert** — Broadcast emergency to all online EMS (5-minute cooldown)

**Research Terminal** is an ox_target sphere zone at the EMS base. Open it to view your tier/XP, all abilities with unlock status, active disease outbreaks, and sample analysis progress.

---

### Revive System

**EMS revive** is a two-phase minigame:
1. **CPR** — Press `E` rapidly to the target count (12 normal, 8 with Rapid Revive)
2. **Defib shock** — Precision bar minigame (easy with Rapid Revive, medium otherwise)

Both phases play appropriate animations from the `missambulance` dict.

**Civilian revive options:**
- **First Aid Kit** — 20-second progress bar on downed player (no minigame). 5% success chance. On success, player revives at barely-alive HP (106 GHP) with all injuries intact — they still need EMS.
- **CPR** — 15-second animation (missambulance dict). 5% success chance. Same barely-alive outcome as above. The low odds reflect untrained bystander CPR — better than nothing, but far from reliable.

**On failed minigame:** a small HP penalty is applied to the patient (-15 for revive, -8 for treat).

---

### Carry & Stretcher

EMS can pick up and carry downed patients. When carrying begins, a **stretcher prop** (`prop_amb_stretcher_01`) attaches to the EMS's hand. A "Put Down Patient" option appears via ox_target on the carried ped.

**Transport XP:** When an EMS enters a vehicle while carrying a patient, +50 XP is awarded once per carry.

---

### Knockout Screen

When a melee knockout fires, a full-screen NUI overlay appears for ~5 seconds:
- Dark radial vignette (no NUI focus — player keeps mouse control and can look around)
- **KNOCKED OUT** pulsing title with yellow glow
- Five stars orbiting in a circle animation
- Recovery progress bar filling over the daze duration

The overlay hides automatically when the bar completes, or immediately if the player takes a second hit and transitions to laststand.

---

### Death Screen

When downed, a full-screen NUI overlay appears:
- Bleedout countdown timer (forced respawn when it expires)
- **Last words** text field
- **Respawn** button — triggers hospital respawn + billing
- **Force respawn** when timer expires

EMS receive a dispatch alert (ps-dispatch + lb-phone) when a player goes down.

---

### Dispatch & lb-phone

When a civilian goes down:
- **ps-dispatch**: creates a blinking map blip + MDT card for all online EMS
- **lb-phone**: sends a push notification to every on-duty EMS phone

Mass Casualty Alerts use the same channels with a different code (MCI).

Toggle integrations in `config/config.lua`:
```lua
HBSConfig.Integrations = {
    psDispatch = true,
    lbPhone    = true,
}
```

---

### Garage (Vehicle Spawn)

Each vehicle and helicopter spawn location automatically spawns a **dispatcher NPC** (`s_m_y_ems_01`) standing 3m beside it. The ped is:
- Invincible and frozen in place
- Playing a clipboard idle scenario
- Targetable via ox_target ("Request Vehicle") — on-duty EMS only

Selecting a vehicle from the menu spawns it at the configured spawn point and teleports the EMS into the driver seat. Both ground-unit and helicopter bays each get their own dispatcher ped.

The walk-in zone (stand inside the box and press `E`) is retained as a fallback.

When requesting a vehicle while already in one, the current vehicle is deleted first.

---

### HUD

The SVG medical HUD displays in the top-left while on duty:
- Body diagram with colour-coded injury severity per part
- Stress bar
- Addiction bar (hidden when clean)
- Status icons: bloodloss, pain, withdrawal, disease

**Severity colours:**
- Yellow — Scratch
- Orange — Minor
- Blue — Fracture
- Red (pulsing) — Critical

---

## Medical Items

| Item | Effect | Armory |
|------|--------|--------|
| `bandage` | Heals scratch/minor injuries | ✓ |
| `firstaidkit` | Heals scratch/minor/fracture, +30 HP, civilian revive | ✓ |
| `bloodbag` | Restores 50 HP | ✓ |
| `defibrillator` | EMS revive tool, self-revive | ✓ |
| `morphine` | Heals critical/fracture, -30 stress, +20 HP — addictive | ✓ |
| `painkiller` | -15 stress, +10 HP, withdrawal relief — addictive | ✓ |
| `splint` | Heals arm/leg fractures | ✓ |
| `methadone` | Reduces addiction by 1 level | ✓ |
| `antibiotic` | EMS treats diseases (flu, infection) | ✓ |
| `disease_sample` | Collected by EMS from infected patients; analysed at Research Terminal | — |
| `vodka` | Drunk effect (4 min), -18% speed, -25 stress | — |
| `beer` | Mild drunk (2 min), -8% speed, -15 stress | — |

To make items useable, add to each item in `ox_inventory` items config:
```lua
client = { event = 'hbs_ambulance:client:useItem' }
```

**New items to add to ox_inventory:**
```lua
['antibiotic'] = {
    label = 'Antibiotic',
    weight = 50,
    stack = true,
    close = true,
    description = 'Treats bacterial infections and disease.',
    client = { event = 'hbs_ambulance:client:useItem' },
},
['disease_sample'] = {
    label = 'Disease Sample',
    weight = 100,
    stack = false,
    close = true,
    description = 'A biological sample collected from an infected patient. Analyse at the Research Terminal.',
},
['vodka'] = {
    label = 'Vodka',
    weight = 300,
    stack = true,
    close = true,
    description = 'Strong spirit. Impairs movement.',
    client = { event = 'hbs_ambulance:client:useItem' },
},
['beer'] = {
    label = 'Beer',
    weight = 200,
    stack = true,
    close = true,
    description = 'A cold one. Mild impairment.',
    client = { event = 'hbs_ambulance:client:useItem' },
},
```

---

## Configuration

All HBS settings are in `config/config.lua` under the `HBSConfig` namespace.

| Key | Description |
|-----|-------------|
| `HBSConfig.Debug` | Enable debug prints (client F8 + server console) |
| `HBSConfig.DamageThresholds` | HP ranges per severity level |
| `HBSConfig.InjurySeverity` | Per-severity bleed rate and health drain |
| `HBSConfig.InjuryEffects` | Per-body-part speed/vision penalties |
| `HBSConfig.TreatMap` | Per-severity treat item, minigame theme, difficulty |
| `HBSConfig.Stress` | Decay rate, tick rate, effect thresholds |
| `HBSConfig.Addiction` | Withdrawal delay, tick rate, level labels, effects |
| `HBSConfig.Substances` | Addictive substance definitions + addiction chances |
| `HBSConfig.SubstanceEventHooks` | Hooks into external drug script events |
| `HBSConfig.MedicalItems` | Item use times, heal effects, addiction config |
| `HBSConfig.Drugs` | Drug high/come-down durations and screen effects |
| `HBSConfig.Diseases` | Disease stages, spread radius, progression time |
| `HBSConfig.ResearchTerminal` | World coords for the research terminal sphere |
| `HBSConfig.EMSResearch` | Tier XP thresholds, XP rewards, ability definitions |
| `HBSConfig.Dispatch` | ps-dispatch call definitions |
| `HBSConfig.Integrations` | Toggle ps-dispatch / lb-phone |

Original qbx_ambulancejob vehicle/grade config remains in `config/client.lua` and location data in `config/shared.lua`.

---

## Commands

| Command | Access | Description |
|---------|--------|-------------|
| `/revive [id]` | Console / EMS job | Revive a player immediately |

---

## Database Tables

| Table | Contents |
|-------|----------|
| `hbs_injuries` | Per-player injury state (body_part + severity) |
| `hbs_stress` | Per-player stress level |
| `hbs_addiction` | Per-player addiction per substance |
| `hbs_ems_research` | EMS tier, XP, and unlocks per player |
| `hbs_diseases` | Per-player active disease and stage |
| `hbs_wills` | Saved last words from death screen |
| `hbs_meta` | Schema version tracker (managed by migration runner) |

All tables are created automatically on first server start via the migration runner in `server/sv_migrations.lua`. No manual SQL is required.

---

## EMS ox_target Options (at a glance)

All options appear via **ox_target** on player peds. Visibility is gated by job/unlock checks.

| Option | Who Sees It | Condition |
|--------|-------------|-----------|
| Revive Patient | EMS only | Target is downed |
| Treat Wounds | EMS only | Any player |
| Examine Patient | EMS Tier 2+ | Any player |
| Check Vitals | EMS only | Target is alive |
| Triage Patient | EMS only | Target is downed |
| Carry Patient | EMS only | Target is downed, not already carrying |
| Administer Detox | EMS Tier 3+ | Any player |
| Full Detox Treatment | EMS Tier 4+ | Any player |
| Full Surgery | EMS Tier 4+ | Target is downed |
| Mass Casualty Alert | EMS Tier 5+ | Any (distance 99) |
| Collect Disease Sample | EMS only | Target has active disease |
| Perform CPR | Civilians only | Target is downed |
| Revive with First Aid Kit | Civilians only | Target is downed + has firstaidkit |
