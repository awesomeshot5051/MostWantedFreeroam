-- Chase lifecycle: start / end of a session, and the vanilla hooks (pursuit action, vehicle switched, level start/end...).
local MWF = require('/lua/ge/extensions/mwf/core/registry')
local S = MWF.S
local CFG = require('/lua/ge/extensions/mwf/data/config')

local M = {}

local function startSession(pd)
  if S.session then return end
  local base = {}
  if gameplay_police and gameplay_police.getPursuitVars then
    local ok, v = pcall(gameplay_police.getPursuitVars)
    if ok and v then base = {evadeTime = v.evadeTime, arrestTime = v.arrestTime, roadblockFrequency = v.roadblockFrequency} end
  end
  S.session = {bounty = 0, spent = 0, heat = 1, lastHits = pd and pd.hitCount or 0, lastOffCount = pd and pd.offensesCount or 0, wrecked = {}, baseVars = base, timeBounty = 0}
  S.feed, S.recent, S.seenColl, S.seenOffenses = {}, {}, {}, {}
  MWF.escalation.escReset()
  S.session.weaponTag = {}
  S.stats.wrecked, S.stats.hitPolice, S.stats.copsPresent = 0, 0, 0
  S.session.bounty = CFG.SCORE_LEVELS[1]
  S.bar = 0
  S.regenSlowUntil = 0
  MWF.util.resetRisk()
  S.lastEnd = nil
  MWF.difficulty.applyHeatTuning(1)
  MWF.pits.loadGasStations()
  S.lastGas = -100
  MWF.breaker.installResetWrapper()
  S.inGas = false
  S.inGarage = false
  S.gasInit = false
  MWF.garage.closeGarage()
  S.transfer = nil
  S.civTimer = 3.1 -- sweep civilians on the next tick
  MWF.lockdown.setChaseBlock(true)
  MWF.lockdown.setRecoveryIntercept(true)
  MWF.achievements.add('chases', 1)
  MWF.achievements.max('heat', 1)
  log('I', 'mwf', 'Chase started')
end

local function endSession(kind)
  if not S.session then return end
  MWF.difficulty.restoreTuning()
  S.lastEnd = {kind = kind, bounty = S.session.bounty, time = os.clock(), wrecked = S.stats.wrecked}
  log('I', 'mwf', string.format('Chase ended (%s), bounty %d', kind, S.session.bounty))
  if kind == 'escaped' then
    MWF.achievements.add('escapes', 1)
    MWF.achievements.max('escapeHeat', S.session.heat)
  elseif kind == 'busted' then
    MWF.achievements.add('busts', 1)
  end
  MWF.achievements.flush()
  MWF.escalation.retireAll()
  if kind == 'escaped' then MWF.rls.payEscape(S.session.bounty, S.session.heat) end
  S.session = nil
  S.bar = 0
  S.regenSlowUntil = 0
  MWF.util.resetRisk()
  MWF.breaker.cancelBreaker()
  MWF.breaker.restoreResetWrapper()
  MWF.lockdown.setRecoveryIntercept(false)
  S.inGas = false
  S.inGarage = false
  MWF.garage.closeGarage()
  S.transfer = nil
  MWF.lockdown.setChaseBlock(false)
end

-- ===== hooks from vanilla =====
function M.onPursuitAction(targetId, action, pursuit)
  if targetId ~= be:getPlayerVehicleID(0) then return end
  log('I', 'mwf', string.format('pursuit action: %s (session %s, mode %s)', tostring(action), tostring(S.session ~= nil), tostring(pursuit and pursuit.mode)))
  if action == 'start' then
    startSession(pursuit)
  elseif action == 'evade' then
    endSession('escaped')
  elseif action == 'arrest' then
    endSession('busted')
  end
end

function M.onStartRecovering()
  -- the vehicle reported a recover_vehicle press (see setRecoveryIntercept)
  if S.session then
    MWF.breaker.chaseResetGameplay(0, 'recover_vehicle')
  else
    -- stale intercept flag outside a chase: clear it and let the normal recover happen
    log('W', 'mwf', 'recover_vehicle intercepted outside a chase - clearing the stale flag')
    MWF.lockdown.setRecoveryIntercept(false)
    local veh = getObjectByID(be:getPlayerVehicleID(0) or -1)
    if veh then veh:queueLuaCommand("recovery.startRecovering()") end
  end
end

function M.onVehicleResetted(vehId)
  if S.session and vehId == be:getPlayerVehicleID(0) then
    S.riskPauseUntil = os.clock() + 1.5
    MWF.util.resetRisk()
  end
end

function M.onVehicleSwitched(oldId, newId)
  if not S.session then return end
  if S.inGas and newId then
    MWF.pits.scheduleTransfer(oldId, newId) -- allowed at a gas station; the chase continues
  else
    endSession('busted') -- swapping cars out on the road counts as running away from the chase
  end
end

function M.onVehicleReplaced(vehId)
  if not S.session or S.breaker or vehId ~= be:getPlayerVehicleID(0) then return end
  if S.inGas then
    MWF.pits.scheduleTransfer(vehId, vehId)
  else
    endSession('busted')
  end
end

function M.onVehicleDestroyed(vehId)
  if S.session and vehId == be:getPlayerVehicleID(0) and not (S.inGas or S.transfer) then endSession('busted') end
end

function M.onClientStartMission()
  if S.session then endSession('level restarted') end
  MWF.escalation.escReset()
  S.hiddenCivs, S.restoreQueue = {}, {}
  MWF.breaker.cancelBreaker()
  MWF.breaker.restoreResetWrapper()
  S.chaseBlocked = true -- force the unlock even if this module forgot it was locked (stale filter from before a reload)
  MWF.lockdown.setChaseBlock(false)
  S.inGas = false
  S.inGarage = false
  MWF.garage.closeGarage()
  S.transfer = nil
end

function M.onClientEndMission()
  if S.session then endSession('level ended') end
  MWF.escalation.escReset()
  S.hiddenCivs, S.restoreQueue = {}, {}
  S.bar = 0
  S.regenSlowUntil = 0
  MWF.breaker.cancelBreaker()
  MWF.breaker.restoreResetWrapper()
  MWF.lockdown.setChaseBlock(false)
end

function M.onExtensionUnloaded()
  MWF.achievements.flush()
  S.inGarage = false
  MWF.garage.closeGarage()
  MWF.breaker.cancelBreaker()
  MWF.breaker.restoreResetWrapper()
  MWF.lockdown.setRecoveryIntercept(false)
  MWF.lockdown.setChaseBlock(false)
  -- put hidden civilians back (and, if a chase was running, drop its extra units)
  pcall(function()
    for id in pairs(S.hiddenCivs) do
      local o = getObjectByID(id)
      if o then o:setActive(1) end
    end
    for _, ids in pairs(S.esc.groups) do for _, id in ipairs(ids) do MWF.escalation.deleteVeh({id = id}) end end
    for id in pairs(S.esc.props) do MWF.escalation.deleteVeh({id = id, prop = true}) end
    for _, id in ipairs(S.esc.specials) do MWF.escalation.deleteVeh({id = id}) end
  end)
  S.hiddenCivs = {}
end

MWF.session = {endSession = endSession, startSession = startSession}

return M
