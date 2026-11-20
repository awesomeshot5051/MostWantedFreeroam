-- Small helpers used everywhere: player vehicle, pursuit data, reset-bar check, toasts.
local MWF = require('/lua/ge/extensions/mwf/core/registry')
local S = MWF.S
local CFG = require('/lua/ge/extensions/mwf/data/config')

local M = {}

-- ===== helpers =====
local function canSpend(n)
  return S.bar >= CFG.SLOT_COST * (n or 1) - 0.01
end

-- bounty price of a Crash Breaker reset right now: free at low heat, CFG.RESET_COST from heat 3
local function resetCost()
  if S.rls.active then return MWF.rls.resetCost() end -- RLS career: real money, like an insurance claim
  local heat = S.session and S.session.heat or 1
  return heat >= CFG.RESET_COST_MIN_HEAT and CFG.RESET_COST or 0
end

-- can the player pay for a reset right now? (RLS: from the career's money; otherwise from the chase bounty)
local function canAffordReset()
  local cost = resetCost()
  if S.rls.active then return MWF.rls.canPay(cost) end
  return MWF.garage.wallet() >= cost
end

-- every gain of the reset bar goes through here, so the slow refill after a free reset applies to all of them
local function addBar(amount)
  if amount > 0 and os.clock() < S.regenSlowUntil then amount = amount * CFG.FREE_RESET_SLOW_MULT end
  S.bar = math.min(CFG.BAR_MAX, S.bar + amount)
end

local function getPlayerVeh()
  local id = be:getPlayerVehicleID(0)
  if not id or id < 0 then return nil end
  return getObjectByID(id), id
end

local function getPursuit(id)
  if not gameplay_police or not gameplay_police.getPursuitData then return nil end
  local ok, pd = pcall(gameplay_police.getPursuitData, id)
  if ok then return pd end
end

-- the player's unit system from the game's settings ("metric" or "imperial"); drives speed and distance wording and goals
local function unitSystem()
  local ok, v = pcall(function() return settings.getValue('uiUnitLength') end)
  return (ok and v == 'imperial') and 'imperial' or 'metric'
end

-- the speed (m/s) that counts as "speeding" for the reset bar: 200 km/h, or 125 mph in imperial
local function speedingMs()
  return unitSystem() == 'imperial' and CFG.SPEEDING_MS_IMPERIAL or CFG.SPEEDING_MS
end

-- RLS career: bounty is scaled down hard (see compat/rls.lua); everything else stays in the same proportions
local function bountyScale()
  return S.rls.active and CFG.RLS_BOUNTY_SCALE or 1
end

-- steady pursuit pay per second at a heat level
local function pursuitRate(heat)
  heat = heat or 1
  if S.rls.active then return math.min(CFG.RLS_RATE_MAX, CFG.RLS_RATE_PER_HEAT * heat) end
  return CFG.PURSUIT_RATE[heat] or CFG.PURSUIT_RATE[1]
end

-- bounty needed for a heat level (scaled in RLS)
local function heatThreshold(h)
  local v = CFG.SCORE_LEVELS[h]
  return v and v * bountyScale() or nil
end

local function heatForBounty(b)
  local h = 0
  for i = 1, #CFG.SCORE_LEVELS do
    if b >= heatThreshold(i) then h = i end
  end
  return h
end

local function resetRisk()
  for _, r in pairs(S.risk) do r.d = 0; r.on = false end
end

local function toast(t, title, msg, ms)
  guihooks.trigger("toastrMsg", {type = t, title = title, msg = msg, config = {timeOut = ms or 2500}})
end

MWF.util = {canSpend = canSpend, getPlayerVeh = getPlayerVeh, getPursuit = getPursuit, heatForBounty = heatForBounty, resetRisk = resetRisk, toast = toast, unitSystem = unitSystem, speedingMs = speedingMs, bountyScale = bountyScale, pursuitRate = pursuitRate, heatThreshold = heatThreshold, resetCost = resetCost, canAffordReset = canAffordReset, addBar = addBar}

return M
