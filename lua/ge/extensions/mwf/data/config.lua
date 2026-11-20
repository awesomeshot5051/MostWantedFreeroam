-- Tuning constants: bar, bounty, heat levels, weapon prices. Change numbers here to rebalance.
local MWF = require('/lua/ge/extensions/mwf/core/registry')

-- ===== tuning =====
local BAR_MAX            = 1000
local SLOTS              = 3
local SLOT_COST          = BAR_MAX / SLOTS
local SCORE_LEVELS       = {1, 6000, 15000, 30000, 50000, 75000, 110000, 150000, 200000, 275000} -- bounty needed for heat 1..10
local MAX_HEAT           = #SCORE_LEVELS
-- steady pursuit income per second, by heat: starts slow (10/s), 100/s by heat 3, then keeps climbing
local PURSUIT_RATE       = {10, 45, 100, 150, 200, 250, 300, 350, 425, 500}
-- RLS career: no farming bounty for money. Escaping pays this share of the bounty, capped, and less if paid recently.
local RLS_BOUNTY_SCALE = 0.1        -- every bounty gain, weapon price and heat threshold is multiplied by this in RLS (heat pacing stays the same)
local RLS_RATE_PER_HEAT, RLS_RATE_MAX = 2, 20 -- RLS pursuit pay per second: +$2 per heat level, at most $20/s
local RLS_PAYOUT_BASE_PCT = 0.08    -- share of the bounty paid when you escape, before any Most Wanted Criminal level
local RLS_PAYOUT_MAX_PCT = 0.25     -- ...and at the top level (6)
local RLS_RANK_TARGETS = {5, 15, 35, 70, 120, 200} -- Most Wanted Criminal points needed for level 1..6 (an escape earns points = heat reached)
local RLS_PAYOUT_CAP = 3000
local RLS_PAYOUT_MIN_BOUNTY = 300
local RLS_PAYOUT_WINDOW = 1200      -- s: payouts within this window shrink the next one
local RLS_PAYOUT_DECAY = 0.25       -- each recent payout takes this much off (down to the floor below)
local RLS_PAYOUT_FLOOR_MULT = 0.25
local RLS_RESET_FALLBACK = 1500     -- reset cost when the car is not in the player's RLS inventory
local RLS_PRIVATE_MIN = 2500        -- "private" reset payment: repair estimate, but at least this
local RESET_COST         = 5000  -- bounty per Crash Breaker reset, from RESET_COST_MIN_HEAT up
local RESET_COST_MIN_HEAT = 3    -- below this heat a reset is free...
local FREE_RESET_SLOW_TIME = 60  -- ...but the bar then refills at FREE_RESET_SLOW_MULT speed for this many seconds
local FREE_RESET_SLOW_MULT = 0.35
-- bounty cost per weapon use (never lowers heat); guns are charged per slot of ammo
local WEAPON_COST = {
  ["Missile"] = 1500, ["Chain Missile"] = 2000, ["EMP"] = 3000, ["Tire Pop"] = 500,
  ["Throttle Lock"] = 400, ["Brake Lock"] = 400, ["Steering Jam"] = 400, ["Parking Brake Lock"] = 400,
}
local WEAPON_SLOTS = {["EMP"] = 3} -- reset-bar slots per use (default 1): the EMP hits many cars, so it drains the whole bar
local GUN_COST_MG, GUN_COST_BIG = 1000, 2000 -- per slot of Universal Weapons ammo (100 machine-gun rounds / 10 big-gun rounds)
local WRECK_BASE, WRECK_PER_HEAT, WRECK_MAX = 1000, 250, 5000 -- police wreck payout: by the heat the unit belongs to, x its class multiplier
local GUN_WRECK_FRACTION = 0.35 -- wrecks credited to machine-gun / cannon fire pay only this share (stops gun farming)
local GUN_CREDIT_WINDOW  = 4    -- s: a cop disabled this soon after you fired a gun counts as a gun kill
local BOUNTY_PER_HIT     = 500   -- per police collision
local DIST_THRESHOLD     = 10    -- metres of continuous risky driving before bar charge starts counting
local DRIFT_RATE         = 1.0   -- bar points per metre
local WRONGWAY_RATE      = 0.3
local SPEEDING_RATE      = 0.5
local SPEEDING_MS        = 200 / 3.6          -- speeding for the bar: 200 km/h, or 125 mph if the player's game uses imperial units
local SPEEDING_MS_IMPERIAL = 125 * 0.44704
local DRIFT_MIN_SPEED    = 8     -- m/s
local DRIFT_MIN_ANGLE    = math.rad(20)
local PASSIVE_BASE       = 2.0   -- bar points per second in a chase
local PASSIVE_PER_HEAT   = 1.5   -- extra per heat level
local PASSIVE_BOUNTY_PCT = 0.05  -- fraction of earned bounty that also refills the bar
local HEAT_TO_MODE       = {1, 2, 3, 3, 3, 3, 3, 3, 3, 3} -- vanilla pursuit mode floor per heat level; mode 3 is what enables roadblocks
local END_BANNER_TIME    = 6
local OFFENSE_MULT       = 5     -- vanilla offense score -> bounty
local BOUNTY_PER_TRAFFIC = 150   -- at-fault hit on a civilian car
local REPEAT_DECAY       = 12    -- seconds for one "repeat" to be forgiven
local REPEAT_FALLOFF     = 0.92  -- each recent repeat of the same source multiplies payout by this
local MIN_MULT           = 0.5
-- weapon bounty: {police target, civilian target}
local WEAPON_BOUNTY = {
  ["Missile"]            = {5000, 4000, "exploded"},
  ["Chain Missile"]      = {5000, 4500, "exploded"},
  ["EMP"]                = {3000, 2500, "EMP'd"},
  ["Tire Pop"]           = {1500, 1200, "had tires popped"},
  ["Throttle Lock"]      = {1000, 800, "throttle-locked"},
  ["Brake Lock"]         = {1000, 800, "brake-locked"},
  ["Steering Jam"]       = {1000, 800, "steering-jammed"},
  ["Parking Brake Lock"] = {1000, 800, "parking-brake-locked"},
}
local WEAPON_MIN, WEAPON_MAX = 500, 5000 -- final payout is always within this range, repeat penalty included
local WEAPON_TAG_WINDOW  = 10   -- s: a cop disabled this soon after a weapon hit is credited to the weapon
local FEED_LINES         = 6
local FEED_LIFE          = 7
local GARAGE_ROWS = 50

