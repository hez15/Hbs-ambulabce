# hbs_ambulance

Advanced medical system for FiveM servers running QBX Core. Replaces the default death and injury system with a full EMS workflow including body-part injuries, bleedout timers, medical items, stress/trauma, addiction, and a 5-tier EMS research progression.

---

## Dependencies

| Resource | Purpose |
|---|---|
| `qbx_core` | Framework / player data |
| `ox_lib` | UI (progress bars, context menus, notifications) |
| `ox_target` | Third-eye targeting for EMS interactions |
| `ox_inventory` | Medical items |
| `oxmysql` | Database |

---

## Installation

1. Drop the `hbs_ambulance` folder into your `resources` directory.
2. Run `sql/hbs_ambulance.sql` against your database.
3. Add the medical items to your `ox_inventory` items file — see `ITEMS.md` for the full definitions.
4. Add `ensure hbs_ambulance` to your `server.cfg` (after all dependencies).
5. Grant the admin ace permission if you want to use admin commands:
   ```
   add_ace group.admin hbs_ambulance.admin allow
   ```

---

## Configuration

All settings live in `config/config.lua`. Key options:

| Option | Default | Description |
|---|---|---|
| `Config.EmsJob` | `'ambulance'` | Job name that grants EMS abilities |
| `Config.MinEmsOnline` | `1` | EMS needed online before NPC doctors activate |
| `Config.ReviveRequiresItem` | `false` | Require a defibrillator item to revive |
| `Config.ReviveItem` | `'defibrillator'` | Item consumed on revive (if above is true) |
| `Config.LastStandTime` | `60` | Seconds of crawl/last-stand before bleedout begins |
| `Config.BleedoutTime` | `300` | Additional seconds before forced death (5 min) |
| `Config.DeathBill.baseAmount` | `2500` | Hospital bill on self-respawn |
| `Config.DeathBill.emsBonusDiscount` | `0.50` | Bill discount when revived by EMS |
| `Config.DamageThresholds` | see below | Damage → injury severity mapping |
| `Config.NPCHealEnabled` | `true` | NPC auto-heals when no EMS is online |
| `Config.NpcHealCost` | `1500` | Cost for NPC treatment |
| `Config.AdrenalineDuration` | `20` | Seconds of adrenaline boost after EMS revive |

### Damage Thresholds

Controls what severity injury is applied based on incoming damage. Defaults are tuned so fistfights only cause scratches/minor wounds:

```lua
Config.DamageThresholds = {
    { min = 1,  max = 18,  severity = 'scratch'  },
    { min = 19, max = 40,  severity = 'minor'    },
    { min = 41, max = 70,  severity = 'fracture' },
    { min = 71, max = 999, severity = 'critical' },
}
```

---

## Features

### Injuries & Body Parts

Damage is tracked per body part (head, torso, left/right arm, left/right leg). Each hit records a severity based on the damage thresholds above. Injuries persist to the database and are restored on reconnect.

**Severity effects:**

| Severity | Bleed Rate | HP Drain | Notes |
|---|---|---|---|
| Scratch | None | None | Visual only |
| Minor | 1/tick | 0.5/s | Minor blood loss |
| Fracture | None | None | Movement/weapon penalties |
| Critical | 3/tick | 2/s | Severe ongoing damage |

**Per-part gameplay effects:**

| Part | Effect |
|---|---|
| Head | Blurred vision, reduced controls |
| Torso | Impaired breathing, -20% speed |
| Arms | Weapon sway, slow reload |
| Legs | Limp, -40% speed |

### Death & Last Stand

