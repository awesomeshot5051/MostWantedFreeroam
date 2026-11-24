-- Police unit tables per heat level (cars, armed units, KARR/KITT, roadblock props) and spawn limits.
local MWF = require('/lua/ge/extensions/mwf/core/registry')
local CFG = require('/lua/ge/extensions/mwf/data/config')


-- ===== escalation: new units and roadblock props per heat level (like Most Wanted's per-heat vehicle groups) =====
-- Heat 1 = the normal police already in traffic. Every heat level above that brings in an extra group of units; only the
-- newest 3 groups stay around. Sawhorse roadblocks come in at heat 3, spike strips at heat 4-6 (vanilla places the props
-- once its pursuit reaches mode 3, which HEAT_TO_MODE guarantees from heat 3).
-- Car entries: {model, config, label, mult, mod = <file that must exist>, alt = <car to use if it does not>}
--   mult = payout multiplier when you wreck one (heavier / armed units are worth more)
-- Armed units use Universal Weapons configs. The AI fires a roof gun nonstop while it is in pursuit mode. If that mod is not
-- installed (the config file is missing) the unit's `alt` car is spawned instead.
local function C(model, config, label, mult, mod, alt) return {model, config, label = label, mult = mult or 1, mod = mod, alt = alt} end
local SEMI_MWM = C("us_semi", "vehicles/us_semi/mwm_interceptor.pc", "Special pursuit semi", 1.5, true, C("van", "vehicles/van/police.pc", "Police van", 1.25))
local HEAT_GROUPS = {
  [2] = {count = 2, note = "extra patrol cars", cars = {
    C("fullsize", "vehicles/fullsize/police.pc", "Patrol car"), C("van", "vehicles/van/police.pc", "Police van", 1.25), C("roamer", "vehicles/roamer/sheriff.pc", "Sheriff SUV")}},
  [3] = {count = 2, note = "pursuit units, roadblocks", cars = {
    C("bastion", "vehicles/bastion/police_v8_awd_A.pc", "Pursuit unit"), C("sunburst2", "vehicles/sunburst2/police.pc", "Pursuit unit")}},
  [4] = {count = 3, note = "unmarked cars, interceptors, SPIKE STRIPS", cars = {
    C("bastion", "vehicles/bastion/police_unmarked_v8_awd_A.pc", "Unmarked unit"), C("roamer", "vehicles/roamer/unmarked.pc", "Unmarked SUV"),
    C("sunburst2", "vehicles/sunburst2/interceptor.pc", "Interceptor", 1.1)}},
  [5] = {count = 5, note = "interceptors, heavy police vans and an ARMORED police truck", cars = {
    C("scintilla", "vehicles/scintilla/interceptor.pc", "Interceptor", 1.2), C("van", "vehicles/van/police.pc", "Police van", 1.25),
    C("roamer", "vehicles/roamer/unmarked.pc", "Unmarked SUV"), C("van", "vehicles/van/police_passenger.pc", "Police transport van", 1.25),
    C("md_series", "vehicles/md_series/md_60_armored_police.pc", "Armored police truck", 1.5)}},
  [6] = {count = 4, note = "elite interceptors and special pursuit semis", cars = {
    C("bastion", "vehicles/bastion/mwm_interceptor.pc", "Elite interceptor", 1.3, true, C("bastion", "vehicles/bastion/police_unmarked_v8_awd_A.pc", "Unmarked unit")),
    SEMI_MWM,
    C("scintilla", "vehicles/scintilla/mwm_interceptor.pc", "Elite interceptor", 1.3, true, C("scintilla", "vehicles/scintilla/interceptor.pc", "Interceptor", 1.2)),
    SEMI_MWM}},
  [7] = {count = 4, note = "elite roamers and more semis", cars = {
    C("roamer", "vehicles/roamer/mwm_interceptor.pc", "Elite interceptor", 1.3, true, C("roamer", "vehicles/roamer/unmarked.pc", "Unmarked SUV")),
    SEMI_MWM, C("scintilla", "vehicles/scintilla/mwm_interceptor.pc", "Elite interceptor", 1.3, true, C("scintilla", "vehicles/scintilla/interceptor.pc", "Interceptor", 1.2)),
    SEMI_MWM}},
  [8] = {count = 4, note = "light ARMED units (minigun / 50cal), semis, KARR", cars = {
    C("hopper", "vehicles/hopper/minigun.pc", "Armed minigun unit", 1.4, true, C("sunburst2", "vehicles/sunburst2/interceptor.pc", "Interceptor", 1.1)),
    SEMI_MWM, C("vivace", "vehicles/vivace/50cal.pc", "Armed 50cal unit", 1.4, true, C("roamer", "vehicles/roamer/unmarked.pc", "Unmarked SUV")),
    SEMI_MWM}},
  [9] = {count = 5, note = "heavy ARMED units (autocannons), semi blockade, KITT", cars = {
    C("scintilla", "vehicles/scintilla/dark_owl2.pc", "Armed interceptor", 1.5, true, C("scintilla", "vehicles/scintilla/interceptor.pc", "Interceptor", 1.2)),
    SEMI_MWM, C("lansdale", "vehicles/lansdale/gambler_autocannon.pc", "Armed autocannon unit", 1.5, true, C("bastion", "vehicles/bastion/police_unmarked_v8_awd_A.pc", "Unmarked unit")),
    SEMI_MWM, C("etkc", "vehicles/etkc/autocannon.pc", "Armed autocannon unit", 1.5, true, C("bastion", "vehicles/bastion/police_unmarked_v8_awd_A.pc", "Unmarked unit"))}},
  [10] = {count = 5, note = "HOWITZER vans, armed interceptors, semis", cars = {
    C("van", "vehicles/van/police_howitzer.pc", "Howitzer van", 1.6, true, C("van", "vehicles/van/police.pc", "Police van", 1.25)),
    C("scintilla", "vehicles/scintilla/dark_owl2.pc", "Armed interceptor", 1.5, true, C("scintilla", "vehicles/scintilla/interceptor.pc", "Interceptor", 1.2)),
    SEMI_MWM, C("etkc", "vehicles/etkc/autocannon.pc", "Armed autocannon unit", 1.5, true, C("bastion", "vehicles/bastion/police_unmarked_v8_awd_A.pc", "Unmarked unit")),
    SEMI_MWM}},
}
-- Exactly one of each, added once per chase when that heat is reached, only if its mod (the Knight Rider pack) is installed.
-- They are indestructible, so they are never counted in a heat group, never replaced, and never pay a wreck bounty.
local HEAT_SPECIALS = {
  [8] = C("karr", "vehicles/karr/da98f.pc", "KARR", 1, true),
  [9] = C("knight_2000", "vehicles/knight_2000/0a7b1.pc", "KITT", 1, true),
}
local FALLBACK_CAR   = C("fullsize", "vehicles/fullsize/police.pc", "Patrol car")
local PROP_DEFS = {
  {name = "sawhorse",  model = "sawhorse",  config = "lights", minHeat = 3, maxHeat = 3, count = 4},
  {name = "spikestrip", model = "spikestrip", config = "flex4", minHeat = 4, maxHeat = CFG.MAX_HEAT, count = 4},
}
local GROUP_WINDOW   = 3     -- how many heat groups stay active
local SPAWN_INTERVAL = 0.6   -- seconds between spawns (avoids a big hitch)
local MAX_EXTRA      = 16
local REPLENISH_EVERY = 6    -- s between checks that put new units in for ones you wrecked (keeps the heat group topped up)

return {C = C, SEMI_MWM = SEMI_MWM, HEAT_GROUPS = HEAT_GROUPS, HEAT_SPECIALS = HEAT_SPECIALS, FALLBACK_CAR = FALLBACK_CAR, PROP_DEFS = PROP_DEFS, GROUP_WINDOW = GROUP_WINDOW, SPAWN_INTERVAL = SPAWN_INTERVAL, MAX_EXTRA = MAX_EXTRA, REPLENISH_EVERY = REPLENISH_EVERY}
