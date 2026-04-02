# HBS Ambulance — Medical Items Reference

All items are registered via `ox_inventory` and defined in `config/config.lua` under `Config.MedicalItems`.

---

## Item List

### Bandage (`bandage`)

| Property | Value |
|---|---|
| Use time | 5 seconds |
| Heals severity | Scratch, Minor |
| Body parts | Any |

Applies a basic bandage to the worst eligible wound on the player. Does not restore health directly. Self-use only.

---

### First Aid Kit (`firstaidkit`)

| Property | Value |
|---|---|
| Use time | 10 seconds |
| Heals severity | Scratch, Minor, Fracture |
| Body parts | Any |
| Health restore | +30 HP |

More capable than a bandage — handles fractures and partially restores health. Self-use only.

---

### Blood Bag (`bloodbag`)

| Property | Value |
|---|---|
| Use time | 15 seconds |
| Health restore | +50 HP |

Restores a significant amount of health. Does not treat injuries directly. Self-use only.

---

### Defibrillator (`defibrillator`)

| Property | Value |
|---|---|
| Use time | 8 seconds |
| Can revive downed players | Yes |
| Requires EMS job | No (configurable) |

Used on a downed player to revive them. To require EMS job, set `requiresEms = true` in config. If `Config.ReviveRequiresItem = true`, EMS must have this item in their inventory to perform a revive.

---

### Morphine (`morphine`)

| Property | Value |
|---|---|
| Use time | 4 seconds |
| Heals severity | Critical, Fracture |
| Body parts | Any |
| Stress reduce | -30 |
| Health restore | +20 HP |
| Addictive | Yes |
| Substance | `morphine` |

Powerful painkiller for serious injuries. Carries significant addiction risk that grows with dependency level.

**Addiction chances per level:**

| Dependency Level | Chance per use |
|---|---|
| 0 — None | 10% |
| 1 — Developing | 25% |
| 2 — Moderate | 40% |
| 3 — Severe | 60% |
| 4 — Critical | 80% |

---

### Painkiller (`painkiller`)

| Property | Value |
|---|---|
| Use time | 3 seconds |
| Stress reduce | -15 |
| Health restore | +10 HP |
| Addictive | Yes |
| Substance | `painkiller` |
| Withdrawal relief | Yes |

Lighter painkiller with lower addiction risk. Also temporarily suppresses withdrawal symptoms.

**Addiction chances per level:**

| Dependency Level | Chance per use |
|---|---|
| 0 — None | 5% |
| 1 — Developing | 15% |
| 2 — Moderate | 25% |
| 3 — Severe | 40% |
| 4 — Critical | 60% |

---

### Splint (`splint`)

| Property | Value |
|---|---|
| Use time | 8 seconds |
| Heals severity | Fracture |
| Body parts | Left Leg, Right Leg, Left Arm, Right Arm |

Specifically treats fractured limbs. Removes the speed/weapon-handling penalties caused by fractures. Cannot be used on head or torso fractures.

---

### Methadone (`methadone`)

| Property | Value |
|---|---|
| Use time | 5 seconds |
| Withdrawal relief | Yes |
| Reduces addiction level | Yes (-1 level) |

Used to treat substance dependency. Relieves active withdrawal symptoms and reduces the player's addiction level by 1. Typically dispensed by EMS via the **Administer Medication** ability (unlocked at Paramedic tier). Has a 20-minute per-patient cooldown when used by EMS.

---

### Blood Test Kit (`blood_test_kit`)

| Property | Value |
|---|---|
| Use time | 8 seconds |
| Requires EMS job | Yes |
| Awards EMS XP | +20 XP |

**EMS-only item.** Used on a nearby patient (within 3 metres) to reveal their full addiction profile. Results are shown in a context menu listing each substance and its current dependency level. One item is consumed per test.

---

## Addiction System

Addiction is tracked per player, per substance, in the `hbs_addiction` database table.

### Levels

| Level | Label |
|---|---|
| 0 | None |
| 1 | Developing |
| 2 | Moderate |
| 3 | Severe |
| 4 | Critical |

### Effects by level

| Level | Effects |
|---|---|
| 1 | Mood swings |
| 2 | Hand tremors, -5% movement speed |
| 3 | Hand tremors, -10% speed, visual distortion |
| 4 | Tremors, -20% speed, visual distortion, vomiting, gradual health drain |

### Withdrawal

Withdrawal begins `Config.Addiction.withdrawalDelay` minutes (default: 30) after the player's last use of an addictive substance. Withdrawal effects tick every 60 seconds and show the withdrawal icon (`🥵`) on the HUD.

### Treatment

| Method | Details |
|---|---|
| Painkiller | Temporarily suppresses symptoms, does not reduce level |
| Methadone | Reduces addiction level by 1, suppresses withdrawal |
| Hospital rehab | Costs $5,000, takes 30 minutes, reduces level to 1 (not instant cure) |

---

## Adding Custom Items

1. Add the item definition to `Config.MedicalItems` in `config/config.lua`:

```lua
Config.MedicalItems['my_item'] = {
    label        = 'My Item',
    useTime      = 5,                  -- progress bar duration in seconds
    heals        = { 'scratch' },      -- optional: severities this heals
    healParts    = { 'any' },          -- optional: body parts it applies to
    healthRestore= 20,                 -- optional: flat HP restore
    stressReduce = 10,                 -- optional: stress reduction
    addictive    = false,              -- optional: triggers addiction roll
    requiresEms  = false,              -- optional: restrict to EMS job
    animation    = { dict = 'mp_suicide', anim = 'pill', flag = 49 },
    notification = 'You used my item.',
}
```

2. Register the item in ox_inventory (via `items.lua` or your server's item definitions):

```lua
['my_item'] = {
    label  = 'My Item',
    weight = 100,
    stack  = true,
    close  = true,
    image  = 'my_item.png',
}
```

3. The item will be automatically picked up by `cl_items.lua`'s generic use handler. No additional Lua is required unless the item has special behaviour (like `blood_test_kit`).

---

## ox_inventory Registration

Items are registered on resource start in `server/sv_items.lua`:

```lua
exports.ox_inventory:RegisterStacks({
    ['bandage']       = { label = 'Bandage',       ... },
    ['firstaidkit']   = { label = 'First Aid Kit', ... },
    -- etc.
})
```

Item images should be placed in `ox_inventory/web/images/` as `<item_name>.png`.