When health hits 0:
1. Player enters **last stand** (crawl animation, invincible to prevent GTA's native death screen).
2. A countdown timer is shown in the HUD — EMS can revive during this window.
3. After `LastStandTime` seconds, bleedout begins.
4. After the full timer expires the player is forced to respawn at the nearest hospital.

A death bill is automatically charged. EMS revives grant a 50% discount.

### Medical HUD

A transparent SVG body diagram appears in the top-left of the screen. Body parts glow when injured, with colour/intensity reflecting severity. The HUD dims to near-invisible when the player is healthy.

### Medical Items

See `ITEMS.md` for full item definitions to paste into ox_inventory.

| Item | Effect |
|---|---|
| `bandage` | Heals scratch / minor wounds |
| `firstaidkit` | Heals scratch / minor / fracture + 30 HP |
| `bloodbag` | Restores 50 HP |
| `defibrillator` | Revives a downed player |
| `morphine` | Heals critical/fracture, -30 stress, +20 HP. Addictive |
| `painkiller` | -15 stress, +10 HP. Mildly addictive |
| `splint` | Heals fractures on limbs only |
| `blood_test_kit` | EMS-only: reveals patient addiction/injury data |
| `methadone` | Reduces addiction level by 1 |

### Stress / Trauma

Stress builds during combat, crashes, injuries, and witnessing deaths. High stress applies progressive screen shake, stamina drain, reduced accuracy, and panic effects. Stress decays naturally when calm and is reduced by certain medical items.

### Addiction

Morphine and painkillers carry addiction risk. Addiction level (0–4) worsens withdrawal symptoms after the substance wears off:

| Level | Label | Effects |
|---|---|---|
| 0 | None | — |
| 1 | Developing | Mood swings |
| 2 | Moderate | Hand tremors, -5% speed |
| 3 | Severe | Tremors, -10% speed, visual distortion |
| 4 | Critical | Tremors, -20% speed, distortion, vomit, HP drain |

Treatment: hospital rehab costs $5,000 and reduces addiction to level 1 over 30 minutes. Methadone and blood test kits can also be used by EMS.

---

## EMS System

### Third-Eye Actions

EMS players (job: `ambulance`) can third-eye any player to access:

| Action | Condition |
|---|---|
| Revive Patient | Target is downed |
| Treat Wounds | Always visible to EMS |
| Carry Patient | Target is downed, not already carried |
| Triage Patient | Target is downed |
| Patient Examination | Tier 2+ unlock |
| Administer Medication | Tier 3+ unlock |
| Full Surgery | Tier 4+ unlock, target is downed |

### Triage System

EMS can mark downed players with a triage colour:

| Colour | Level |
|---|---|
| Red | Critical |
| Orange | Moderate |
| Yellow | Minor |

Triage tags appear on the EMS map blip for downed players.

### EMS Research Progression

EMS players earn XP through actions and unlock abilities at a hospital research terminal.

**XP Rewards:**

| Action | XP |
|---|---|
| Revive | 75 |
| Treat wounds | 30 |
| Transport patient | 50 |
| Passive duty (per 5 min) | 10 |
| First responder bonus | 25 |
| Blood test | 20 |
| Addiction treatment | 40 |

**Tiers & Unlocks (pick 2 per tier):**

| Tier | Label | XP Required | Available Unlocks |
|---|---|---|---|
| 1 | EMT | 0 | — |
| 2 | Paramedic | 500 | Rapid Revive, Patient Examination, Dispatch Intel |
| 3 | Senior Paramedic | 1,500 | Med Administration, IV Therapy, Trauma Splint |
| 4 | Lead Medic | 3,500 | Full Surgery, Adrenaline Revive, Advanced Carry |
| 5 | Chief of Medicine | 7,000 | Hands-Only Revive, Mentor, Mass Casualty Alert |

Unlocks are selected at a research terminal inside each hospital.

---

## Hospital Locations

| Hospital | Coords |
|---|---|
| Pillbox Medical Center | 295.6, -584.4, 43.3 |
| Sandy Shores Medical | 1839.6, 3672.4, 34.3 |
| Paleto Bay Medical | -246.0, 6331.0, 32.4 |

Each hospital has a research terminal, NPC doctor (active when no EMS online), and hospital bed interaction points.

---

## Database Tables

| Table | Contents |
|---|---|
| `hbs_injuries` | Per-citizen body part injuries |
| `hbs_bills` | Hospital bills (paid/unpaid) |
| `hbs_stress` | Stress levels |
| `hbs_addiction` | Substance addiction levels and usage history |
| `hbs_ems_research` | EMS XP, tier, and unlocked abilities |

---

## Admin Commands

All commands require the `hbs_ambulance.admin` ace permission (or server console).

| Command | Usage | Description |
|---|---|---|
| `/revive` | `/revive [playerid]` | Force-revive a player, clearing downed state and death screen |
| `/setemstier` | `/setemstier [playerid] [1-5]` | Set an EMS player's research tier |
| `/setemsxp` | `/setemsxp [playerid] [amount]` | Set an EMS player's XP total |
| `/resetems` | `/resetems [playerid]` | Reset EMS research data to tier 1 |
| `/viewems` | `/viewems [playerid]` | Print EMS tier/XP/unlocks to console |

---

## File Structure

```
hbs_ambulance/
├── client/
│   ├── cl_main.lua          # Bootstrap, framework hooks, shared state
│   ├── cl_hud.lua           # HUD updates
│   ├── cl_death.lua         # Last stand, bleedout, death screen, respawn
│   ├── cl_injury.lua        # Damage detection, injury effects
│   ├── cl_ems.lua           # EMS targeting, revive, treat, carry
│   ├── cl_ems_research.lua  # Research menu, tier-up notifications
│   ├── cl_ems_terminal.lua  # Hospital research terminal interaction
│   ├── cl_hospital.lua      # Hospital zones, NPC interaction, beds
│   ├── cl_items.lua         # Medical item use handlers
│   ├── cl_stress.lua        # Stress effects
│   ├── cl_addiction.lua     # Addiction/withdrawal effects
│   └── cl_vehicle.lua       # Ambulance/stretcher interactions
├── server/
│   ├── sv_database.lua      # All DB read/write helpers
│   ├── sv_main.lua          # Callbacks, player state on load
│   ├── sv_death.lua         # Downed blips, death record
│   ├── sv_injury.lua        # Injury save on damage event
│   ├── sv_ems.lua           # Revive, treat, carry, triage events
│   ├── sv_ems_research.lua  # XP, tier progression, unlocks, admin cmds
│   ├── sv_hospital.lua      # Respawn, bills, NPC heal
│   ├── sv_items.lua         # Item use server-side logic
│   ├── sv_stress.lua        # Stress save/load
│   └── sv_addiction.lua     # Addiction save/load
├── shared/
│   └── sh_utils.lua         # Shared utilities, injury definitions, state bags
├── config/
│   └── config.lua           # All configuration
├── locales/
│   └── en.lua               # English locale strings
├── ui/
│   ├── index.html           # NUI (death screen + medical HUD)
│   ├── style.css
│   └── script.js
├── sql/
│   └── hbs_ambulance.sql    # Database schema
├── fxmanifest.lua
├── README.md
└── ITEMS.md                 # ox_inventory item definitions
```
