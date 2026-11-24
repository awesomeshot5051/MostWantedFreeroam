# Changelog

Technical changes to Most Wanted Freeroam (mod id `most_wanted_freeroam`, game extension `mwf_core`), newest first. The player-facing
summary of each release (new features, improvements, bug fixes) is in the "What's new" section of
[PUBLISHING_README.md](PUBLISHING_README.md). The technical overview of the mod is in [README.md](README.md).

Versioning: `major.minor.patch`. The major number only changes when the maintainer says so; every later change bumps the minor number.
File paths are relative to the repository root; `mwf/` stands for `lua/ge/extensions/mwf/`, and `ui/` for
`ui/ui-vue/mods/most_wanted_freeroam/`.

## 2.0.0

Everything since the 1.0.0 release, as one release.

### Added

#### Style bonuses and achievements
- **Style bonuses** (`mwf/chase/style.lua`, called from `core.lua` next to `bar.updateBar`).
  - *Drift*: own Forza-style detector and counter (vanilla's `gameplay_drift_*` was far too insensitive). Slip angle >= 10 degrees above 7 m/s held
    for 0.25 s starts a drift; points per second scale with slip angle and speed; a combo (x1 to x5) grows with time and with each change of
    direction; 1 s of grace links drifts; a spinout (> 100 degrees or stopped) banks what was earned; a sudden deceleration (> 30 m/s^2) forfeits it.
    Anti-circle: after 270 degrees of net turning the rate falls to a 5% floor and the combo stops growing. Bounty = 10 x points, capped at 25 000 and
    paid through `pursuit.award('off_drift', ...)`, so repeats fade like traffic offenses.
  - *Near miss* and *trading paint*: per-vehicle tracking of traffic and police within 30 m (`scanOthers`), chains with a 5 s window.
    Near miss = closest approach with a body gap of 0 to 1.3 m at >= 10 m/s own speed and >= 8 m/s closing speed, no contact. Trading paint = a new
    entry in the player's `tv.collisions` with `dot < 0.2` (side contact) at >= 6 m/s, so it never overlaps the existing hit bounties.
  - Live drift line in `mwf/ui/hud.lua`.
- **Reset achievements** button on both the options page and the achievements page (two presses to confirm, shown red on the first). Calls
  `mwf_core.achievementsReset()` -> `MWF.achievements.reset()` (`achievements/tracker.lua`), which clears stats, unlocks and queued banners and saves.
- **Achievements**: "Dodged a Missile" (60 mph) and "Really Dodged a Missile" (100 mph) via the max-stat `missileDodgeMph` (a police car heading at the
  player within about 37 degrees, speed measured on the police car); "Living on the Edge" (100 near misses), "Nearly missing the near miss" (100 paint
  trades), "Highway to the Danger Zone" (180 s in a row above 100 mph, max-stat `fastSeconds`).
  - `data/achievements.lua` entries can carry `reward = {bounty, money, points}`. `achievements/tracker.lua` `grantReward` pays bounty through
    `pursuit.award` and, in an RLS career, money and Most Wanted Criminal milestone points through the new `MWF.rls.payAchievement`.
  - Achievements only unlock during a chase: `check()` returns early without `S.session`; `checkAll()` runs at chase start to unlock what was reached
    in between.
- Achievement stats `drifts`, `nearMisses`, `paintTrades`, `carsStolen`, `tunesApplied` are counted (no achievement for the last two yet).

#### Weapons and on foot
- **Weapons can start a chase** (`mwf/economy/weapons.lua`, option `weaponChase`). `M.provoke(targetId)` calls the player's traffic entry `triggerOffense`
  with vanilla's `hitPolice` / `hitTraffic` keys, but only when `pursuit.policeVisible` is true. Hooks: Weapon Panel presses (now also recorded outside a
  chase, `wp.free`) and Universal Weapons rounds going down (`reportAmmo`, target from a narrow forward cone).
