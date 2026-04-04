# Changelog — HBS Ambulance

All notable changes to this project are documented in this file.

---

## [Unreleased] — 2026-04-04 (session 3)

### Bug Fixes
- **`cl_ems.lua`** — Added `reviveActive` lock flag to `Revive()` — without it ox_target could fire the function twice; the second call hit `_mgActive` guard inside `RunMinigame`, returned false immediately, and incorrectly triggered `minigameFailed` (dealing 15 HP damage to the patient and showing "Shock failed")
- **`cl_ems.lua`** — Preload all EMS animation dicts (`missambulance`, `mini@repair`, `mp_suicide`, `mini@crate_search@std@ps`, `move_m@drunk@a`) on `hbs:client:stateLoaded` so `LoadDict` inside `PlayAnim` is a no-op by the time the EMS interacts with a patient — eliminates the multi-second delay before the minigame appears
- **`ui/style.css`** — Removed `backdrop-filter: blur()` from `#medical-hud` and `#minigame` — FiveM's CEF cannot composite backdrop-filter against the game canvas and renders it as a solid black rectangle; replaced with a slightly more opaque background colour instead
- **`ui/style.css`** — Added `background: transparent !important` to `html, body` — CEF requires explicit transparent root to avoid rendering a page background colour over the game world
- **`sv_main_hbs.lua`** — Added `QBCore:Server:PlayerLoaded` hook (`ApplyPlayerStateBags`) that sets all state bags from DB server-side the moment the player loads — previously `HasUnlock()` returned `false` (tier 1) until the client's `getPlayerState` callback completed, meaning the first EMS action after login would see wrong tier/XP
- **`sv_main_hbs.lua`** — `getPlayerState` callback now calls `ApplyPlayerStateBags` and reads back from state bags rather than re-querying DB independently, ensuring both code paths are consistent

---

## [Unreleased] — 2026-04-04 (session 2)

### Bug Fixes
- **`cl_addiction.lua`** — Fixed `HBSNotify` argument order (was `HBSNotify('warning', msg)`, should be `HBSNotify(msg, 'warning')`)
- **`cl_addiction.lua`** — Wrapped vomit scenario + 2-minute cooldown in its own `CreateThread` so the withdrawal tick thread is no longer blocked for 2 minutes each time vomiting triggers

### Improvements
- **Debug system** — Added `HBSUtils.Debug(category, ...)` calls throughout all client and server files, gated by `HBSConfig.Debug`. Enable with `HBSConfig.Debug = true` in `config/config.lua`
  - `cl_addiction`: withdrawal tick level, state transitions, vomit cooldown
  - `cl_injury`: damage detected (bone/part/severity), injury save vs skip decision, bleed drain amount, injury clear
  - `cl_ems`: minigame start/result/timeout, Revive item & cooldown checks, TreatWounds difficulty selection, carry start/stop, transport XP trigger, research state sync
  - `cl_drugs`: high start/override/end, come-down start/end, drugEffect event receipt
  - `setdownedstate`: ShowDeathScreen, HideDeathScreen, doctor count refresh, downed state trigger with context
  - `sv_injury`: save vs skip with reason logged
  - `sv_stress`: stress value on every save
  - `sv_ems`: `HasUnlock` logs current tier, required tier, and result for every check
  - `sv_drugscompat`: addiction roll logs chance, outcome, and new level per drug use
- **`cl_ems.lua`** — `emsResearchUpdate` handler now also syncs flat `HBSState.emsTier`/`emsXP`/`emsUnlocks` so research terminal reads correct values after a server push

---

## [0.4.0] — Previous Session

### New Features
- **Full Surgery** (Tier 4) — Hard minigame, clears all injuries on success, deals HP penalty on failure
- **Hands-Only Revive cooldown** — 3-minute cooldown tracked client-side with remaining time shown on block
- **Transport XP** — EMS earns 50 XP when entering a vehicle while carrying a patient (once per patient per carry)
- **Mass Casualty Alert** (Tier 5) — Broadcasts emergency alert to all online EMS; includes camera shake, red blip, 5-minute per-EMS cooldown
- **Last Words** — Death screen text box; content saved to `hbs_wills` DB table on respawn

### Bug Fixes
- **Blip colour always red** — Triage blip colour map was broken (both branches returned `1`); fixed with explicit `{ critical=1, moderate=17, minor=2 }` map
- **Dispatch clearing all EMS blips** — `updateDownedBlips` was being called with an empty list immediately after `broadcastDownedBlips`; removed the erroneous call
- **Detox applying to self** — `administerDetox` lacked a self-target guard; added `if targetSrc == src then return end`
- **Stress state bag unclamped** — `HBS.Set` was receiving the raw (potentially out-of-range) value; now always uses the clamped variable
- **Admin `/revive` broken notify** — Was passing a table `{msg=..., type=...}` instead of positional `(ntype, msg)` args; fixed

