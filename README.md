# HBS Ambulance

A full-featured EMS resource built on top of **qbx_ambulancejob** — one standalone resource combining all qbx EMS functionality with the HBS advanced medical system.

---

## Dependencies

| Resource | Purpose |
|----------|---------|
| `qbx_core` | Player data, jobs, notifications |
| `qbx_medical` | Ped death state, laststand, writhe |
| `ox_lib` | UI, progress circles, context menus |
| `ox_inventory` | Items, crafting ingredient management |
| `ox_target` | Player interaction zones |
| `oxmysql` | Database persistence |

---

## Installation

1. Place the resource folder in your `resources` directory and name it `hbs_ambulance`
2. Run `sql/hbs_ambulance.sql` on your database
3. Add `ensure hbs_ambulance` to your `server.cfg` **after** all dependencies
4. Add the medical supply ingredients to your `ox_inventory` items (see Crafting section)

---

## Features

### Injury System
Injuries are tracked per body part with four severity levels:

| Severity | Effects |
|----------|---------|
| Scratch | Minor visual only |
| Minor | Slight movement penalty |
| Fracture | Movement/sprint impaired, requires splint |
| Critical | Severe penalties, requires surgery to clear |

Body part damage is shown on the SVG HUD (top-left). Injuries persist across sessions via the database.

---

### Stress System
- Builds from combat, injury, and drug withdrawal
- Decays naturally over time
- High stress causes screen shake and stamina drain
- Reduced by morphine, painkiller, and EMS treatment

---

### Addiction System
Certain medical items carry addiction risk. Addiction has 4 levels:

| Level | Label | Effects |
|-------|-------|---------|
| 1 | Developing | Random mood swings (screen flash) |
| 2 | Moderate | Hand tremors, -5% speed |
| 3 | Severe | Tremors, -10% speed, visual distortion |
| 4 | Critical | All above + health drain + vomiting |

**Addictive items:** Morphine, Painkiller

**Treatment items:**
- `methadone` — reduces addiction by 1 level, self-use
- EMS `Administer Detox` — reduces all substances by 1 level (requires Tier 3 research)
- EMS `Full Detox Treatment` — completely clears all addiction (requires Tier 4 research)

---

### Medical Items

| Item | Effect |
|------|--------|
| `bandage` | Heals scratch/minor injuries |
| `firstaidkit` | Heals scratch/minor/fracture, +30 HP |
| `bloodbag` | Restores 50 HP |
| `defibrillator` | Self-revive / EMS revive tool |
| `morphine` | Heals critical/fracture, -30 stress, +20 HP — addictive |
| `painkiller` | -15 stress, +10 HP, withdrawal relief — addictive |
| `splint` | Heals arm/leg fractures |
| `methadone` | Reduces addiction by 1 level |

To make items useable, add the following to each item in your `ox_inventory` items.lua:
```lua
client = { event = 'hbs_ambulance:client:useItem' }
```

---

### EMS Research System

EMS players earn XP through active medical work and progress through 5 tiers, unlocking better tools at each level.

**XP Rewards**
| Action | XP |
|--------|----|
| Revive patient | +75 |
| Treat wounds | +30 |
| Transport to hospital | +50 |
| Craft item | +15 |

**Research Tiers & Unlocks**

| Tier | Label | XP Required | Unlocks |
|------|-------|-------------|---------|
| 1 | EMT | 0 | Basic revive, basic crafting |
| 2 | Paramedic | 500 | Rapid Revive (-30% time), Patient Examination, Tier 2 crafting |
| 3 | Senior Paramedic | 1,500 | Trauma Splint, IV Therapy (+75 HP on treat), Addiction Therapy, Tier 3 crafting |
| 4 | Lead Medic | 3,500 | Full Surgery (clears all injuries), Adrenaline Revive, Full Detox, Tier 4 crafting |
| 5 | Chief of Medicine | 7,000 | Hands-Only Revive (no defibrillator, 3min cooldown), Mass Casualty Alert, Tier 5 crafting |

