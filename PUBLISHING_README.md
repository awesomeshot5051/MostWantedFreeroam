# Most Wanted Freeroam  (version 2.0.0)

**Turn BeamNG's police chases into a Most Wanted-style pursuit that keeps escalating.**

Drive recklessly near a cop in freeroam and the chase starts like normal. This mod then keeps it going: your **bounty**
climbs, the **heat** rises up to level 10, and the police bring more and nastier units the longer you survive. Escape or get
busted and the chase simply ends. There is no end screen, and the next one starts fresh.

It works on any freeroam map and needs no other mod for the core experience.

---

## The idea in 30 seconds

- **Everything you do in a chase earns bounty:** surviving, ramming cops, wrecking cop cars, hitting traffic, breaking traffic laws.
- **More bounty means more heat.** Heat 1 is the normal police. By heat 3 you get roadblocks, by heat 4 spike strips, by heat 6
  special pursuit semis, by heat 8 armed police that shoot at you, and at heat 10 a howitzer van.
- **Bounty is also your money.** You spend it on resets (from heat 3), weapons, cars and parts. Spending never lowers your heat, so you can
  never "buy your way out" of a chase. (In an RLS career it works differently; see the RLS section.)
- **You can't just reset or teleport your way out.** Resets are limited by a three-slot *reset bar* that you fill by driving
  dangerously.

---

## Heat levels

| Heat | What arrives |
|---|---|
| 1 | The normal police already on the road |
| 2 | Extra patrol cars, a police van, a sheriff SUV |
| 3 | Pursuit units and **sawhorse roadblocks** |
| 4 | Unmarked cars, interceptors and **spike strips** |
| 5 | Fast interceptors and **heavy police vans** and an **armored police truck** |
| 6 | Elite interceptors and **special pursuit semis** |
| 7 | More elite units and more semis |
| 8 | **Armed police** (minigun, 50cal) and a **KARR** |
| 9 | Heavy armed units (autocannons) and a **KITT** |
| 10 | A **howitzer van**, armed interceptors, autocannons, semis |

If you wreck police cars, the ones in the current heat group are replaced after a few seconds, so smashing cops doesn't
make the chase easier. The higher you go, the faster the reinforcements arrive. Police are also tougher as heat rises: you take
longer to lose them and they arrest you faster.