- **On foot** (`mwf/chase/onfoot.lua`, option `onFoot`). Walking mode is no longer in the chase lockdown (`chase/lockdown.lua` skips the `walkingMode` template /
  `toggleWalkingMode` when the option is on). `session.onVehicleSwitched` hands the vehicle change to `onfoot.handleSwitch`, which re-uses the pit-stop
  `scheduleTransfer` to carry the pursuit to the character and on to the next car.
  - Stamina (8 s sprint, 10 s regen) blocks `unicycle__sprintHold` / `unicycle__sprintToggle` through an action-filter group while exhausted. HUD stamina line.
  - Arrest (`copsAround`): surrounded (3+ police within 12 m, ring gap <= 240 degrees), cornered (2+ within 8 m while below 3 m/s) or pinned (within 3.5 m while
    below 1.5 m/s) fill a 1.5 s timer, then `gameplay_police.arrestVehicle`. If that does not end the pursuit, the mode is forced to -1 and the session ends as busted.
    A status line is logged every 3 s while on foot (`On foot: N police within 12 m (nearest ...), speed ..., arrest timer ...`).
- **Stealing traffic cars on foot** (option `stealCars`). Vanilla keeps AI traffic on `gameplay_walk`'s blacklist, so they are never enterable.
  `gameplay_walk.toggleWalkingMode` is wrapped once (`installTheftHook`, called from `core.lua`); when on foot in a chase with no vanilla `getVehicleInFront`, the nearest
  non-reserved AI traffic car within 5 m and slower than 8 m/s (police cars: 12 m/s, see "Fixed") is taken out of traffic (`removeTraffic`, `removeVehicleFromBlacklist`, `isTraffic=false`,
  `ai.setMode("disabled")`) and entered with `gameplay_walk.getInVehicle`. Approach borrowed from the RLS Carjacking add-on (`career_modules_carjacking`). Only stands
  down while a career is active (`career_career.isActive()` or `S.rls.active`); the add-on being installed does not matter, since it loads itself in every game mode.
  Pays a small bounty (key `steal`). `tryTheft` logs why it did nothing (`Carjack: no traffic car within ...`).
- Options `weaponChase`, `onFoot`, `stealCars` (`core/state.lua`, `core/options.lua`).
- **Armored police truck** (`md_series/md_60_armored_police.pc`, vanilla) in the heat 5 group (`data/units.lua`, group size 4 to 5).
- **Cop counter diagnostics**: `pursuit.lua` logs `Cops: N counted, M registered police (...)` every 10 s.

#### Garage
- **Garage UI pages** (`ui/ui-vue/mods/most_wanted_freeroam`): the garage, the options window and the achievements window are Vue pages (ImGui gets no controller input).
  - `ui/index.js`: `makePage(event, view, luaClosed)` builds a popup per page for the events `MwfShop`, `MwfOptions`, `MwfAchievements`. The popup base component is a
    navigation scope like the game's own popups (`v-bng-scoped-nav` with `scopeId`, `activated` / `activateOnMount` from the host's `popupActive` prop,
    `canDeactivate: () => false`, `preferAutoFocus`, `trapPolicy: "always"`, plus `useUINavBlocker().allowNavigationOnly()` while active).
  - Controller: `bng-scoped-nav-autofocus` on the first item of every screen, `bng-nav-item` on every button and on the car / achievement cards (plain `<button>`
    elements were skipped by the navigation), `v-bng-on-ui-nav:back` on each root (B steps back like Esc), `v-bng-text-input` on the search boxes (calls
    `setCEFTyping` so keystrokes reach the page, and the on-screen keyboard works). The brand and sort lists use `BngDropdown` (native `<select>` lists open in a separate
    OS window the in-game UI never shows).
  - The search / name fields are the game's own `BngInput` (a plain `<input>` with `v-bng-text-input` put the controller into typing mode as soon as it was focused, and it could
    not get out, so nothing below a search box could be reached). Every first / primary element also carries `v-bng-ui-nav-focus="1000"` (a priority-focus element), which is
    what the game uses to put focus back when the controller takes over again after the mouse was used; without one the controller could not get back in.
  - `mwf/ui/options_window.lua`: `optionsInit`, `optionsGet`, `optionsSet(key, value)` (type- and range-validated, applies side effects such as `lockdown.refreshBlock` and
    `difficulty.refreshSensitivity`, saves), `optionsClose`. `S.optUI` is a small state table. `mwf/ui/achievements_window.lua`: `achievementsGet` (formatted progress text),
    `achievementsClose`, `openAchievements`. The unlock banner is still the ImGui overlay. A page that does not answer within 4 s is closed with a toast.
