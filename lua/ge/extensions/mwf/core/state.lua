-- Shared mutable state of the mod (one table, S). Everything that changes at runtime lives here.
local MWF = require('/lua/ge/extensions/mwf/core/registry')
local S = MWF.S
local im = ui_imgui

local M = {}

-- ===== state =====
S.hudVisible = im.BoolPtr(true)
S.bar = 0
S.session = nil -- {bounty, heat, lastHits, lastScore, wrecked = {}, baseVars}
S.lastEnd = nil -- {kind, bounty, time}
S.risk = {drift = {d = 0, on = false}, wrongWay = {d = 0, on = false}, speeding = {d = 0, on = false}}
S.ammoByVeh = {}   -- [vehId][fireElectric] = {rounds, max}, pushed by the vehicle-side extension
S.hudH = 120      -- height of the main HUD panel, so the ammo window can sit above it
S.resetsLocked = false
S.ach = {stats = {}, unlocked = {}, banners = {}, dirty = false, saveTimer = 0, loaded = false, show = im.BoolPtr(false)} -- achievements (see achievements/tracker.lua)
S.rls = {active = false, checkT = 0, resetCost = 0, payouts = {}} -- RLS career compatibility (see compat/rls.lua)
S.regenSlowUntil = 0  -- os.clock() until which the reset bar refills slowly (after a free reset at heat 1-2)
S.fallbackPois = {} -- POI id -> "garage" / "gas station", for the POIs made into pit stops (world/pits.lua)
S.options = {hideCivilians = false, thinTraffic = true, spawnInterval = 1.5, smooth = true, waveScale = 1.0, pitCosts = true, priceFactor = 0.5, fallbackPits = true, sensitivity = 1.0, rlsResetPayment = "insurance", weaponChase = true, onFoot = true, stealCars = true}
-- pit stop economy (see "pit stop economy" section): vehicle swaps and part changes cost bounty
S.garage = {show = im.BoolPtr(false), mode = nil, search = im.ArrayChar(128), catalog = nil, note = ""} -- mode: nil | "hub" | "cars" | "parts"
S.garagePaused = false
S.lastCostToast = -100
S.lastGunFire = -100   -- os.clock() of the last Universal Weapons round fired by the player
S.bypassGate = false -- set while this mod spawns its own police/props, so they are never charged
S.optionsLoaded = false
S.hiddenCivs = {}      -- traffic vehicle ids we hid for the chase
S.restoreQueue = {}    -- ids waiting to be put back on the road (a few per frame)
S.civTimer = 0
S.idleClear = 0
S.resetTrace = nil     -- {pos, t}: logs where a Crash Breaker reset put you
S.feed = {}          -- recent bounty events {text, amount, mult, t}
S.recent = {}        -- per-source repeat counters (decay over time)
S.seenColl = {}      -- victim id -> last time a hit was credited
S.seenOffenses = {}
S.stats = {wrecked = 0, hitPolice = 0, copsPresent = 0}

S.breakerLockUntil = 0  -- one reset per press: later requests (second input bound to the same button) are ignored
S.origReset = nil    -- vanilla resetGameplay, while we wrap it
S.breaker = nil      -- active Crash Breaker {t, pid, prevScale}
S.gasStations = {}
S.lastGas = -100
S.lastLockedToast = nil
S.gasInit = false        -- first check after a chase starts only records where you are; it never repairs
S.riskPauseUntil = 0     -- no bar charge right after a reset/teleport (physics spikes)
S.inGas = false      -- inside any pit stop (gas station or garage)
S.inGarage = false   -- inside a garage: the only place with the vehicle / parts UI
S.transfer = nil -- pending pursuit hand-over after a car change at a gas station

return M