**Patient Examination** (Tier 2): When examining a downed player you can see their exact injuries, stress level, and addiction state.

**Adrenaline Revive** (Tier 4): Revived patient receives -50 stress and full HP instead of a barely-alive revive.

---

### Crafting System

EMS can craft medical items at the crafting table located at the EMS base (configurable in `HBSConfig.CraftingTable`). Recipes are locked behind research tiers.

**Tier 1 — EMT**
| Output | Ingredients |
|--------|------------|
| Bandage ×3 | med_gauze ×2, med_tape ×1 |
| Painkiller ×2 | med_pills ×3 |

**Tier 2 — Paramedic**
| Output | Ingredients |
|--------|------------|
| Splint ×1 | med_gauze ×3, med_tape ×2, med_rod ×1 |
| Morphine ×1 | med_syringe ×1, med_opioid ×2 |

**Tier 3 — Senior Paramedic**
| Output | Ingredients |
|--------|------------|
| First Aid Kit ×1 | bandage ×2, med_gauze ×4, med_tape ×2, med_pills ×2 |
| Methadone ×2 | med_syringe ×1, med_detox ×3 |
| Blood Bag ×1 | med_bloodpack ×1, med_tube ×1 |

**Tier 4 — Lead Medic**
| Output | Ingredients |
|--------|------------|
| Defibrillator ×1 | med_defib_pad ×2, med_battery ×1, med_tube ×1 |
| Surgical Kit ×1 | med_scalpel ×1, med_gauze ×5, med_syringe ×2, med_opioid ×3 |

**Tier 5 — Chief of Medicine**
| Output | Ingredients |
|--------|------------|
| Advanced Surgical Pack ×1 | surgical_kit ×1, bloodbag ×1, morphine ×1, med_detox ×2 |

**Required ingredient items to add to ox_inventory:**
`med_gauze`, `med_tape`, `med_pills`, `med_rod`, `med_syringe`, `med_opioid`, `med_detox`, `med_bloodpack`, `med_tube`, `med_defib_pad`, `med_battery`, `med_scalpel`

---

### HUD

The SVG medical HUD displays in the top-left corner while on duty:
- Body diagram with colour-coded injury severity per part
- Stress bar
- Addiction bar (hidden when clean)
- Status icons (bloodloss, pain, withdrawal)

**Severity colours:**
- Yellow — Scratch
- Orange — Minor
- Blue — Fracture
- Red (pulsing) — Critical

---

### Death Screen

When downed, a full-screen NUI overlay appears showing:
- Bleedout timer (countdown to force respawn)
- Last words text box
- Respawn button (triggers hospital respawn + billing)
- Force respawn option when timer expires

EMS are alerted via dispatch when a player goes down.

---

## Configuration

All HBS settings are in `config/config.lua` under the `HBSConfig` namespace.

| Key | Description |
|-----|-------------|
| `HBSConfig.Addiction` | Withdrawal delay, tick rate, level effects |
| `HBSConfig.MedicalItems` | Item use times, heal effects, addiction chance |
| `HBSConfig.EMSResearch` | Tier XP thresholds, ability definitions |
| `HBSConfig.Crafting` | Recipes, ingredients, craft times |
| `HBSConfig.CraftingTable` | World coords for the crafting table target zone |

The original qbx_ambulancejob configuration remains in `config/client.lua` and `config/shared.lua`.

---

## Commands

| Command | Access | Description |
|---------|--------|-------------|
| `/revive [id]` | Console / EMS job | Revive a player |

---

## Database Tables

| Table | Contents |
|-------|----------|
| `hbs_injuries` | Per-player injury state (part + severity) |
| `hbs_stress` | Per-player stress level |
| `hbs_addiction` | Per-player addiction per substance |
| `hbs_ems_research` | EMS tier, XP, and unlocks per player |
