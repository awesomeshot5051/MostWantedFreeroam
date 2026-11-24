-- RLS Career Overhaul compatibility. Everything here only does anything while an RLS career is running
-- (overhaul_career_career.isActive()). Outside RLS, or if RLS is not installed, this module is inert.
--
-- In an RLS career:
--   * Bounty is drastically reduced (x RLS_BOUNTY_SCALE, pursuit pay $2/s per heat up to $20/s) and is not money. Escaping pays a
--     share of it (8%, rising to 25% with the "Most Wanted Criminal" milestone), capped and diminishing, so chases cannot be
--     farmed for money (data/config.lua: RLS_*).
--   * A Crash Breaker reset costs real money, like an insurance claim: the vehicle's insurance deductible ("insurance" option),
--     or the repair estimate with a floor ("private" option).
--   * Pit stops are switched off: no repair, no garage window, no vehicle / parts unlock. In RLS you own the garage and change
--     cars and parts at its computer.
local MWF = require('/lua/ge/extensions/mwf/core/registry')
local S = MWF.S
local CFG = require('/lua/ge/extensions/mwf/data/config')

local M = {}

local function detect()
  local ok, active = pcall(function() return overhaul_career_career ~= nil and overhaul_career_career.isActive() == true end)
  return ok and active or false
end

-- the player's car as an RLS inventory vehicle (nil for a car that is not in the player's inventory)
local function inventoryVehicle()
  local ok, invId, info = pcall(function()
    local _, vehId = MWF.util.getPlayerVeh()
    if not vehId then return nil end
    local id = overhaul_career_garage_inventory.getInventoryIdFromVehicleId(vehId)
    return id, id and overhaul_career_garage_inventory.getVehicles()[id]
  end)
  if ok then return invId, info end
end

-- what a reset costs right now, in real money
local function computeResetCost()
  local invId, info = inventoryVehicle()
  local damage
  if info then
    local ok, d = pcall(function() return overhaul_career_market_valueCalculator.getRepairDetails(info).price end)
    if ok then damage = tonumber(d) end
  end
  local privateCost = math.max(CFG.RLS_PRIVATE_MIN, damage or 0)
  if (S.options.rlsResetPayment or "insurance") == "private" then return math.floor(privateCost) end
  if not invId then return CFG.RLS_RESET_FALLBACK end
  local ok, deductible = pcall(function()
    return overhaul_career_repair_insurance.getPlCoverageOptionValue(invId, 'deductible')
  end)
  deductible = ok and tonumber(deductible) or nil
  if deductible then return math.floor(deductible) end
  return math.floor(privateCost) -- uninsured car: you pay for it yourself
end

local function balance()
  local ok, v = pcall(function() return overhaul_career_economy_playerAttributes.getAttributeValue("money") end)
  return ok and tonumber(v) or 0
end

local function canPay(amount)
  if amount <= 0 then return true end
  local ok, res = pcall(function() return overhaul_career_economy_payment.canPay({money = {amount = amount, canBeNegative = false}}) end)
  return ok and res == true
end

-- shows a charge to the player: a toast, and a red "-$N" line in the bounty feed (it is real career money, not bounty)
local function announce(amount, what)
  if not (amount and amount > 0) then return end
  table.insert(S.feed, 1, {text = what .. " (career money)", amount = amount, mult = 1, neg = true, t = os.clock()})
  while #S.feed > CFG.FEED_LINES do table.remove(S.feed) end
  MWF.util.toast("info", "Crash Breaker: " .. what, string.format("-$%d from your career money.", math.floor(amount + 0.5)), 3500)
end

local function charge(amount, label)
  if amount <= 0 then return true end
  local ok, res = pcall(function()
    return overhaul_career_economy_payment.pay({money = {amount = amount, canBeNegative = false}},
      {category = "insurance", finance = {vehicleRelated = false}, label = label})
  end)
  log('I', 'mwf', string.format('RLS charge $%d for "%s": %s', amount, label, tostring(ok and res)))
  return ok and res == true
end

-- ===== Most Wanted Criminal: a milestone in RLS's own milestones screen =====
-- Escaping a chase earns "wanted points" equal to the heat you reached. The points live in RLS's per-profile milestone save data
-- (so they belong to the career, not to this PC), and RLS shows the milestone, its progress bar and its claim rewards.
-- The LEVEL (0-6, from points) raises the share of the bounty paid when you escape, from 8% up to 25% at level 6.
local MILESTONE_ID = "mwf_most_wanted_criminal"