Some of the units need an optional mod (see [What else is supported](#what-else-is-supported)). Without it, the mod
substitutes an ordinary police car, so nothing breaks.

---

## Bounty

You earn bounty from:

- **Staying alive.** A steady income per second that grows with heat: $10/s at heat 1, $100/s at heat 3, up to $500/s at heat 10.
- **Ramming and wrecking police cars.** What a wrecked cop is worth depends on the car: a plain patrol car pays about $1,000,
  a late-game semi or armed unit pays several thousand.
- **Hitting civilians** and **breaking traffic laws** (speeding, red lights, wrong way, reckless driving). Repeating the same
  offense over and over pays a little less each time.

The bounty on screen is your wallet: what you earned minus what you spent.

---

## The reset bar

Along the bottom of the screen is a bar split into three slots. It fills when you:

- **drift**,
- **drive the wrong way**,
- **speed** (above 200 km/h, or 125 mph if your game uses imperial units),

and it also fills slowly by itself, faster at higher heat, plus a little from every bounty payout. It starts empty at the
beginning of each chase.

A slot is what you spend to:

- **Reset your car** (R or your controller's reset button). You get the *Crash Breaker*: slow motion, your car explodes, then
  you're put back on the road.
- **Fire a weapon**, if you have one of the supported weapon mods.

### What a reset costs

| Heat | Reset cost |
|---|---|
| 1 and 2 | **Free**, but afterwards the bar refills at about a third of normal speed for a minute |
| 3 and up | **$5,000 bounty** (and the bar slot) |

Teleporting to the last road is always free. Other resets, home teleports and fast travel are blocked during a chase.

---

## Pit stops: gas stations and garages

- **Gas station:** drive in and your car is **repaired once**.
- **Garage:** drive in and you also get the **garage shop** (laid out like the RLS computer, at the listed price, no haggling), where you can change cars or parts. **The chase is paused while
  the window is open**, so you can't sit there waiting for something to happen. Close the window and the chase resumes.

Everything costs bounty, so you can only change into cars you can afford, and you can't tune up the perfect car for free:

The garage shop has three tiles:

- **Vehicle Shop:** every car you can drive, with a search box, brand filter, sorting, an "Affordable only" switch and pages (12 cars at a time). Pick one, check the details and confirm to buy.
- **Parts Shop:** categories, then slots, then parts, with a search box on every level. Put parts in the cart, check the total and confirm. Weapon mounts cost money too.
  Parts you buy are yours for the rest of that chase, so putting one back on is free.
- **Tuning:** change suspension, tyre pressure, gearing, boost and every other tuning setting the game offers, then press Apply. It is free. You can save tunes per car
  model, load them later, undo your changes or reset to the car's defaults.

Everything works with a controller as well as the mouse. Prices are half of each car's real value by default (changeable in the options).

**Maps without gas stations or garages:** some maps don't define any. If that's the case, the mod can turn points of interest
(spawn points and similar) into pit stops, alternating between garages and gas stations, so you always have both. It never
replaces a map's own gas stations or garages. On the big map, those points of interest get the garage or fuel icon and a "Garage:" / "Gas station:" in front of their name, so you can tell them apart. You can switch this off in the options.

---

## Style bonuses

Extra bounty during a chase, with a live drift counter on screen:

- **Drifting** pays 10 x a Forza-style drift counter. It is much more sensitive than the game's own, it keeps your combo through direction changes, and a
  spinout still pays what you had. Circling in place is nerfed, so you can't farm it.
- **Near misses** and **trading paint** (side-swipes) pay a bonus that grows when you chain them.

Several achievements are tied to these (see below).

## Getting out of your car

With the **Get out of your car** option on, you can stop during a chase, get out and run to another car. Sprinting uses stamina, and the police can arrest you
on foot if they surround, corner or pin you. With **Steal traffic cars** on, you can also take a civilian car **or a police car** by walking up to it and pressing the walking key
(not used in RLS careers).

## Minimap with a heat ring

Add **Most Wanted Freeroam: Minimap** from the apps menu (use it instead of the stock Navigation app). It shows your heat as a ring of ten segments and a heat number with
a flame, and flashes red and blue while the police can see you. If you use the Most Wanted Mission mod, its own minimap follows this mod's heat during a chase.

---

## Weapons

If you have the optional weapon mods installed, using them during a chase costs reset bar **and** bounty. Outside chases they stay
free, exactly as the mods intend.

| Weapon | Bar | Bounty |
|---|---|---|
| Missile | 1 slot | $1,500 |
| Chain Missile | 1 slot | $2,000 |
| **EMP** | **all 3 slots** | $3,000 |
| Tire Pop | 1 slot | $500 |
| Throttle / Brake / Steering / Parking brake lock | 1 slot | $400 |
| Machine gun ammo (40 rounds) | 1 slot | $1,000 |
| Big gun ammo (5 rounds) | 1 slot | $2,000 |

Landing hits pay bounty back. Weapon hits pay between $500 and $5,000. Guns pay less than other ways of taking cops out
(a cop that goes down while you're firing a gun pays about a third), so you can't farm bounty by standing still and shooting.

---

## Options

Press **Alt+M** to open the options window. A few of the useful ones:

| Option | What it does |
|---|---|
| **Police sensitivity** | How easily police start a chase. 1.00 is the game's normal. Turn it **down** if speeding a little near a cop starts a chase every time (then you need something worse, like running a red light). Turn it **up** to make cops jumpier. Doesn't change a chase that's already running. |
| **Pit stop costs** | On by default. Switch it off for free car and part changes at pit stops. |
| **Generate pit stops from map POIs** | On by default. See the pit stops section above. |
| **Price factor** | How much of a car's real price you pay (10% to 100%). |
| **Hide civilian traffic during chases** | Less load, fewer hitches. Police are not hidden. |
| **Weapons can start a chase** | On by default. Using a weapon on a police or civilian car counts as an offense, if a cop sees it. |
| **Get out of your car on foot** / **Steal traffic cars while on foot** | On by default. See "Getting out of your car" above. |
| **Smooth spawning / spawn spacing / wave size** | If new waves of police make the game stutter, lower the wave size and raise the spacing. |

Your settings are saved automatically.

**Controls:** **Alt+M** options, **Alt+K** achievements, **Alt+G** open or close the garage window (only inside a garage during a chase). You can rebind
them in the game's controls menu, and bind them to a controller button there too. The windows themselves work with a controller (D-pad / stick, A to select, B to go back).

---

## RLS Career Overhaul

If you play the **RLS Career Overhaul**, the mod detects your career and adjusts itself so it adds to RLS without breaking its economy:

- **Bounty is drastically reduced.** Everything still works the same way, but the numbers are about a tenth of normal, and
  steady pursuit pay is only **$2 per second per heat level, up to $20/s**. Bounty is not money by itself: it's what your escape reward is
  a share of.
- **Escaping pays a share of your bounty: 8% to start, up to 25%.** The more you escape, the bigger the share, through a new milestone in
  RLS's milestones screen called **Most Wanted Criminal** (6 levels; every escape earns points equal to the heat you reached).
  Payouts are capped and shrink if you've been paid recently, so chases are a fun extra, not a way to farm money. Getting busted pays nothing.
- **Resets cost real money, like an insurance claim.** Using the Crash Breaker charges you the **deductible** of the car's insurance. In
  the options you can switch it to **private**, which charges the car's repair estimate instead (at least $2,500). If you can't pay,
  you can't reset.
- **No pit stops.** The mod's gas station repair and garage window are switched off in RLS. In RLS you own your garage, and you
  change cars and parts at its computer, like normal. If you repair your car at the computer during a chase, the chase is paused while the computer is open, the repair is instant (you pay what RLS quoted) and the chase carries on afterwards.
- Weapons work as usual, but their bounty price is a tenth as much. Heat levels, police and achievements are unchanged.

Outside an RLS career, none of this applies.

---

## Achievements

There are **33 achievements**, with a banner when you unlock one and a list with progress bars in the achievements window
(**Alt+K**). A few of them: *You can run but you can't hide!* (trigger a pursuit), *That's a lot of cops!* (reach heat 6),
*You're still wanted. We just gave up the chase* (escape at heat 5 or higher), *Now that's a big bounty* ($500,000),
*You're a millionaire now!* ($1,000,000), *You're a monster!* (blow up 100 cops in one pursuit), *Big Rig Down* (wreck a special
pursuit semi), *Lights Out!* (fire the EMP) and *Michael Knight Would Be Proud* (get chased by both KARR and KITT), *Really Dodged a Missile* (near-miss a cop charging at you at 100 mph) and *Highway to the Danger Zone* (stay above 100 mph for 3 minutes in a row). Some are
easy, some will take many chases, and a few are very hard. The distance and speed ones follow your game's unit setting, so
imperial players see miles and mph (and the goals change to match), and metric players see km and km/h.

These are this mod's own achievements, not Steam achievements (mods can't add those). They are saved to
`/settings/mwf_achievements.json`. To start over, press **Reset achievements** in the options or achievements window (it asks you to press twice). Achievements only unlock during a chase.

---

## What else is supported

None of these are required. Install the ones you like.

| Mod | What it adds |
|---|---|
| **Weapon Panel** | Its weapons become usable in chases, paid for with reset bar and bounty. |
| **Universal Weapons** | Its guns work the same way, and heat 8+ adds **armed police** that use its roof guns. |
| **Most Wanted Mission** | Its elite interceptor and special pursuit semi cars show up from heat 6. |
| **Knight Rider pack (KARR and KITT)** | One **KARR** joins at heat 8 and one **KITT** at heat 9. They are indestructible. |

If any of them is missing, the matching units are replaced with an ordinary police car or van.

This mod doesn't modify or include any other mod's files. Everything is done at runtime.

---

## Installing and removing

- **Install:** put the mod in your BeamNG mods folder like any other, and start a freeroam level with **traffic and police enabled**
  (the mod reacts to the game's own police chases; it doesn't start them).
- **Remove:** delete or disable it. Any chase locks are cleared when the level restarts or the mod unloads. Delete
  `/settings/mwf_options.json` if you want to clear your saved options, and `/settings/mwf_tunes.json` for saved tunes.

---

## Good to know

- **Chases only.** Outside of a chase the game behaves exactly as normal, including resets, vehicle swapping, weapons and pit stops.
- **Built for freeroam.** It isn't designed for scenarios, missions, the vanilla career or BeamMP. The one career it supports is RLS.
- **If something behaves oddly,** please report it and include your `BeamNG.log`; the mod writes clear lines starting with `mwf` that say what it was doing.
- Swapping, reconfiguring or resetting your car through the pause menu can't be fully blocked. Doing any of it outside a pit stop ends the chase.

---

## Credits

Inspired by the **Most Wanted Mission** mod; this is a standalone rewrite that doesn't use its code. Thanks to the authors of
**Weapon Panel**, **Universal Weapons** and the **Knight Rider pack** for the optional integrations.

## What's new

The technical details of every change are in the changelog on GitHub (CHANGELOG.md in the mod's repository).

### 2.0.0
**New features**
- **Style bonuses:** a Forza-style drift counter with a combo (circling in place is nerfed), near misses and trading paint, all chaining.
- **New achievements:** Dodged a Missile, Really Dodged a Missile, Living on the Edge, Nearly missing the near miss, Highway to the Danger Zone. The
  last three pay a little bounty (and in RLS, real money and milestone points). Achievements now only unlock during a chase.
- **Weapons can start a chase** (option): using a weapon on a police car or a civilian car is an offense, if a cop sees it.
- **Get out of your car** (option): stop, get out, run to another car. Sprinting uses stamina, and the police can bust you if they surround, corner or pin you.
- **Steal civilian traffic cars** while on foot in a chase (option). Off in RLS careers.
- **Tuning in the garage:** a third tile next to the Vehicle Shop and the Parts Shop. Change your car's suspension, tyre pressure, gearing, boost and every other
  tuning setting the game offers, then press Apply. It is free. Save tunes per car model, load them again later, undo your changes, or reset everything to the car's
  defaults.
- **Minimap with a heat ring:** a new UI app ("Most Wanted Freeroam: Minimap") that is the game's minimap with your heat around the outside: a ring of ten segments that
  fills with your bounty, the heat number with a flame, and a ring that flashes red and blue while the police can see you. Add it from the apps menu and use it instead
  of the stock Navigation app.
- An **armored police truck** joins the heat 5 wave.

**Improvements**
- In an RLS career, a Crash Breaker reset now shows what it cost (insurance claim or private repair) as a toast and as a red line in the bounty feed.
- A **Reset achievements** button in the options and achievements windows (press twice to confirm).
- The garage, the options window and the achievements window are proper game UI pages: they work with a controller (D-pad / stick, A to select, B to go back) and the
  on-screen keyboard. Number options have - / + buttons and on/off options are switches. The Parts Shop has a search box and asks you to confirm before buying.
- Weapon mounts now cost money. Parts you buy are yours for the rest of that chase: putting one back on, or putting back a part you swapped out, is free.
- The garage only lists vehicles you can actually drive.
- On maps without garages and/or gas stations, the big map now labels which point of interest is the made-up garage and which is the made-up gas station.
- If you also have the Most Wanted Mission mod, its minimap's heat number and heat ring follow this mod's heat during a chase (nothing of that mod is changed).

**Bug fixes**
- In an RLS career, repairing your car at the computer during a chase no longer ends the chase: the chase pauses while the computer is open, the repair is instant, and the chase continues.
- Resetting your car from the pause menu now ends the chase (it counts as running away), so it can't be used instead of the Crash Breaker.
- You can carjack police cars, not only civilian ones.
- Universal Weapons ammo now runs out faster: a slot is 40 machine-gun rounds or 5 big-gun rounds, so using a gun actually takes a real bite out of your reset bar.
- The Vehicle Shop now has pages, so you can browse every car, and its brand filter lists every brand.
- The big map labels for made-up garages and gas stations now show up (the big map rebuilds its list when it opens, which used to remove them).
- New police units no longer fall from the sky: they spawn on the road, and any that end up in the air are put back.
- You can type in the garage's search box, the brand and sort lists open, the chase stays paused while the garage is open, and leaving the garage no longer resumes
  the chase in slow motion.

### 1.0.0
Initial release.
