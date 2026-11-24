-- The Crash Breaker: slow motion, explosion and recover that replaces the normal reset during a chase.
local MWF = require('/lua/ge/extensions/mwf/core/registry')
local S = MWF.S
local CFG = require('/lua/ge/extensions/mwf/data/config')

local M = {}

local BREAKER_SLOWMO     = 0.25
local BREAKER_DURATION   = 1.6   -- real seconds of slow-mo before the reset happens

-- Crash Breaker: slow motion -> the car explodes -> the normal vanilla reset
local function cancelBreaker()
  if S.breaker then
    pcall(function() simTimeAuthority.set(S.breaker.prevScale or 1) end)
    S.breaker = nil
  end
end

local function startBreaker(pid)
  local veh = getObjectByID(be:getPlayerVehicleID(0) or -1)
  if not veh then return end
  local prev = 1
  pcall(function() prev = simTimeAuthority.get() end)
  S.breaker = {t = 0, pid = pid, prevScale = prev}
  pcall(function() simTimeAuthority.set(BREAKER_SLOWMO) end)
  veh:queueLuaCommand("fire.explodeVehicle() beamstate.breakAllBreakgroups()")
  log('I', 'mwf', 'Crash Breaker started')
end

-- End of the Crash Breaker, exactly like Most Wanted's stopSpeedBreaker(): recovery.startRecovering() then
-- recovery.stopRecovering(). The intercept flag is off only for this call.
local function recoverInPlace()
  local veh = getObjectByID(be:getPlayerVehicleID(0) or -1)
  if not veh then return end
  -- one command, so nothing can run in between the flag changes
  local p = veh:getPosition()
  S.resetTrace = {pos = vec3(p.x, p.y, p.z), t = 0}
  log('I', 'mwf', string.format('Reset: recovering from %.1f,%.1f,%.1f', p.x, p.y, p.z))
  veh:queueLuaCommand("recovery.recoveryHooksOnly = false recovery.startRecovering() recovery.stopRecovering()")
  -- switch the intercept back on only if the chase is still going (queued after the recover, so the order holds)
  if S.session then veh:queueLuaCommand("recovery.recoveryHooksOnly = true") end
  -- a real reset empties every Universal Weapons gun on the car (it has to be paid for again)
  veh:queueLuaCommand("if extensions.mwfWeapons then extensions.mwfWeapons.resetRounds() end")
  local a = S.ammoByVeh[veh:getID()]
  if a then for _, e in pairs(a) do e.rounds = 0 end end
end

local function tickBreaker(dtReal)
  if not S.breaker then return end
  S.breaker.t = S.breaker.t + dtReal
  if S.breaker.t >= BREAKER_DURATION then
    cancelBreaker()
    recoverInPlace()
  end
end

-- Replaces vanilla resetGameplay() while a chase is on. The R key goes through here.
local function chaseResetGameplay(pid, source)
  if S.breaker or os.clock() < S.breakerLockUntil then return end
  if pid == -1 then return end -- reset-all is never allowed mid-chase
  local cost = S.rls.active and MWF.rls.computeResetCost() or MWF.util.resetCost()
  local affordable = S.rls.active and MWF.rls.canPay(cost) or (not S.rls.active and MWF.garage.wallet() >= cost)
  if MWF.util.canSpend() and affordable then
    S.bar = math.max(0, S.bar - CFG.SLOT_COST)
    if cost > 0 then
      if S.rls.active then
        local private = S.options.rlsResetPayment == "private"
        MWF.rls.charge(cost, "Most Wanted: Crash Breaker reset (" .. (private and "private" or "insurance claim") .. ")")
        MWF.rls.announce(cost, private and "private repair" or "insurance claim")
      else
        MWF.garage.spendBounty(cost, "Crash Breaker reset")
      end
    else
      -- free at low heat, but the bar refills slowly for a while afterwards
      S.regenSlowUntil = os.clock() + CFG.FREE_RESET_SLOW_TIME
    end
    S.breakerLockUntil = os.clock() + BREAKER_DURATION + 2.5
    log('I', 'mwf', 'Reset request accepted from ' .. tostring(source or 'reset key'))
    MWF.achievements.add('resets', 1)
    startBreaker(pid)
  else
    if os.clock() - (S.lastLockedToast or -10) > 1.5 then
      S.lastLockedToast = os.clock()
      MWF.util.toast("warning", "Reset Locked", MWF.util.canSpend() and string.format("A reset costs $%d. Teleport to road is free.", cost)
        or "Not enough reset bar. Teleport to road is free.", 2200)
    end
  end
end

local function installResetWrapper()
  if S.origReset or resetGameplay == chaseResetGameplay then return end
  S.origReset = resetGameplay
  resetGameplay = chaseResetGameplay
end

local function restoreResetWrapper()
  if resetGameplay == chaseResetGameplay and S.origReset then resetGameplay = S.origReset end
  S.origReset = nil
end

MWF.breaker = {cancelBreaker = cancelBreaker, chaseResetGameplay = chaseResetGameplay, installResetWrapper = installResetWrapper, restoreResetWrapper = restoreResetWrapper, tickBreaker = tickBreaker}

return M