local function entry()
  local ok, e = pcall(function()
    local sd = overhaul_career_progression_milestones_milestones.saveData
    sd.general = sd.general or {}
    sd.general[MILESTONE_ID] = sd.general[MILESTONE_ID] or {claimedStep = 0, notificationStep = 0}
    return sd.general[MILESTONE_ID]
  end)
  return ok and e or nil
end

local function points()
  local e = entry()
  return e and e.points or 0
end

local function levelFor(p)
  local lvl = 0
  for i, target in ipairs(CFG.RLS_RANK_TARGETS) do
    if p >= target then lvl = i end
  end
  return lvl
end

local function level() return levelFor(points()) end

local function payoutPct()
  local frac = level() / #CFG.RLS_RANK_TARGETS
  return CFG.RLS_PAYOUT_BASE_PCT + (CFG.RLS_PAYOUT_MAX_PCT - CFG.RLS_PAYOUT_BASE_PCT) * frac
end

local function addPoints(n)
  local e = entry()
  if not e or n <= 0 then return end
  local before = levelFor(e.points or 0)
  e.points = (e.points or 0) + n
  local after = levelFor(e.points)
  log('I', 'mwf', string.format('Most Wanted Criminal: +%d points (now %d, level %d)', n, e.points, after))
  if after > before then
    MWF.util.toast("success", "Most Wanted Criminal: level " .. after,
      string.format("Escapes now pay %d%% of your bounty.", math.floor(payoutPct() * 100 + 0.5)), 6000)
  end
end

