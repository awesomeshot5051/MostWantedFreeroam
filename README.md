# Most Wanted Freeroam  (version 2.0.0)

Turns the vanilla police chase in BeamNG freeroam into a continuous, escalating **Most Wanted**-style pursuit:
ten heat levels, a bounty, a "reset bar" you spend on weapons and vehicle resets, pit stops at gas stations and
garages, and new police units and roadblocks as the heat climbs. There is **no end screen**. A chase simply ends when
you escape (or get busted), and the next one starts fresh.

This is a **standalone rewrite**. It does not use or depend on the *Most Wanted Mission* mod's code (that mod is only
used as a design reference, and optionally for a few vehicle configs, see [Dependencies](#dependencies)).

> **Changes:** every release, with the technical details, is listed in the [changelog](CHANGELOG.md).

> **Status:** all features, including heat 7-10, armed units, KARR / KITT, the garage pause, POI pit stops, police sensitivity,
> achievements and RLS mode, have been tested in-game by the author. Known limits are listed under
> [Known limitations](#known-limitations). Please report problems with your `BeamNG.log`.

---

## Contents

1. [Quick start](#quick-start)
2. [Dependencies](#dependencies)
3. [How a chase works](#how-a-chase-works)
4. [Heat levels and escalation](#heat-levels-and-escalation)
5. [Bounty](#bounty)
6. [The reset bar](#the-reset-bar)
7. [Style bonuses](#style-bonuses)
8. [Weapons cost reset bar](#weapons-cost-reset-bar)
9. [Resetting your car (Crash Breaker)](#resetting-your-car-crash-breaker)
10. [Pit stops (gas stations and garages)](#pit-stops-gas-stations-and-garages)
   - [Pit stop economy (cars and parts cost bounty)](#pit-stop-economy-cars-and-parts-cost-bounty)
   - [RLS career compatibility](#rls-career-compatibility)
11. [What is locked during a chase](#what-is-locked-during-a-chase)
12. [The HUD](#the-hud)
   - [Minimap app with a heat ring](#minimap-app-with-a-heat-ring)
   - [On foot](#on-foot)
13. [Options and performance](#options-and-performance)
14. [Controls](#controls)
    - [Achievements](#achievements)
15. [Files in this mod](#files-in-this-mod)
16. [Changes made to other mods](#changes-made-to-other-mods)
17. [Known limitations](#known-limitations)
18. [Troubleshooting and logs](#troubleshooting-and-logs)
19. [Tuning](#tuning)
20. [Uninstalling and reverting](#uninstalling-and-reverting)
21. [Developer notes](#developer-notes) (architecture, hooks, adding modules)

---

## Quick start

22. Keep this folder in `mods/unpacked/most_wanted_freeroam/` (or zip its contents as a normal mod).
2. Optionally install **Weapon Panel** and **Universal Weapons** as they are. This mod gates them by itself, without
   changing a single one of their files (see [How the weapon gating works](#how-the-weapon-gating-works)).
3. Start a freeroam map with **traffic enabled and police in the traffic** (the vanilla police option).
4. Commit an offense near a police car (speed past them, hit something, run a light). When the vanilla pursuit starts,
   the HUD appears at the bottom of the screen and the chase is on.

---

## Dependencies

### Required

| Requirement | Why |
|---|---|
| **BeamNG.drive (freeroam)** with vanilla traffic **and police enabled** | The mod rides on the game's own `gameplay_police` and `gameplay_traffic` systems. It does not create pursuits itself, it reacts to the ones the game starts. |

No other mod is required for the core chase: heat, bounty, HUD, reset bar, Crash Breaker reset, pit stops, input
locks, extra police waves and roadblock props.

### Optional

| Mod | What you lose without it |
|---|---|
| **Weapon Panel** (`weapon_panel_jtf`), unmodified | Its weapons stay free and unlimited in chases, and earn no bounty. |
| **Knight Rider pack** (`KNIGHTRIDERV12_2`: KARR and KITT) | Optional. One KARR at heat 8 and one KITT at heat 9. Skipped if not installed. |
| **Universal Weapons** (`universalweapons`), unmodified | Its guns are gated by the reset bar and bounty (see weapons). Heat 8+ also spawns **armed police** with its roof guns; without the mod they are replaced by ordinary interceptors. |
| **Most Wanted Mission** (`most_wanted_mission_mathkuro`) | Heat 6+ units use its `mwm_interceptor` configs (bastion, scintilla, roamer, US semi). If it is not installed, those spawns fall back to a plain police car or van. Nothing else depends on it. |

### Compatibility notes

- **Freeroam first.** Scenarios, missions, the vanilla career and multiplayer (BeamMP) are not supported or tested. The one career
  that is supported is the **RLS Career Overhaul** (see [RLS career compatibility](#rls-career-compatibility)). The mod
  deliberately blocks and wraps several game inputs during a chase.
- Neither weapon mod is modified. You can update or remove either one at any time. If one is missing, the matching part
  of this mod simply does nothing.
- The gating depends on how those mods work today (Weapon Panel's window title and button labels, and Universal Weapons'
  jbeam keys). If a future update renames them, gating for that mod stops working until this mod is adjusted (weapons
  then just stay free).
- If you run the Most Wanted Mission mod alongside this one, avoid running its mission and a freeroam chase at the same
  time. Interaction between the two has not been tested. Its **Most Wanted: Minimap** app (heat number with a flame, and the heat
  ring) follows this mod's heat during a chase: `compat/mwm.lua` wraps `mathkuro_mostWantedMission.getPursuitData` at run time (no
  file of that mod is edited) and answers with this mod's heat, progress to the next heat and "police can see you" flag while one
  of our chases is on. Outside a chase the original function answers, and without that mod nothing happens.

---

## How a chase works

- A chase **starts** when the vanilla police system starts a pursuit against your car (the game's `start` event). It
  **ends** on the game's `evade` (you got away) or `arrest` (busted) events.
- Starting a chase resets the bounty and empties the reset bar. Ending one clears everything: bounty, bar, spawned
  units, locked inputs.
- **Arrest** does not freeze you for an end screen. The mod just ends its own session and lets the game's normal
  arrest/release flow play out.
- Leaving or restarting the level, switching vehicles on the road, or replacing/deleting your car outside a pit stop
  also ends the chase (as "busted").
- While a chase is on the mod scales the game's pursuit difficulty with heat (see below).

---

## Heat levels and escalation

Heat goes from 1 to **10** and rises with **bounty** (what you *earned*; spending never lowers it):

| Heat | Bounty needed | Pursuit pay |
|---|---|---|
| 1 | 1 (start of chase) | $10/s |
| 2 | 6,000 | $45/s |
| 3 | 15,000 | $100/s |
| 4 | 30,000 | $150/s |
| 5 | 50,000 | $200/s |
| 6 | 75,000 | $250/s |
| 7 | 110,000 | $300/s |
| 8 | 150,000 | $350/s |
| 9 | 200,000 | $425/s |
| 10 | 275,000 | $500/s |

The "Pursuit pay" is the steady income for staying alive. It is shown on the HUD (`Pursuit time +$N/s`) and in the toast
that appears when a new heat level is reached.

Heat only goes up during a chase. Every level up shows a toast naming what is arriving.

### What changes as heat rises

- **Extra police units** are spawned per level (heat 1 is the normal police already in traffic):

  | Heat | Extra units | Count |
  |---|---|---|
  | 2 | Fullsize police, van police, roamer sheriff | 2 |
  | 3 | Bastion police, sunburst police | 2 |
  | 4 | Unmarked bastion, unmarked roamer, sunburst interceptor | 3 |
  | 5 | Scintilla interceptor, **police vans**, unmarked roamer, **armored police truck** (`md_60_armored_police`) | 5 |
  | 6 | `mwm_interceptor` bastion / scintilla, **US semi** x2 | 4 |
  | 7 | `mwm_interceptor` roamer / scintilla, **US semi** x2 | 4 |
  | 8 | **Armed** minigun hopper, 50cal vivace, US semi x2, plus **KARR** | 4 + 1 |
  | 9 | **Armed** scintilla (dark owl), autocannon lansdale and ETK, US semi x2, plus **KITT** | 5 + 1 |
  | 10 | **Howitzer van**, armed scintilla, autocannon ETK, US semi x2 | 5 |

  **Armed units** use Universal Weapons configs. The AI fires a roof gun non-stop while in pursuit, and their guns are
  free (only your own gun costs you). They only appear if Universal Weapons is installed; otherwise an ordinary
  interceptor, van or patrol car is spawned in their place. Likewise, the US semis need Most Wanted Mission and fall back
  to a police van without it.

  **KARR and KITT** (Knight Rider pack, `karr` and `knight_2000`): exactly **one** KARR joins at heat 8 and exactly **one**
  KITT at heat 9, once per chase. They are indestructible, so they are never replaced, never count toward a group or
  the unit cap, and never pay a wreck bounty. If the pack is not installed they are simply skipped. They are removed when
  the chase ends.

  **Reinforcements:** wrecked units in the heat groups still in play are retired and replaced every few seconds, so
  smashing cops does not thin the chase out (and the semis keep coming at the top heats). The check runs every 6 s, every
  4 s from heat 7 and every 3 s at heat 10.

  New units are placed on a road out of sight, then join the pursuit. Only the **newest 3 heat groups** stay in play,
  and the total is capped at **16** extra units.
- **Roadblock props:** 4 sawhorses at heat 3 only, 4 spike strips at heats 4 to 10. They are parked until the game builds
  a roadblock with them.
- **Harder pursuit settings** (restored when the chase ends): evade time grows (up to 2x the default from heat 8), arrest time shrinks (down to a 2.5 s floor), roadblock frequency rises.
- **Vanilla pursuit mode** is raised with heat (heat 2 -> mode 2, heat 3 and up -> mode 3). Mode 3 is what makes the
  game build roadblocks, which is why they start at heat 3. Spike strips run from heat 4 to 10.
- When the chase ends, every unit and prop the mod spawned is removed (see [Options](#options-and-performance)).

---

## Bounty

Bounty is shown at the bottom of the screen with a live **feed that says exactly what paid you**, for example
`+$500 Rammed a police car`.

| Source | Base payout |
|---|---|
| Surviving | $10/s at heat 1, rising to $500/s at heat 10 (table above) |
| Ramming a police car | $500 |
| Hitting a civilian car (at fault) | $150 |
| Police car smashed / put out of action | $1,000 to about $5,000, by unit type (see below) |
| New offense (speeding, street racing, reckless driving, wrong way, red light) | vanilla offense score x5 |
| Repeat offense | $250 |
| Weapon hits (see below) | $500 to $5,000 |

**Repeat penalty (traffic offenses only):** speeding, street racing, reckless driving, driving the wrong way, running a
red light, and the generic "repeat offense" payout get less each time you repeat them. Every recent repeat multiplies the
payout by **0.92** (minimum **50%**); one repeat is forgiven about every **12 seconds**. Repeats show in purple with their
multiplier, e.g. `(repeat x0.85)`.

**Never penalised:** destroying or ramming cars always pays the full amount, no matter how often you do it. That covers
smashing a police car, ramming a police car, hitting civilian traffic, and every weapon hit.

### Police wreck payout

What a smashed police car pays depends on **which unit it is**: `$1,000 + $250 per heat level` of the group the unit
belongs to, times a class multiplier (patrol cars x1, vans x1.25, interceptors x1.1 to 1.3, semis x1.5, armed units x1.4
to 1.5, howitzer van x1.6), capped at **$5,000**. So a plain patrol car is $1,000, a heat 6 semi is about $3,300, and a
heat 10 howitzer van about $5,000. The feed names the unit, for example `+$3,375 Special pursuit semi smashed`.

**Gun kills pay 35%.** If you fired a Universal Weapons gun in the last 4 seconds when a cop goes down, the wreck is
paid at a reduced rate and labelled `(gun kill)`, so a gun cannot farm bounty. Missiles and ramming pay as normal.

### Weapon bounty (Weapon Panel)

Per use, on a police car / civilian car:

| Weapon | Police | Civilian |
|---|---|---|
| Missile | 5,000 | 4,000 |
| Chain Missile (first target) | 5,000 | 4,500 |
| EMP | 3,000 | 2,500 |
| Tire Pop | 1,500 | 1,200 |
| Throttle Lock / Brake Lock / Steering Jam / Parking Brake Lock | 1,000 | 800 |

Weapon payouts are always between **500 and 5,000**. A cop put out of action within 10
seconds of a weapon hit is credited to the weapon, so you do not also get the smashed bonus. Using a weapon on your own
car pays nothing. Weapon bounty only counts **during a chase**, for **paid** uses.

---

## The reset bar

A three-slot bar (1000 points, 333.3 per slot). It is **empty at the start of every chase**.

**Fills from risky driving** (counted after 10 m of continuous behaviour):

| Behaviour | Points |
|---|---|
| Drifting (about 20 degrees of slip or more, above 8 m/s) | 1.0 per metre |
| Driving the wrong way | 0.3 per metre |
| Speeding above **200 km/h (125 mph if your game is set to imperial units)** | 0.5 per metre |

**Passive refill:** 2 points per second plus 1.5 per heat level, plus 5% of all bounty you earn. Higher heat refills
faster.

**Spent on:** weapon use, and resetting your car. See the next two sections.

The charge pauses for about 1.5 seconds after any reset or teleport, and speed/distance are sanity-capped, to stop
physics spikes from instantly filling the bar.

---

## Style bonuses

Extra bounty during a chase, shown in the bounty feed (the live drift counter is shown above it):

| Bonus | Pays |
|---|---|
| Drift | 10 x a Forza-style drift counter (not vanilla's, which is far less sensitive): a drift starts at about 10 degrees of slip above 16 mph, scores by angle and speed, and a combo (up to x5) grows with time and with every change of direction. You can straighten out for 1 s without losing it. It pays when the drift ends, and a **spinout** pays what you had. Hitting something forfeits it. Turning more than 270 degrees in one drift (circles, donuts) cuts the rate to almost nothing and stops the combo growing, repeats pay a little less each time, and one drift pays at most $25,000. |
| Near miss | $250, passing a car (traffic or police) closely at speed without touching it. Back-to-back near misses within 5 s chain: +50% per link, up to 8 links. |
| Trading paint | $300, a glancing side-swipe at speed. Chains the same way. Head-on hits keep paying the normal "hit" bounty. |

---

## Weapons cost reset bar

**Only while a chase is active.** Outside a chase, all weapons are free and unlimited, exactly as in the original mods.

| Weapons | Cost |
|---|---|
| **Weapon Panel**: every button | 1 slot per use (Chain Missile charges once per launch) |
| **Weapon Panel**: **EMP** | **all 3 slots** (it can hit several cars at once) |
| **Universal Weapons**, machine guns (50cal, minigun) | 1 slot = **40 rounds** |
| **Universal Weapons**, big guns (M242 autocannon, howitzer) | 1 slot = **5 rounds** |

- **Weapons also cost bounty**, on top of the bar. Like pit stop spending, this **never lowers your heat**:

  | Weapon | Bounty cost |
  |---|---|
  | Missile | $1,500 |
  | Chain Missile | $2,000 |
  | EMP | $3,000 |
  | Tire Pop | $500 |
  | Throttle / Brake / Steering / Parking Brake lock | $400 |
  | Universal Weapons machine gun, per slot (40 rounds) | $1,000 |
  | Universal Weapons big gun, per slot (5 rounds) | $2,000 |

  If your wallet is too low the weapon does not fire.
- With an empty bar, nothing fires: no shot, no muzzle sound.
- Universal Weapons rounds are counted by firing time (the weapon's rounds-per-minute), so the count can be off by about
  one round. When the rounds run out, the next trigger pull asks for another slot. Leftover rounds stay loaded between
  trigger pulls and across vehicle resets.
- Rounds loaded before a chase (free) carry into it.
- A jbeam key `roundsPerSlot` on a weapon part overrides the default. Machine guns are told apart from big guns by the
  part's `explosionRadius` (none = machine gun).
- Weapon Panel: a press with no slot available is swallowed. A press that goes ahead is charged only if the panel reports
  success, so a cooldown or a "No Target" result costs nothing.
- Only the **player's own** gun draws from the bar. Guns on other vehicles (e.g. AI turrets) are free.
- While your car has a Universal Weapons gun during a chase, a small **AMMO window** appears just above the main HUD showing
  `rounds / capacity` (for example `29 / 40` for a machine gun, `4 / 5` for a big gun) with a bar. It turns red at 0.
- A **real reset** (the Crash Breaker) empties every Universal Weapons gun on your car back to 0 rounds, so they must be
  paid for again.
- Weapon Panel hits pay bounty (table above). The mod works out the target itself (the nearest vehicle ahead of you, or
  within 20 m for Tire Pop), so the cop-versus-civilian split is a close estimate, not exact.

### How the weapon gating works

No file of either weapon mod is changed, copied or replaced.

- **Weapon Panel:** this mod wraps ImGui's `Begin`, `End` and `Button` (and the toast function) once, and only reacts while
  the window titled "Weapons Panel" is being drawn. If that mod is not installed, the window never appears and nothing
  happens.
- **Universal Weapons:** a small vehicle extension (`lua/vehicle/extensions/auto/mwfWeapons.lua`) loads in every vehicle.
  It does nothing unless the vehicle has a Universal Weapons part (a part section with `ammoTag` and `fireRate`). On such
  a vehicle it takes the fire input (`fireweapons` or the part's own `fireElectric`) behind a small proxy: the weapon
  only sees "firing" while the trigger is held and rounds are loaded.

---

## Resetting your car (Crash Breaker)

During a chase a reset costs **one bar slot**, plus bounty that depends on the heat, and it plays the Most Wanted sequence:

| Heat | Bounty cost | Side effect |
|---|---|---|
| 1 and 2 | **Free** | The reset bar then refills at **35% speed for 60 seconds** (every source of bar charge is slowed), so a second free reset takes much longer to come around. |
| 3 and up | **$5,000** (heat is not lowered) | None. |

The sequence:

1. **Slow motion** (0.25x time).
2. **Your car explodes.**
3. After about 1.6 seconds the game's normal **recover** runs (the same as `recovery.startRecovering()` followed by
   `stopRecovering()`).

- Works from the **reset key (R)**, and from the **controller reset button** (usually `recover_vehicle`). Both are
  handled by the same code, and only one request counts per press (later duplicates from the same button are ignored
  for the length of the effect plus 2.5 s).
- With less than a full slot, or (from heat 3) less than $5,000 in your wallet, the reset is refused with a "Reset Locked" toast.
- **Teleport to last road is free** and is never blocked.
- **Reset-all, home reset, and other teleports are blocked** (see below).
- The recover does **not** repair damage. Repair at a pit stop.
- Every reset logs where you were and where you ended up (`Reset: recovering from ...` then `Reset: now at ...`).

---

## Pit stops (gas stations and garages)

Gas stations and garages act as **pit stops during a chase**:

- **Entering** one repairs your car **once** (the game's `saveHome` + `loadHome`, as Most Wanted does), with a
  5-second cooldown. It does not repeat while you sit inside.
- **Only garages open the vehicle UI.** A gas station repairs you and nothing else. In a garage you can swap or
  reconfigure the car and the chase **keeps going**: the pursuit, bounty, bar and heat are handed over to the new car.
  Everything locks again when you leave. (With the **pit stop costs** option switched off, gas stations unlock the
  vanilla vehicle options for free as before.)
- **The chase is paused while a garage window is open.** The game is frozen (no bounty, no timers, no new units), so you
  cannot wait around for something to show up. Close the window or press **Leave garage** to resume.
- **Shape:** gas stations use a 10 m radius around the centre of their pumps (same as Most Wanted). Garages use a 6 m
  radius around their door(s). If a garage has no door data it falls back to the centre of its zone.

### Maps with no gas stations or garages

Pit stops come from the level's own facility data, so any map that defines gas stations and garages works with no
setup. For maps that define none (Caldera Bay, for example, only has spawn points), the **"Generate pit stops from map POIs"**
option (on by default, Alt+M) makes some from the game's points of interest (spawn points and similar):

- Only the **missing** kind is generated. A map with real gas stations but no garages gets generated garages only. Real
  facilities are never replaced or moved.
- If both are missing, the POIs alternate garage / gas station. If only one is missing, every other POI becomes that kind.
- POIs within 150 m of another stop are skipped, and generated stops have a 12 m trigger radius.
- **Big map labels:** a generated stop is a plain POI on the big map, so there is nothing to tell a made-up garage from a made-up gas
  station. The game collects the big map's POIs through the `onGetRawPoiListForLevel` hook; this mod's implementation gives the POIs it
  turned into pit stops the game's own `poi_garage_2_round` / `poi_fuel_round` icon and a `Garage: ` / `Gas station: ` prefix on their name
  (`world/pits.lua`). Real garages and gas stations keep their own icons and are never touched. About 4 s after a level loads the mod works
  out which POIs it will use, asks the game to rebuild its POI list (`gameplay_rawPois.clear()`) and labels the rebuilt list directly (the pin icon and the icon on the big map's card), then re-checks every 3 s in case something else rebuilds it. Nothing
  is labelled in an RLS career or with the option off. There is no marker in the 3D world, only on the map.
- The log line `fallback pit stops from POIs (N POIs, M usable): X garages, Y gas stations added` says what was made.

### Pit stop economy (cars and parts cost bounty)

**Enabled by default.** It can be switched off in the options window (**Alt+M**, "Pit stop costs"). It only does
anything while you are inside a pit stop during a chase. Everywhere else the game behaves as normal.

The idea is borrowed from the RLS career mod: bounty is your money. You can only switch to cars you can afford, and you
pay for modifications, so you cannot hop from garage to garage building the ultimate car.

- **Wallet:** your bounty minus what you have spent. The HUD's `BOUNTY` figure is your wallet, and spending shows
  in the feed in red (`-$6,000 Bought ...`). **Heat follows what you earned, not what is left.** Spending bounty on
  cars, parts, resets and weapons never cools the chase down.
- **Prices:** a share of each car's real in-game value. The default is **50%** (the "Price factor" slider in the options
  window goes from 10% to 100%). Prices are clamped to **$1,500 minimum and $60,000 maximum**, so cheap cars are not free
  and supercars are not out of reach forever. Part prices use the same factor, capped at $20,000 per part.
- **Garage shop (only in garages):** it opens by itself when you enter a garage (toggle with **Alt+G**) and closes
  when you leave. It is a real game UI page (Vue, in `ui/ui-vue/mods/most_wanted_freeroam`) laid out like the RLS
  computer, except you pay the listed price: there is no negotiating.
  - **Tuning:** every tuning variable the game exposes for the car (suspension, tyre pressure, gear ratios, boost, ...), grouped
    by category and sub-category like the game's own tuning screen, with a slider and - / + buttons per setting, a reset-to-default
    button and a search box. Changes are collected and applied together with **Apply tune** (the car is rebuilt, which keeps the
    chase going the same way a parts purchase does). **Undo changes** drops the edits; **Reset to the car's defaults** puts every
    variable back to the car's jbeam values. **Saved tunes** keep a named snapshot per car model in `/settings/mwf_tunes.json`
    (Save, Load into the edit list, Delete), the same idea as RLS's saved tunes. Tuning is free: it only changes variables on the
    car you already have, never its parts. Not available in an RLS career (the garage is off there; use RLS's own tuning).
  - **Search:** the vehicle shop and the parts shop both have a search box. In the parts shop it searches whatever list is
    showing: at the top level every slot of every category at once (type "turbo", "tire", ...), inside a category its
    slots, inside a slot its parts.
  - **Controller:** the whole page works with a controller using the game's normal UI navigation (D-pad / stick to move, A to
    select, B to step back, the on-screen keyboard for the search boxes). Nothing opens the menus by itself on a controller:
    bind **Toggle garage / options / achievements** (they are in the controls menu under this mod) to whatever you like.
  - **Hub:** three tiles, **Vehicle Shop**, **Parts Shop** and **Tuning**, plus **Leave garage**.
  - **Vehicle Shop:** search, brand filter, sort (price, power, name) and an "Affordable only" switch (off by default). The list is paged, 12 cars per page. Each listing shows the
    photo, name, price and key specs; click one for the detail page (full specs, price, wallet after purchase) and a
    **Buy** button with a confirm step. Your current car is swapped for it.
  - **Parts Shop:** categories, then slots, then the parts for that slot with their prices. Add parts to the **cart** on the
    right, check the total, and buy them together.
  - If the page fails to load, the garage closes itself after 4 seconds (so the game is never left paused) and the log says why.
- **Parts:** each part you change costs its value x the price factor. A change you cannot afford is **refused** with a
  toast (the vanilla list itself cannot be filtered, so you find out when you try). Parts that stay the same are free.
- **No loopholes:** while pit stop costs are on, the vanilla vehicle selector and car switching stay locked, and any
  other way of swapping the car (the pause menu, another mod) at any pit stop goes through the same price check.
- **Not charged:** the police units and roadblock props this mod spawns itself.
- Turn the option off for the old behaviour: free swapping and modifying at pit stops.

- Starting a chase while standing inside a pit stop does **not** trigger a repair or open the options.
- Each entry is logged: `Pit stop entered: garage "Name" (4.2 m ...)`, which tells you exactly which place triggered.
- Pit stops only work **during a chase**. Outside a chase the normal game behaviour applies everywhere.

### RLS career compatibility

When an **RLS Career Overhaul** career is running (`overhaul_career_career.isActive()`, checked once a second), the mod switches
to **RLS mode** so it adds to the career without breaking its economy. Outside an RLS career, or when RLS is not installed,
none of this applies. It is written against RLS 2.8.0's code (the calls are wrapped in `pcall`, so an RLS update that renames
something degrades to "no charge / no payout" with a log line instead of an error).

| Area | Normal freeroam | RLS career |
|---|---|---|
| Bounty | Your spendable wallet | **Drastically reduced**: every bounty gain, weapon price and heat threshold is multiplied by **0.1**, so heat pacing stays the same but the numbers are small. Pursuit pay is **+$2/s per heat level, max $20/s** (heat 1 = $2/s, heat 10 = $20/s). The bounty is still not money by itself; it is what the escape payout is a share of. |
| Payout | None | **Escaping** pays a share of the bounty: **8% at the start, rising to 25% at Most Wanted Criminal level 6** (see below). Capped at $3,000, nothing under $300 bounty, and each payout in the last 20 minutes takes 25% off the next (down to 25% of normal). Getting busted pays nothing. The HUD shows the percentage, the estimate and your level. |
| Crash Breaker reset | Free at heat 1-2, $5,000 bounty from heat 3 | **Real money, at every heat**, like an insurance claim (see below). Still needs a bar slot. |
| Pit stops | Repair, garage window, car and part prices | **Off.** No repair, no garage window, nothing unlocked. In RLS you own the garage and change cars and parts at its computer. A repair there during a chase is made **instant** (RLS still charges the quote and files the claim), the chase is **frozen while the RLS computer is open**, and it carries on in the repaired car. |
| Weapons | Bar slot + bounty | Bar slot + bounty, with the weapon prices scaled by the same 0.1 (never real money) |
| Heat, units, achievements, sensitivity | as described | Unchanged |

**Most Wanted Criminal (RLS milestone).** The mod adds its own milestone to RLS's milestones screen. Every **escaped** chase earns
**points equal to the heat you reached** (a heat 6 escape = 6 points). Points are stored in RLS's per-profile milestone save data, so
they belong to the career, not the PC. Levels and the escape payout share they unlock:

| Level | Points needed | Escape payout |
|---|---|---|
| 0 | 0 | 8% |
| 1 | 5 | 10.8% |
| 2 | 15 | 13.7% |
| 3 | 35 | 16.5% |
| 4 | 70 | 19.3% |
| 5 | 120 | 22.2% |
| 6 (max) | 200 | **25%** |

The level applies as soon as you reach the points (you do not have to claim the milestone step for it to count). Claiming a step
in RLS also gives a small money reward ($150 x step). The milestone is registered through RLS's `onOverhaulGeneralMilestonesCollect`
hook, which RLS calls on every loaded extension when a career activates. If this mod loads after the career is already active, the
milestone shows up the next time a career is loaded.

**What a reset costs in RLS** (option **"RLS career: how a Crash Breaker reset is paid"**, Alt+M):

- **Insurance claim** (default): the **deductible** of the insurance on the car you are driving (the same figure RLS shows when
  you claim a repair). If the car is in your inventory but uninsured, you pay the private price below. If it is not an
  inventory car at all (a borrowed or spawned car), a flat $1,500.
- **Private**: the car's current **repair estimate**, with a floor of **$2,500**.

The charge is shown as a toast and as a red `-$N` line in the bounty feed. The money is taken with RLS's own payment function (category `insurance`, so it shows in your finance history as
"Most Wanted: Crash Breaker reset"). If you cannot pay, the reset is refused with a toast. It does **not** file an actual
insurance claim, so there is no driver-score penalty or accident record; it only charges the equivalent money.

The numbers (`RLS_BOUNTY_SCALE`, `RLS_RATE_*`, `RLS_PAYOUT_*`, `RLS_RANK_TARGETS`, `RLS_RESET_FALLBACK`, `RLS_PRIVATE_MIN`) are in `data/config.lua`. The code is `compat/rls.lua`.
RLS functions used: `overhaul_career_career.isActive`, `overhaul_career_economy_payment.canPay / pay / reward`,
`overhaul_career_economy_playerAttributes.getAttributeValue`, `overhaul_career_progression_milestones_milestones.saveData`, `overhaul_career_garage_inventory.getInventoryIdFromVehicleId /
getVehicles`, `overhaul_career_repair_insurance.getPlCoverageOptionValue`,
`overhaul_career_market_valueCalculator.getRepairDetails`.

---

## What is locked during a chase

Blocked inputs (via the game's input action filter):

- Reset, home, recover-in-place and teleport actions (except teleport to last road, and the reset key / controller
  reset button, which are handled by the Crash Breaker as above)
- Vehicle selector, parts selector, vehicle debug menu, vehicle switching
- Free camera, drop-at-camera, photo mode, track builder, editor. Walking mode is blocked too, unless the **Get out of your car on foot** option is on (see below).
- AI/traffic toggles, slow-motion controls, and the fun/cheat actions (boom, fire, boost, etc.)

**Fast travel is blocked, the big map is not.** You can open the big map and set waypoints. The quick-travel button
shows a "Fast Travel Locked" toast and does nothing during a chase.

All locks are removed when the chase ends, the level (re)starts, or the mod unloads. Inside a garage the vehicle
options open as described in the pit stop sections above (never in an RLS career).

---

## The HUD

A translucent panel at the bottom centre of the screen, shown only during a chase (and for 6 seconds after, with an
ESCAPED / BUSTED banner). It follows a dark theme with cyan accents.

- **Left:** `HEAT n`, your bounty (the wallet after pit stop spending), and a progress bar to the next heat. In an RLS career a line under the feed shows the escape payout percentage, the estimate and your Most Wanted Criminal level.
- **Above:** the bounty feed (what just paid you), plus the steady `Pursuit time +$N/s` line (N follows your heat).
- **Middle:** the three-slot reset bar and `RESET READY (R, 1 slot, $5,000)` at heat 3+, `RESET READY (R, free)` or `(R, free, slow refill)` at heat 1-2, or `RESET LOCKED (road teleport free)`. In an RLS career the cost is the live insurance / private price.
- **Right:** `COPS ON YOU` (active police cars), `COPS WRECKED`, `RAMMED`, and small evade (green) and arrest (red)
  meters.
- A separate **AMMO** window sits above it while a Universal Weapons gun is equipped (see the weapons section).

The HUD is drawn with ImGui, so the game's single built-in font is used. Colours follow the supplied palette
(`#00bfff` accent, `#e0e0e0` text, `#888` muted, `#00e676` good, `#ff5252` bad, `#9b30ff` purple, `#3b82f6` blue).

### Minimap app with a heat ring

`ui/modules/apps/MwfMinimap` is a UI app ("Most Wanted Freeroam: Minimap", add it from the apps menu like any other app). It is the game's
own Navigation minimap (same code and drawing, see the header of its `app.vue`) with the heat shown around the outside, like the Most
Wanted minimap:

- a ring of ten segments around the minimap that fills with your bounty (segment *n* fills as you climb through heat *n*);
- the heat number with a flame in the top-left corner (it pops when the heat goes up);
- while a police car can see you the ring and the flame flash red / blue, on top of the game's own red / blue flashing minimap edge;
  while the escape meter is winning (you are slipping away) the ring pulses orange.

Use it **instead of** the stock Navigation app, not next to it (both ask the game to draw the minimap into their own box). The data comes
from `mwf_core.getHeatHud()` (`ui/hud.lua`), polled four times a second.

### On foot

With the **Get out of your car on foot** option on, walking mode stays available during a chase. It is free.

- Vanilla walking mode rules still apply: your car has to be almost stopped to get out, and you get into the car in front of
  you the usual way. The chase carries over to your new body (and to the next car), the same hand-over a pit stop uses.
- **Stamina:** sprinting drains it (about 8 s from full), walking or standing refills it (about 10 s, faster when standing
  still). At zero the sprint keys are blocked until it is back to 40%. The HUD shows `ON FOOT   STAMINA |||||||...`.
- **Busted on foot:** an arrest timer (1.5 s) fills while you are **surrounded** (3 or more police within 12 m with no gap wider
  than 240 degrees around you), **cornered** (2 or more within 8 m while you are not sprinting) or **pinned** (a police car within
  3.5 m while you are almost standing still). When it is full you are arrested like any other arrest. Break away (sprint, if you
  have stamina) and it drains. The HUD shows `SURROUNDED!`. While you are on foot the log gets a `On foot: ...` status line every
  3 seconds, which shows what the police around you are doing.
- Vanilla's own arrest and escape rules keep running on foot too.
- **Stealing traffic cars** (option **Steal traffic cars while on foot**, on by default): vanilla does not let you get into AI
  traffic cars. Walk up to a civilian car (within 4 m, driving slower than 8 m/s) and press the walking-mode key: the car is
  taken out of traffic, its AI is switched off and you get in. Pays a small bounty ($500). **Police cars can be carjacked too** (reach 5 m,
  moving slower than 12 m/s, pays $1,500): a unit this mod spawned is released from the chase's unit lists first, so it is never retired, replaced or deleted
  while you drive it. Only KARR and KITT cannot be stolen. The approach is borrowed from the *RLS Career Carjacking* add-on. It is **off in an RLS career** and
  whenever any career (vanilla or RLS) is active, since RLS and its add-on do this themselves.

---

## Options and performance

Open the options page with **Alt+M** (or a controller button you bind to it, or run `mwf_core.toggleOptions()` in the console). It is a game UI page, so it works with a controller: move with the D-pad / stick, A to change a row, B to close. Settings are saved to
`/settings/mwf_options.json`.

| Option | Default | What it does |
|---|---|---|
| Hide civilian traffic during chases | Off | While you are chased, civilian traffic is hidden and cannot respawn. Police are not affected. Civilians return, a couple per frame, when the chase ends (or as soon as you switch the option off). Less load, fewer hitches. |
| **Weapons can start a chase** | **On** | Using a weapon (Weapon Panel, or Universal Weapons guns) on a police car or a civilian car counts as an offense, but only one a police car can see you do (the same visibility check vanilla uses for every offense). Weapons panel hits are matched to the nearest car in front of you; guns to a car in your line of fire. |
| **Get out of your car on foot** | **On** | During a chase you can stop, press the walking-mode key to get out, run to another car and get in. See [On foot](#on-foot). Takes effect from the next chase. |
| **Steal traffic cars while on foot** | **On** | While on foot in a chase, walk up to a civilian car and press the walking-mode key to carjack it (see [On foot](#on-foot)). Not used in an RLS career. |
| Smooth spawning | On | If the frame rate is already low (under about 22 fps), new unit spawns are held back, up to 8 seconds. |
| Seconds between unit spawns | 1.5 | Spacing between extra-unit spawns (0.5 to 6). |
| Wave size | 100% | Scales how many units and props each wave brings (25% to 100%). |
| **Pit stop costs** | **On** | Swapping or modifying your car at a pit stop costs bounty (see [Pit stop economy](#pit-stop-economy-cars-and-parts-cost-bounty)). Off = free, with the vanilla selector. |
| **Generate pit stops from map POIs** | **On** | Maps without gas stations and/or garages get some made from their POIs (see above). |
| **Police sensitivity** | **1.00** | How easily police start a chase (0.25 to 2.00). 1.00 is the game's default. Lower: speeding alone no longer starts a chase (running a red light, or speeding plus another offense, still does); higher: even minor offenses do. A chase already in progress is unaffected. Details under [Police sensitivity](#police-sensitivity). |
| **RLS career: reset payment** | **Insurance claim** | In an RLS career, how a Crash Breaker reset is paid: the car's insurance deductible, or privately (repair estimate, at least $2,500). Ignored outside RLS. |
| Price factor | 50% | Share of the real price that cars and parts cost, 10% to 100%. |

### Police sensitivity

In the vanilla game a pursuit starts once a car's offense score reaches 100, and a single speeding offense is worth exactly
100, so any speeding in view of a cop starts a chase. The sensitivity slider scales two vanilla values (`s` = the slider):

| Value | Formula | At 0.5 | At 1.0 | At 2.0 |
|---|---|---|---|---|
| `strictness` (how large a fault must be to count as an offense) | 0.5 x s, clamped to 0.1 to 0.8 | 0.25 | 0.50 | 0.80 |
| Score needed to start a pursuit (`scoreLevels[1]`) | 100 / s | 200 | 100 | 50 |

Offense scores: speeding 100, street racing 200, reckless 250, wrong way 150, red light 200. So at 0.5, speeding alone is not
enough, but a red light or speeding plus another offense is. The values are only changed outside a chase (a running chase always
uses the vanilla values, so its difficulty is unchanged) and are re-checked every 2 seconds, because the game resets them on
level load. At exactly 1.00 the mod touches nothing. The log line `Police sensitivity ...` shows what was applied.

If new waves make the game stutter, lower the wave size and raise the spacing, or turn on the civilian toggle.

**Cleanup:** when a chase ends, every unit and prop the mod spawned is removed: units once they are 120 m away (or after
30 seconds at the latest), props immediately. Units that fall out of the newest 3 heat groups during a chase are removed
the same way. The normal police already in traffic are never touched.

---

## Controls

| Input | Action |
|---|---|
| **R** / controller reset button | In a chase: Crash Breaker reset (1 slot; free at heat 1-2 with a slow refill afterwards, $5,000 from heat 3). Otherwise the normal game reset. |
| **Alt+M** | Open or close the Most Wanted Freeroam options |
| **Alt+K** | Open or close the achievements window |
| **Alt+G** | Open or close the garage window (only inside a garage during a chase; opening it pauses the chase) |
| **Alt+W** | Weapon Panel (from the Weapon Panel mod) |
| **T** / left trigger | Fire Universal Weapons (from that mod) |
| Teleport to last road | Always available |

The Alt+M, Alt+G and Alt+K bindings are added by `settings/inputmaps/keyboard_mwf.json`. Rebind them in the game's controls menu
under "Most Wanted Freeroam: ..." if they clash with another mod.

---

### Achievements

The mod has its own **in-game achievements**: 33 of them, with an unlock banner at the top of the screen and a toast, and a
list with progress bars in the achievements window (**Alt+K**, or the button in the options window). They are tracked
everywhere, including outside chases, but they only unlock during a chase: a goal reached outside one waits until the next chase starts.

**Why not Steam achievements?** Steam (and Epic) achievements are a fixed list defined by the game's developer inside the
game's Steamworks configuration. A mod cannot add to that list, and BeamNG's own achievement system only unlocks that fixed
list (the career milestones are separate and career-only). So these are the mod's own, saved to
`/settings/mwf_achievements.json`. To reset them press **Reset achievements** (press twice to confirm) in the options page or the achievements page, or delete that file while the game is closed.

| Achievement | Goal |
|---|---|
| You can run but you can't hide! | Trigger a pursuit |
| Serve and Protect (Yourself) | Wreck your first police car |
| Now We're Cooking | Reach heat 3 |
| That's a lot of cops! | Reach heat 6 |
| Public Enemy Number One | Reach heat 10 |
| Is This a Parade? | Have 10 police cars on you at once |
| You're still wanted. We just gave up the chase | Escape with a heat level of 5 or more |
| Now You See Me, Now You Don't | Escape 10 chases |
| Frequent Flyer | Get busted 5 times |
| Still Going, Officer? | Survive a single chase for 15 minutes |
| Pocket Change | Reach a bounty of $100,000 in one chase |
| Now that's a big bounty | Reach a bounty of $500,000 |
| You're a millionaire now! | Reach a bounty of $1,000,000 |
| You're a monster! | Blow up 100 cops during one pursuit |
| Donut Shortage | Wreck 500 police cars in total |
| Big Rig Down | Wreck a special pursuit semi |
| Disarming Personality | Wreck an armed police unit |
| Michael Knight Would Be Proud | Be chased by both KARR and KITT in one chase |
| Lights Out! | Fire the EMP |
| Spray and Pray | Take out 25 police cars with a gun |
| Arms Dealer | Use 50 weapons during chases |
| Tokyo Drift, Local Edition | Drift 5 km (3 miles) during chases |
| Dodged a Missile | Near-miss a police car charging straight at you at 60 mph (97 km/h) or more |
| Really Dodged a Missile | Same, at 100 mph (160 km/h) or more |
| Living on the Edge | Get 100 near misses |
| Nearly missing the near miss | Trade paint 100 times |
| Highway to the Danger Zone | Stay above 100 mph (160 km/h) for 3 minutes in a row |

| Wrong Way Wallace | Drive 2 km (1 mile) the wrong way during chases |
| Pedal to the Metal | Drive 20 km (12 miles) above 200 km/h (125 mph) during chases |
| Nine Lives (Plus One) | Use the Crash Breaker 10 times |
| Trade-In Value: Mostly Smoke | Buy a car at a garage during a chase |
| Cash Is Just a Number | Spend $100,000 of bounty at garages |
| Quick Oil Change | Visit a garage at heat 5 or higher |

Living on the Edge and Nearly missing the near miss pay $2,500 of bounty when they unlock, and Highway to the Danger Zone pays
$5,000. In an RLS career those bounty amounts are scaled down like all bounty, and each one also pays real money ($300 / $300 /
$500) and adds Most Wanted Criminal milestone points (3 / 3 / 5).

**Units:** the distance and speed achievements follow the game's own unit setting (`uiUnitLength`, Options > User Interface). With
imperial units the wording, the progress display and the goal itself change: drift 3 miles, drive 1 mile the wrong way, drive 12
miles above 125 mph. The speeding threshold of the reset bar changes with it (125 mph = 201.2 km/h instead of 200 km/h). Stats are
stored in metres, so switching units never loses progress. In `data/achievements.lua` a `dist = {metric = km, imperial = miles}` field
gives the two goals, and `descOf` / `goalOf` resolve them; the player's system comes from `MWF.util.unitSystem()`.

Notes on what counts: "wreck" means a police car put out of action (not necessarily exploded); the bounty goals use what you
**earned** in one chase, not your wallet; "gun" kills are cops that went down within 4 seconds of you firing a Universal Weapons gun
(the same rule that discounts their bounty); the weapon counts include Weapon Panel buttons that went through and every paid slot
of Universal Weapons ammo.

**How it works (technical):** other modules report events with two calls, `MWF.achievements.add(stat, n)` (accumulating stats such as
wrecks or metres drifted) and `MWF.achievements.max(stat, v)` (best-ever stats such as heat reached or bounty in one chase). An
achievement in `data/achievements.lua` unlocks when its `stat` reaches its `goal`. To add one: add a row to that list and, if it needs a
new stat, call `add` or `max` from where the event happens. Progress autosaves every 30 s while there is unsaved progress, and on
unlock, at the end of a chase and when the extension unloads.

---

## Files in this mod

```
most_wanted_freeroam/
  README.md                                      this technical readme
  CHANGELOG.md                                   technical changes per version
  PUBLISHING_README.md                           plain-language readme for the mod page
  scripts/mostWantedFreeroam/modScript.lua       loads the extension and keeps it loaded
  lua/ge/extensions/mwf/
    core.lua                                     extension mwf_core: loads the modules below, wires the game's hooks, main loop
    core/    registry.lua                        the shared object (S state, MWF module lookup)
             state.lua                           all mutable state, with initial values
             util.lua                            player vehicle, pursuit data, reset-bar check, toasts
             options.lua                         option defaults, load / save of /settings/mwf_options.json
    data/    config.lua                          tuning numbers (bar, bounty, heat, weapon prices)
             achievements.lua                    the achievement list (names, descriptions, stats, goals)
             units.lua                           police units per heat level, KARR / KITT, roadblock props, unit limits
    chase/   session.lua                         chase start / end and the vanilla hooks
             pursuit.lua                         per-frame scoring, bounty awards, wreck payouts, heat changes
             bar.lua                             the reset bar (drift / wrong way / speeding)
             style.lua                           style bonuses: drift, near miss, trading paint, missile dodges
             onfoot.lua                          getting out of the car: stamina, busted on foot
             difficulty.lua                      heat scaling and police sensitivity
             escalation.lua                      spawning, reinforcements and clean-up of extra units and props
             breaker.lua                         Crash Breaker reset
             lockdown.lua                        input lockdown, recovery intercept, fast-travel guard
             civilians.lua                       optional hiding of civilian traffic
    achievements/ tracker.lua                    unlock logic, stats, save / load of /settings/mwf_achievements.json
    compat/  rls.lua                             RLS Career Overhaul mode: reset charged as a claim, escape payout, pit stops off
             mwm.lua                             makes the Most Wanted Mission minimap follow this mod's heat (runtime wrap, no file edited)
    world/   pits.lua                            gas stations, garages, POI fallback, repair, pursuit hand-over
    economy/ garage.lua                          wallet, prices, vehicle / parts guards, garage pause
             weapons.lua                         Weapon Panel wrapper, Universal Weapons slots, weapon bounty and costs
    ui/      theme.lua                           palette and ImGui drawing helpers
             hud.lua                             chase HUD and ammo window
             garage_window.lua                   opens / closes the Vue garage shop and answers its data calls (shop*, incl. tuning)
             options_window.lua                  options page (Lua side of MwfOptions.vue)
             achievements_window.lua             achievements page (Lua side of MwfAchievements.vue, Alt+K) and the unlock banner
  ui/ui-vue/mods/most_wanted_freeroam/           the Vue pages: index.js, MwfShop.vue (garage: vehicles, parts, tuning), MwfOptions.vue, MwfAchievements.vue
  ui/modules/apps/MwfMinimap/                    the minimap app with the heat ring (app.json, app.vue, app.png)
  lua/vehicle/extensions/auto/mwfWeapons.lua     vehicle-side ammo gate for Universal Weapons (does nothing without them)
  lua/ge/extensions/core/input/actions/mwf.json  input actions for the options, garage and achievements windows
  settings/inputmaps/keyboard_mwf.json           default key bindings (Alt+M options, Alt+G garage, Alt+K achievements)
```

Saved at runtime: `/settings/mwf_options.json`, `/settings/mwf_achievements.json` and `/settings/mwf_tunes.json` (saved garage tunes).

---

## Changes made to other mods

**None.** Weapon Panel and Universal Weapons are used exactly as published. Earlier development versions edited their
files; those edits are gone, and the original files were restored. This mod ships none of the other authors' code, which
keeps it clear of the Weapon Panel's "DO NOT REUSE CODE" header.

---

## Known limitations

- **Not covered by the weapon bounty:** Universal Weapons hits. Their projectiles explode inside each vehicle's own
  code with no clean target to credit. Police they take out still earn the smashed bonus.
- **Two Universal Weapons on one car** each get their own round pool, but share the same reset bar.
- **Universal Weapons round counting** is time-based, so it can differ from the real shot count by about one round, and a
  held trigger can fire one extra round or so when a gun runs dry.
- **Gating relies on the other mods' current internals** (see Compatibility notes).
- **Chain Missile** pays only for its first target, not every car it hops to.
- **Resetting from the pause menu ends the chase** (as busted): the pause menu's Reset button resets the car directly, so `session.lua` wraps
  `ui_pause_providers_vehicleTabInteractions.executeVehicleTabInteractionAction` once to note the click, and a reset of your car in the 8 s after it (that the Crash Breaker, a pit stop or the walking mode did not cause) ends the chase.
- **Spawning or reconfiguring a car from the pause menu cannot be blocked** by the input filter. Doing so (outside a pit
  stop) ends the chase as busted. The fast-travel button on the big map is visible but does nothing during a chase.
- **The Crash Breaker recover can place you in an unexpected spot** (the game's recover rewinds to an earlier recorded
  position and may adjust it). If a reset puts you somewhere odd, look for the `Reset: ...` log lines.
- **The Crash Breaker explodes only your own car.** Unlike Most Wanted it does not blow up nearby cars or switch the
  camera.
- **Garage and gas station detection** depends on the level's facility data. A level without that data only gets pit stops if the POI fallback option is on, and generated stops sit on spawn points, which can be on a mountain top or in a cave, so some may be hard to reach.
  The log line `N pit stops loaded` tells you how many were found.
- **RLS compatibility** is written against RLS 2.8.0's code. A later RLS update that renames or changes the functions it uses would turn the reset charge and escape payout off (with a log line) rather than cause errors. `RLS charge ...` and `RLS escape payout ...` appear in `BeamNG.log`.
- **Pit stop economy notes:** the car list comes from the game's own vehicle data
  (cars without a value are not listed), part prices rely on the part data the game exposes (if a part's value cannot be read it
  counts as free), and the vanilla parts configurator cannot be filtered to affordable parts, so
  unaffordable changes are refused instead.
- **Heat 6+ semis and elite interceptors** use Most Wanted Mission vehicle configs, and **heat 8+ armed units** use Universal Weapons configs. Without those mods ordinary police vehicles are spawned instead.
- **The garage pause** uses the game's sim-time pause; `Garage: chase paused / resumed` is logged.
- **The mod wraps a few game functions** (the global `resetGameplay` during a chase, and the big map's `teleportToPoi`).
  Another mod that replaces the same functions could conflict.
- **Not supported:** the vanilla career, scenarios, missions, BeamMP (RLS careers are covered by RLS mode). The HUD font is the game's default (no custom fonts).
- If extra units do not appear, check the log (`Heat N unit spawned: ...` lines). Spawning and teleporting units into traffic depends on the level's traffic setup.
- **Bounty also refills the bar:** 5% of every bounty payout goes into the reset bar, so a 5,000 weapon hit gives back
  about 250 points (most of a slot). That is intentional but easy to retune (`PASSIVE_BOUNTY_PCT`).
- **Spike strip prop:** the spawn call sometimes does not hand back the vehicle it created. The mod now looks for the new
  vehicle and adopts it (`adopted spawned spikestrip` in the log) so it is tracked and cleaned up.

---

## Troubleshooting and logs

Everything the mod does is written to `BeamNG.log` with the tag `mwf`. Useful lines:

| Log line | Meaning |
|---|---|
| `N pit stops loaded` | Gas stations and garages found for the level |
| `Chase started` / `Chase ended (...)` | Session start and end (reason in brackets) |
| `pursuit action: evade/arrest/...` | Every pursuit event the game reported for your car |
| `Heat N unit spawned: ...` | An extra unit was spawned |
| `Roadblock prop spawned: ...` / `adopted spawned ...` | A sawhorse or spike strip was spawned (or found after the spawn call returned nothing) |
| `Chase over: removing N spawned units/props` | Cleanup started |
| `Universal Weapon slot request ...` / `mwfWeapons: ...` | A Universal Weapons gun asked for a slot, and the answer |
| `Reset request accepted from ...` | A reset was accepted, and from which input |
| `Reset: recovering from ... / now at ...` | Where a reset moved you |
| `Pit stop entered: ...` | Which gas station or garage fired, and your distance to it |
| `fallback pit stops from POIs (...)` | Pit stops generated for a map without any |
| `Garage: chase paused / resumed` | The garage window froze or resumed the chase |
| `Police sensitivity ...` | The sensitivity slider changed the game's pursuit settings |
| `Achievement unlocked: ...` | An achievement was earned |
| `RLS career detected: RLS mode on` | An RLS career was found; `RLS charge ...` (reset), `RLS escape payout ...` and `Most Wanted Criminal: +N points ...` follow |
| `recover_vehicle intercepted outside a chase ...` | A stale intercept was caught and cleared |

Common problems:

- **Recover/reset does nothing outside a chase:** the car may still have the chase-only "report recover presses" flag
  set. The mod clears it when a chase ends, at level start, on load, and every few seconds outside a chase. If it
  persists, reload the level and report it with the log.
- **Arrest or evade never triggers:** read the `pursuit action` lines. If the game logs the event and the HUD stays, it
  is a mod bug. If the game never logs one, it is the game's own pursuit logic (note that evade time grows with heat).
- **Weapons are free during a chase:** the other mod's window title, button labels or jbeam keys may have changed in an
  update, or the other mod is not loaded. Check that its panel or part actually exists.
- **A stray extra unit never disappears:** note where it was and send the log lines.

---

## Tuning

Numbers live in data files (`data/achievements.lua` holds the achievement list), so rebalancing never means touching logic:

- `mwf/data/config.lua`: bar size and fill rates, bounty amounts, heat thresholds and pursuit pay per second, repeat falloff,
  weapon bounties, weapon and reset costs, wreck payouts, gun-kill share, garage list size, and every `RLS_*` value (bounty scale, pursuit pay, payout shares, Most Wanted Criminal point targets).
- `mwf/data/units.lua`: which police cars appear at each heat, their wreck multipliers, armed units and their fallbacks,
  KARR / KITT, roadblock props, how many heat groups stay active, the unit cap and the reinforcement check interval.

A few constants belong to one module and stay next to the code that uses them: Crash Breaker slow motion and duration
(`chase/breaker.lua`), pit stop radii and cooldown and the POI fallback spacing (`world/pits.lua`), car and part price
clamps (`economy/garage.lua`), blocked input groups (`chase/lockdown.lua`), offense labels and the heavy-model multipliers
(`chase/pursuit.lua`), Weapon Panel button names (`economy/weapons.lua`), sensitivity formulas (`chase/difficulty.lua`).
The in-game options cover the performance-related and difficulty-related ones.

---

## Uninstalling and reverting

1. Remove (or disable) the `most_wanted_freeroam` folder. Inputs, input blocks, and the vehicle flags are cleared when the
   extension unloads or the level restarts.
2. The other mods are untouched, so there is nothing to revert in them.
3. Delete `/settings/mwf_options.json` if you want to clear saved options, `/settings/mwf_achievements.json` to reset achievements, and `/settings/mwf_tunes.json` to delete saved tunes.

---

## Developer notes

### Architecture

`core.lua` is the extension the game loads (`mwf_core`). It holds no game rules: it loads the module files, runs the main loop that calls them each frame, and passes
the game's hooks on to them. Every other file is a small module in its own folder (see
[Files in this mod](#files-in-this-mod)).

- **Module shape.** A module is a plain Lua file that returns a table `M`. Everything in `M` (the `on*` hooks and public
  functions such as `spendSlot`) is merged into `mwf_core`, so the game and the vehicle-side extension call it as
  `mwf_core.<name>`. The two data modules (`data/config`, `data/units`) and `ui/theme` instead return a table of constants
  or helpers, which other modules read as `CFG`, `UNITS` and `UI`.
- **Shared state.** All mutable state lives in one table `S` (`core/state.lua` lists every field with its initial value).
  Modules read and write `S.session`, `S.bar`, `S.garage` and so on directly. Nothing that changes at runtime is kept in a
  module-level local if another module needs it.
- **Calling another module.** Each function module registers the functions others need in `MWF.<module>` at its end, for
  example `MWF.pits.loadGasStations()`. Lookups happen at call time, not load time, so modules never `require` each other
  and there are no circular dependencies. `MWF.core` is the extension table itself.
- **Load order** is set in `core.lua` (data and helpers first, then logic, then the windows, then `chase/session`). Every file
  is loaded with `rerequire`, so reloading the extension (or restarting the level) always reads the files again.
- **Adding a module:** create the file in the matching folder, `require` the registry, define your functions, set
  `MWF.<name> = {...}` for the ones others call, `return M` for hooks, then add the path to the list in `core.lua` and call
  it from wherever it belongs (usually `onUpdate`).
- **Adding state:** add a field with its initial value to `core/state.lua`, and use it as `S.<name>`.
- **Adding an option:** default in `S.options` (`core/state.lua`), a pointer in `S.optUI` and a control in
  `ui/options_window.lua`, and the load line in `core/options.lua`. Saved values are only accepted if their type matches the
  default.
- **Testing without the game:** the files load under plain LuaJIT. A stub of the few globals used (`log`, `be`,
  `gameplay_police`, `ui_imgui`, ...) is enough to load `core.lua` and run `onPursuitAction` and several `onUpdate` frames,
  which catches broken cross-module references. A real test still needs BeamNG.

### Calls and hooks

- Extension names: `mwf_core` (game side) and `mwfWeapons` (vehicle side). Calls between them:
  `mwf_core.requestSlot(vehId, roundsPerSlot, fireElectric)` and `mwfWeapons.grantSlot(fireElectric, ok, rounds)`.
  Other public calls: `mwf_core.spendSlot(name, slots, cost)`, `mwf_core.weaponHit(name, vehId)`, `mwf_core.reportAmmo(...)`,
  `mwf_core.toggleHud()`, `mwf_core.toggleOptions()`, `mwf_core.toggleGarage()`, `mwf_core.getBar()`,
  `mwf_core.getSession()`, `mwf_core.isFastTravelLocked()`. The pit stop economy also exposes `vehicleGate`, `vehicleCharged`,
  `partsGate`, `partsCharged` for its wrappers.
- Vanilla hooks used: `onPursuitAction`, `onStartRecovering`, `onVehicleSwitched`, `onVehicleReplaced`,
  `onVehicleDestroyed`, `onVehicleResetted`, `onClientStartMission`, `onClientPostStartMission`, `onClientEndMission`, `onGetRawPoiListForLevel`, `onExtensionLoaded`,
  `onExtensionUnloaded`, `onUpdate`.
- The pit stop economy wraps `core_vehicles.replaceVehicle` / `spawnNewVehicle` and `core_vehicle_partmgmt.setPartsTreeConfig`
  once and asks the live `mwf_core` on every call, so a reload cannot leave them stuck. Own spawns bypass the price check.
- Vanilla APIs used: `gameplay_police` (pursuit data, vars, modes, props), `gameplay_traffic` (traffic data, insert,
  teleport), `gameplay_rawPois` (POI fallback), `core_input_actionFilter`, `freeroam_facilities` and `freeroam_gasStations`,
  `core_vehicles.spawnNewVehicle`, `simTimeAuthority` (Crash Breaker slow motion, garage pause), and the vehicle-side `recovery`
  module (`recoveryHooksOnly`).
- Design references: the Most Wanted Mission mod (reset bar, heat levels, per-heat police groups, roadblock props, gas
  station and Crash Breaker behaviour). No code from it is loaded at runtime.