- **Parts shop**: search box (top level searches every slot of every category, inside a category its slots, inside a slot its parts); Add to cart / Remove is one stable
  button, its click is stopped from bubbling and a `back` within 600 ms of a cart change is ignored; Buy parts opens a confirm screen (items, total, wallet after) and nothing
  is bought until Confirm is pressed (Cancel is focused by default).
- **Owned parts** (`mwf/economy/garage.lua`): parts are remembered by name for the rest of the chase (`S.session.ownedParts`, `markOwned` / `isOwned`): a Crash Breaker reset keeps
  them, the end of the chase forgets them. `partsCost` skips owned parts and also returns the names that become yours (bought, and taken off the car by the change). `partsGate`
  / `partsCharged` pass that list through the `setPartsTreeConfig` wrapper; `shopSlotParts` returns an `owned` flag, `shopBuyParts` accepts a zero-cost cart ("Install parts").
- **Weapon mounts cost money** (`weaponValue`): Universal Weapons parts carry no `information.value`, so they were priced at $0. A part whose `slotType` starts with `weapon`
  (or that loads the `universalweapons` controller) gets a default value (16 000, or 40 000 when the slot or part name says big / howitzer / cannon); the price factor and
  part-price cap apply as for every part.
- **Big map labels for made-up pit stops** (`mwf/world/pits.lua`). POIs turned into pit stops on maps with no garages / gas stations (`FB.add`) are recorded in
  `S.fallbackPois` (POI id -> kind). `M.onGetRawPoiListForLevel(levelIdentifier, elements)` (the hook the game uses to collect big map POIs) sets their
  `bigmapMarker.icon` (map pin) to `poi_garage_2_round` / `poi_fuel_round`, `bigmapMarker.cardIcon` (the icon the Vue big map's list and card read first, `freeroam/vueBigMap.lua`) to `garage01` / `fuelPump`, and prefixes their translated name with `Garage: ` / `Gas station: ` (once, `mwfLabeled`). Real facilities are
  not touched. `onClientPostStartMission` starts a timer; `tickPoiLabels` (from `core.lua`) runs `loadGasStations()` 4 s after the level loads and calls
  `gameplay_rawPois.clear()` once, then fetches the rebuilt list with `getRawPoiListByLevel` and labels it in place, so it does not depend on the order extensions add POIs in
  (the hook alone did nothing when it ran before the POI sources). That was still not enough: the Vue big map (`freeroam/vueBigMap.lua`, `buildPoiDataCache`) calls `gameplay_rawPois.clear()` every
  time it opens and rebuilds the list itself. `installPoiWrap()` (called from `tickPoiLabels`) therefore wraps `gameplay_rawPois.getRawPoiListByLevel` once (`rp.mwfWrapped`; the wrapper asks the live
  `mwf_core.mwfLabelPois`) so every list the game hands out is labelled; a list that was already labelled (`S.poiLabeledList`) is skipped. Skipped in an RLS career or with the option off; reset in `session.onClientEndMission`.
- **Garage tuning** (third hub tile, screen `tuning`). Lua (`mwf/ui/garage_window.lua`): `shopTuning()` reads `core_vehicle_manager.getVehicleData(id).vdata.variables`, runs it
  through `core_vehicle_partmgmt.translateTuningData`, drops `hideInUI` and non-numeric variables and returns category > sub-category > variable lists (display range
  `minDis/maxDis/stepDis`, current and default value as display values; `rawToDis` / `disToRaw` copy the game's own conversion in
  `ui-vue/src/modules/vehicleConfig/stores/tuningStore.js`). `shopTuneApply(list)` converts the edits back to raw values, clamps them and calls
  `core_vehicle_partmgmt.setConfigVars` (which goes through `veh:respawn`, not `core_vehicles.replaceVehicle`, so the price guard does not charge for it).
  `shopTuneDefaults()` sets every variable to its jbeam default. Saved tunes (like RLS's saved tunes) are kept per model in `/settings/mwf_tunes.json`: `shopTunes`,
  `shopSaveTune`, `shopLoadTune` (returns display values for the page's edit list), `shopDeleteTune`. Lists are passed as arrays of `{name, v}` because names such as
  `$fuel...` are awkward table keys when serialised to Lua. Free; not available in an RLS career (the garage is off there).

#### Minimap and compatibility
- **`MwfMinimap` UI app** (`ui/modules/apps/MwfMinimap/{app.json, app.vue, app.png}`, directive `mwfMinimap`, `"vue": true`): a copy of the game's Navigation app
  (`ui/modules/apps/Navigation/app.vue`, same minimap drawing through `ui_apps_minimap_minimap`) with an SVG heat ring inside the circular map container (ten arc segments
  computed from `heat - 1 + progress`), a flame + heat badge, and CSS animations: red / blue flashing while `pursued`, an orange pulse while `cooling`. Polls
  `mwf_core.getHeatHud()` every 250 ms.
- `getHeatHud()` / `heatData()` in `mwf/ui/hud.lua`: `{active, heat, maxHeat, progress (0-1 through the current heat), pursued (pursuit.policeVisible while the pursuit mode
  is above 0), cooling (evadeValue > arrestValue while not visible), mode, evadeValue, arrestValue, bounty}`.
- **Most Wanted Mission minimap follows this mod's heat** (`mwf/compat/mwm.lua`, loaded between `compat/rls` and `achievements/tracker`). The *Most Wanted: Minimap* app of
  `most_wanted_mission_mathkuro` polls `mathkuro_mostWantedMission.getPursuitData()` for `currentHeatLevel`, `bountyProgress`, `mode`, `policeVisible` and
  `timers.evadeValue/arrestValue`, but that mod only computes them during its own mission. `install()` (called every frame from `core.lua`, because the app can unload and
  reload the extension) wraps that exported function once per module table (`ext.mwfWrapped`): while `S.session` exists it returns a copy of the original result with those
  fields replaced by this mod's values (`MWF.hud.heatData()`); otherwise it returns the original result. No file of that mod is modified.

### Changed
- **Garage vehicle list** (`mwf/economy/garage.lua`, `isDriveable`) only lists cars and trucks you can drive. The vehicle type is read from `config.Type` and from
  `config.aggregates.Type` (the game merges the model's type there; only a few configs carry their own `Type`); mod vehicles with no type are accepted only if they report
  engine power. The catalog is not cached if it has fewer than 20 entries (the vehicle list was not ready yet).
- `PUBLISHING_README.md` has a "What's new" section (grouped by new features / improvements / bug fixes) and `README.md` links to this changelog.

### Fixed
- **The RLS reset charge was invisible**: `MWF.rls.announce(cost, what)` (`compat/rls.lua`, called from `chase/breaker.lua` after `MWF.rls.charge`) adds a red `-$N insurance claim / private repair (career money)` line to the bounty feed (`neg = true`) and shows a toast ("Crash Breaker: insurance claim", "-$N from your career money.").
- **A chase ended when the car was repaired at the RLS computer** (`mwf/compat/rls.lua`, `chase/session.lua`, `economy/garage.lua`). RLS's insurance repair has a repair time (60 s in the log): `startRepairDelayed` removes
  the car from the world (`removeVehicleObject`) and an instant repair respawns it (`spawnVehicle`), and either looked like swapping cars out of the chase. In an RLS career, while a chase is on:
  `installRepairWatch()` wraps `overhaul_career_repair_insurance.startRepairInGarage` / `startRepairInPlace` once (`mwfWrapped`); the wrapper calls `mwf_core.rlsRepairStarting(opt)`, which sets
  `opt.repairTime = 0` (RLS still charges the quote, files the claim and applies the deductible) and opens a 25 s `S.rlsRepairUntil` window in which `onVehicleSwitched` / `onVehicleReplaced` /
  `onVehicleDestroyed` hand the chase over (`scheduleTransfer`) instead of ending it. While the RLS computer is open (`overhaul/lib/career/context`.`currentUiRouteName()` starts with `overhaul.computer`,
  polled every 0.25 s) the chase is frozen with the garage pause (`S.rlsComputer` in `applyGaragePause`), so the pursuit cannot run out while you pay.
- The three places where a vehicle event ends a chase as busted (car switched, replaced / respawned, removed; `chase/session.lua`) now log why (`Chase ends: ...`), to pin down what ends a chase when a car is repaired through RLS.
- **Resetting from the pause menu did not end the chase** (`mwf/chase/session.lua`): the pause menu's Reset button calls `vehicle:requestReset(RESET_PHYSICS)` directly (`ui/pause/providers/vehicleTabInteractions.lua`),
  so it bypassed the Crash Breaker and its cost. `installPauseWatch()` (from `core.lua`) wraps `executeVehicleTabInteractionAction` once (`mwfWrapped`) and calls `mwf_core.notePauseAction()`;
  `onVehicleResetted` ends the chase as `busted` (with a toast) when the player's car is reset within 8 s of such a click and the Crash Breaker (`S.breaker`, `breakerLockUntil`), a pit stop / garage /
  transfer or walking mode did not cause it.
- **Police cars could not be carjacked** (`mwf/chase/onfoot.lua`): `findStealTarget` skipped everything with the `police` role. Police are now valid (reach 5 m, up to 12 m/s since they keep rolling while closing in on you;
  KARR / KITT and roadblock props excluded). A stolen unit goes through `MWF.escalation.release(id)` (new, `chase/escalation.lua`: removed from `S.esc.groups` / `specials` / `info` / `place` / `cleanup`) and
  loses its `mwfSpawned` tag, so reinforcement, the unit cap, the end-of-chase cleanup and `sweepLeftovers` never touch the car you are driving. Pays $1,500 ("Carjacked a police car").
- **Universal Weapons ammo barely used up a slot** (`lua/vehicle/extensions/auto/mwfWeapons.lua`): a slot (a third of the reset bar) held 100 machine-gun rounds / 10 big-gun rounds, which is 5 to 12 s of
  continuous fire from a minigun or 50cal, so one payment lasted a long time. It now holds 40 / 5 rounds (the machine gun / big gun test in `economy/weapons.lua` `requestSlot` moved from 50 to 20 rounds).
  The price per slot is unchanged ($1,000 / $2,000).
- **Vehicle Shop paging and filters** (`ui/ui-vue/mods/most_wanted_freeroam/MwfShop.vue`): the list is now paged (12 per page, first / prev / next / last, also at the bottom) instead of a "Show more" button
  that was easy to miss; "Affordable only" starts off, so every car is listed and the ones you cannot afford are flagged; the brand dropdown is built from the cars themselves (`carBrands`) instead of the
  list sent when the page opened, and the car list is re-requested (up to 3 times) when the game's vehicle list was not ready yet.
- **Police units fell from the sky** (`mwf/chase/escalation.lua`): units were spawned at the engine's default spawn point and only teleported by
  `gameplay_traffic.forceTeleport`, which silently does nothing in several cases. `groundSpawnPoint()` now picks a road point behind the player with
  `trafficUtils.findSafeSpawnPoint` / `finalizeSpawnPoint`, spawns the car there (`pos` passed to `spawnNewVehicle`), orients it with `spawn.safeTeleport`, and
  `checkGrounded()` watches each new unit for 4 s and teleports it back if it is more than 1.5 m above the surface (or below it), up to 3 times. The old
  `forceTeleport` is the fallback when no road point is found.
- **The chase did not stay paused in the garage** (`mwf/economy/garage.lua`): `keepGaragePaused()` runs every frame (called from `core.lua`) and re-applies
  `simTimeAuthority.pause(true)` while the garage holds the pause, logging when something else un-paused the game.
- **The chase resumed at about 1/1000 speed after leaving the garage with the controller's back button** (`applyGaragePause`). `simTimeAuthority.pause(false)` restores the
  speed the game saw when it was paused; a pause re-applied in the middle of the speed ramp made it "remember" a near-zero speed. The garage now remembers the real time
  scale when it pauses (`S.garage.timeScale`, 1 if it was below 0.05) and sets it back with `simTimeAuthority.setInstant` when it resumes.
- Garage page: the search box could not be typed into and the dropdowns did nothing (see the garage UI pages above); the search bar in the parts shop no longer has a huge gap
  under it (`.search` is `flex: 1 1 16em`, which grew vertically inside the column-flex parts panel; `.parts-search` now sets `flex: none`).

## 1.0.0

Initial release.