---

## [0.3.0] — Previous Session

### New Features
- **NUI precision bar minigame** — Replaced progress circles with a custom bouncing-cursor minigame; E key detected in Lua and forwarded to JS; multiple rounds per difficulty; themed via CSS custom properties
- **Revive animations** — Two-phase animation: `treat_a_doctor` (1.2s assess) → `defib_a_doctor` (loops during minigame); `TreatWounds` uses `fixing_a_ped`
- **Player disorientation on revive** — Plays drunk idle animation for 3 seconds after being revived by EMS
- **Auto-suggest triage** — Reads `hbs:injuries` state bag from target; finds worst severity; marks the suggested triage level with ★ in the context menu
- **qbx_medical integration** — Server hooks into `qbx_medical:server:onPlayerLaststand`, `playerDied`, and `playerRespawned` to keep HBS `DownedPlayers` table in sync without requiring a separate client event

### Bug Fixes
- **HUD never showing** — Lua sent `showHud` (lowercase d); JS only matched `showHUD` (uppercase D); fixed with fallthrough cases for both spellings
- **XP showing 0 in research terminal** — `OnPlayerLoaded` set `HBSState.emsResearch` but crafting/research menus read flat `HBSState.emsTier`/`emsXP`; fixed by syncing flat fields on load
- **Examine option not showing (client)** — `HBSHasUnlock` read `.mentorTier` (nil) instead of `.tier`
- **Examine option not working (server)** — `HasUnlock` read `HBS.Get(src, 'mentorTier')` which was never set; fixed to `emsTier`
- **Drug threads surviving player unload** — Added unload handlers to nil `activeHigh`/`activeComeDown` and call `ClearHighEffects()`/`ClearComeDownEffects()`

### Improvements
- **Stumbling effect reduced** — Speed multiplier for leg injuries now scaled by severity (`SevScale`: scratch=0.1, minor=0.35, fracture=0.70, critical=1.0) instead of always applying the full penalty
- **Debug system** — Added `HBSConfig.Debug` flag and `HBSUtils.Debug(category, ...)` helper; `HBSLog()` alias for server files
- **Minigame HP penalty on failure** — Server `minigameFailed` event deducts 15 HP from patient on failed revive, 8 HP on failed treat

---

## [0.2.0] — Previous Session

### New Features
- **Health bar in HUD** — Green gradient bar, turns red at ≤25% health; updated every 2 seconds via a tick thread
- **EMS Research terminal** — Context menu at EMS base showing current tier, XP progress, and available abilities
- **Carry system** — EMS can carry downed players; `ox_target` option on carried ped to put them down; `setCarried` state bag set on server
- **Triage system** — EMS can mark downed players as Critical / Moderate / Minor; blip colour and label updated on all EMS clients
- **Patient Examination** (Tier 2) — Shows injuries, stress, and addiction state to EMS in a context menu
- **Administer Detox** (Tier 3) / **Full Detox** (Tier 4) — EMS can reduce or fully clear a player's addiction
- **Civilian revive with First Aid Kit** — Non-EMS players can revive downed players using `firstaidkit` with a progress circle

### Bug Fixes
- **Death screen too dark** — Background opacity reduced from full black to `rgba(0,0,0,0.30)`
- **Inventory wiped on respawn** — `wipeInvOnRespawn` set to `false` in `config/server.lua`
- **Revive item not required** — `HBSConfig.ReviveRequiresItem` now enforced in `Revive()`; checks `ox_inventory` item count before proceeding

---

## [0.1.0] — Initial Build

### Initial Features
- Core injury tracking (damage detection, body part mapping, severity scaling)
- Stress system (build/decay, screen effects, DB persistence)
- Addiction system (level 1–4, withdrawal effects, `methadone` treatment)
- Medical item use system (bandage, firstaidkit, bloodbag, morphine, painkiller, splint, defibrillator)
- EMS Research system (5 tiers, XP rewards, ability unlocks)
- Crafting table with tier-locked recipes
- Death screen NUI (bleedout timer, respawn button, last words)
- Downed player blips for EMS
- Dispatch notification on player down
- Database tables: `hbs_injuries`, `hbs_stress`, `hbs_addiction`, `hbs_ems_research`
- `hbs:state` state bag system (`HBS.Set`, `HBS.SetLocal`, `HBS.GetRemote`)
- `hbs_wills` table for saved last words
- qbx_ambulancejob bundled files with explicit load order in fxmanifest