return {RLS_BOUNTY_SCALE = RLS_BOUNTY_SCALE, RLS_RATE_PER_HEAT = RLS_RATE_PER_HEAT, RLS_RATE_MAX = RLS_RATE_MAX, RLS_PAYOUT_BASE_PCT = RLS_PAYOUT_BASE_PCT, RLS_PAYOUT_MAX_PCT = RLS_PAYOUT_MAX_PCT, RLS_RANK_TARGETS = RLS_RANK_TARGETS, RLS_PAYOUT_CAP = RLS_PAYOUT_CAP, RLS_PAYOUT_MIN_BOUNTY = RLS_PAYOUT_MIN_BOUNTY, RLS_PAYOUT_WINDOW = RLS_PAYOUT_WINDOW, RLS_PAYOUT_DECAY = RLS_PAYOUT_DECAY, RLS_PAYOUT_FLOOR_MULT = RLS_PAYOUT_FLOOR_MULT, RLS_RESET_FALLBACK = RLS_RESET_FALLBACK, RLS_PRIVATE_MIN = RLS_PRIVATE_MIN, BAR_MAX = BAR_MAX, SLOTS = SLOTS, SLOT_COST = SLOT_COST, SCORE_LEVELS = SCORE_LEVELS, MAX_HEAT = MAX_HEAT, PURSUIT_RATE = PURSUIT_RATE, RESET_COST = RESET_COST, RESET_COST_MIN_HEAT = RESET_COST_MIN_HEAT, FREE_RESET_SLOW_TIME = FREE_RESET_SLOW_TIME, FREE_RESET_SLOW_MULT = FREE_RESET_SLOW_MULT, WEAPON_COST = WEAPON_COST, WEAPON_SLOTS = WEAPON_SLOTS, GUN_COST_MG = GUN_COST_MG, GUN_COST_BIG = GUN_COST_BIG, WRECK_BASE = WRECK_BASE, WRECK_PER_HEAT = WRECK_PER_HEAT, WRECK_MAX = WRECK_MAX, GUN_WRECK_FRACTION = GUN_WRECK_FRACTION, GUN_CREDIT_WINDOW = GUN_CREDIT_WINDOW, BOUNTY_PER_HIT = BOUNTY_PER_HIT, DIST_THRESHOLD = DIST_THRESHOLD, DRIFT_RATE = DRIFT_RATE, WRONGWAY_RATE = WRONGWAY_RATE, SPEEDING_RATE = SPEEDING_RATE, SPEEDING_MS = SPEEDING_MS, SPEEDING_MS_IMPERIAL = SPEEDING_MS_IMPERIAL, DRIFT_MIN_SPEED = DRIFT_MIN_SPEED, DRIFT_MIN_ANGLE = DRIFT_MIN_ANGLE, PASSIVE_BASE = PASSIVE_BASE, PASSIVE_PER_HEAT = PASSIVE_PER_HEAT, PASSIVE_BOUNTY_PCT = PASSIVE_BOUNTY_PCT, HEAT_TO_MODE = HEAT_TO_MODE, END_BANNER_TIME = END_BANNER_TIME, OFFENSE_MULT = OFFENSE_MULT, BOUNTY_PER_TRAFFIC = BOUNTY_PER_TRAFFIC, REPEAT_DECAY = REPEAT_DECAY, REPEAT_FALLOFF = REPEAT_FALLOFF, MIN_MULT = MIN_MULT, WEAPON_BOUNTY = WEAPON_BOUNTY, WEAPON_MIN = WEAPON_MIN, WEAPON_MAX = WEAPON_MAX, WEAPON_TAG_WINDOW = WEAPON_TAG_WINDOW, FEED_LINES = FEED_LINES, FEED_LIFE = FEED_LIFE, GARAGE_ROWS = GARAGE_ROWS}