-- RLS asks every loaded extension for milestones with this hook (see RLS's milestones/general.lua)
function M.onOverhaulGeneralMilestonesCollect(list)
  local ms = overhaul_career_progression_milestones_milestones
  local maxStep = #CFG.RLS_RANK_TARGETS
  table.insert(list, {
    id = MILESTONE_ID,
    filter = {general = true, mostWanted = true},
    type = "stat",
    icon = "star",
    color = "var(--bng-add-red-500)",
    maxStep = maxStep,
    getValue = points,
    getLabel = function(step) return "Most Wanted Criminal - level " .. math.max(1, step) end,
    getDescription = function(step, current, target)
      local pct = CFG.RLS_PAYOUT_BASE_PCT + (CFG.RLS_PAYOUT_MAX_PCT - CFG.RLS_PAYOUT_BASE_PCT) * math.max(1, step) / maxStep
      return string.format("Escape police chases in Most Wanted Freeroam to become a Most Wanted Criminal. Each escape earns points equal to the heat you reached. At this level, escaping pays %d%% of your bounty.", math.floor(pct * 100 + 0.5))
    end,
    getProgressLabel = function(step, current, target) return string.format("%d / %d points", math.floor(current), math.floor(target)) end,
    getTarget = function(step) return step <= 0 and 0 or CFG.RLS_RANK_TARGETS[math.min(step, maxStep)] end,
    getRewards = function(step) return {{attributeKey = "money", rewardAmount = 150 * (step + 1)}} end,
  })
end

-- ===== escape payout =====
-- A share of the bounty (8% .. 25% by level), capped, and smaller the more often you were paid recently.
local function payoutFor(bounty)
  if bounty < CFG.RLS_PAYOUT_MIN_BOUNTY then return 0 end
  local now, recent = os.clock(), 0
  local kept = {}
  for _, t in ipairs(S.rls.payouts) do
    if now - t < CFG.RLS_PAYOUT_WINDOW then recent = recent + 1 table.insert(kept, t) end
  end
  S.rls.payouts = kept
  local mult = math.max(CFG.RLS_PAYOUT_FLOOR_MULT, 1 - CFG.RLS_PAYOUT_DECAY * recent)
  return math.floor(math.min(CFG.RLS_PAYOUT_CAP, bounty * payoutPct()) * mult)
end

local function payEscape(bounty, heat)
  if not S.rls.active then return end
  local amount = payoutFor(bounty)
  if amount > 0 then
    local ok, res = pcall(function()
      return overhaul_career_economy_payment.reward({money = {amount = amount}},
        {category = "reward", label = "Most Wanted: escaped the police"})
    end)
    if ok and res ~= false then
      table.insert(S.rls.payouts, os.clock())
      MWF.util.toast("success", "Escaped!", string.format("The police gave up. Payout: $%d (%d%% of the bounty)", amount, math.floor(payoutPct() * 100 + 0.5)), 4500)
      log('I', 'mwf', string.format('RLS escape payout $%d (bounty %d, %d%%)', amount, math.floor(bounty), math.floor(payoutPct() * 100 + 0.5)))
    else
      log('W', 'mwf', 'RLS escape payout failed: ' .. tostring(res))
    end
  end
  addPoints(heat or 1)
end

-- a small real-money payout plus milestone points, for achievements that carry a reward (see data/achievements.lua)
local function payAchievement(money, pts, label)
  if not S.rls.active then return end
  if money and money > 0 then
    local ok, res = pcall(function()
      return overhaul_career_economy_payment.reward({money = {amount = money}}, {category = "reward", label = "Most Wanted: " .. label})
    end)
    if not (ok and res ~= false) then log('W', 'mwf', 'RLS achievement payout failed: ' .. tostring(res)) end
  end
  addPoints(pts or 0)
end

local function active() return S.rls.active end

-- the cached cost is what the HUD and the "reset ready" check use; the real charge recomputes it
local function resetCost() return S.rls.resetCost end

-- ===== repairs at the RLS computer during a chase =====
-- Two things used to end the chase: (1) a timed insurance repair (60 s) takes the car out of the world, (2) an instant repair respawns it, and
-- both look like "you got rid of your car" to the chase. So, while a chase is on in an RLS career:
--   * the chase is frozen (like the garage pause) while the RLS computer is open, so the pursuit cannot run out while you pay and wait;
--   * the repair is made instant (the quote and the price stay exactly what RLS showed; the insurance claim, deductible and driver score
--     are still handled by RLS), and session.lua carries the chase over to the respawned car.
local COMPUTER_POLL, REPAIR_GRACE = 0.25, 25 -- s

local function computerOpen()
  local ok, name = pcall(function() return require("overhaul/lib/career/context").currentUiRouteName() end)
  return ok and type(name) == 'string' and name:find("^overhaul%.computer") ~= nil
end

function M.rlsRepairStarting(opt)
  if not (S.session and S.rls and S.rls.active) then return end
  if type(opt) == 'table' and (tonumber(opt.repairTime) or 0) > 0 then
    log('I', 'mwf', string.format('RLS repair during a chase: repair time %s s made instant so the chase keeps going', tostring(opt.repairTime)))
    opt.repairTime = 0
  end
  S.rlsRepairUntil = os.clock() + REPAIR_GRACE
end

local function installRepairWatch()
  local ins = overhaul_career_repair_insurance
  if type(ins) ~= 'table' or ins.mwfWrapped or type(ins.startRepairInGarage) ~= 'function' then return end
  ins.mwfWrapped = true
  local function wrap(orig)
    return function(invVehId, opt, ...)
      if mwf_core and mwf_core.rlsRepairStarting then pcall(mwf_core.rlsRepairStarting, opt) end
      return orig(invVehId, opt, ...)
    end
  end
  ins.startRepairInGarage = wrap(ins.startRepairInGarage)
  if type(ins.startRepairInPlace) == 'function' then ins.startRepairInPlace = wrap(ins.startRepairInPlace) end
  log('I', 'mwf', 'RLS: repairs are watched (a repair during a chase is instant and the chase carries on)')
end

local function tick(dtReal)
  S.rls.pollT = (S.rls.pollT or 0) + dtReal
  if S.rls.pollT >= COMPUTER_POLL then
    S.rls.pollT = 0
    local open = S.session ~= nil and S.rls.active == true and computerOpen()
    if open ~= (S.rlsComputer == true) then
      S.rlsComputer = open
      MWF.garage.applyGaragePause()
    end
  end
  S.rls.checkT = S.rls.checkT + dtReal
  if S.rls.checkT < 1 then return end
  if S.rls.active then pcall(installRepairWatch) end
  S.rls.checkT = 0
  local was = S.rls.active
  S.rls.active = detect()
  if S.rls.active ~= was then log('I', 'mwf', 'RLS career ' .. (S.rls.active and 'detected: RLS mode on' or 'not active: RLS mode off')) end
  if S.rls.active and S.session then S.rls.resetCost = computeResetCost() end
end

MWF.rls = {announce = announce, active = active, resetCost = resetCost, computeResetCost = computeResetCost, canPay = canPay, charge = charge,
  balance = balance, payEscape = payEscape, payAchievement = payAchievement, payoutFor = payoutFor, payoutPct = payoutPct, level = level, points = points, tick = tick}

return M
