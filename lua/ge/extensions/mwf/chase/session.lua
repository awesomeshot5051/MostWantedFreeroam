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
  MWF.escalation.sweepLeftovers()
  S.session.weaponTag = {}
  -- police cars that are already wrecked when the chase starts are not part of it: never pay them out as wrecks
  pcall(function()
    for pid, pveh in pairs(gameplay_police.getPoliceVehicles()) do
      if pveh.role and pveh.role.state == 'disabled' then S.session.wrecked[pid] = true end
    end
  end)
  S.stats.wrecked, S.stats.hitPolice, S.stats.copsPresent = 0, 0, 0
  S.session.bounty = CFG.SCORE_LEVELS[1]
  S.bar = 0
  S.regenSlowUntil = 0
  MWF.util.resetRisk()
  S.lastEnd = nil
  MWF.onfoot.reset()
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
  MWF.achievements.checkAll() -- goals reached outside a chase unlock now
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
  MWF.onfoot.reset()
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

-- ===== resetting from the pause menu ends the chase =====
-- The pause menu's Reset button (ui/pause/providers/vehicleTabInteractions) resets the car directly, bypassing the Crash Breaker and its
-- cost. Its only public entry is executeVehicleTabInteractionAction(buttonId, payload), which the page calls for every button, so that is
-- wrapped once: it only notes the time. A reset of the player's car that follows shortly after, and that the Crash Breaker / a pit stop did
-- not cause, is the pause menu's reset, and counts as running away (the chase ends as "busted").
local PAUSE_RESET_WINDOW = 8 -- s

function M.notePauseAction()
  if S.session then S.pauseActionAt = os.clock() end
end

local function installPauseWatch()
  local ext = ui_pause_providers_vehicleTabInteractions
  if type(ext) ~= 'table' or ext.mwfWrapped or type(ext.executeVehicleTabInteractionAction) ~= 'function' then return end
  ext.mwfWrapped = true
  local orig = ext.executeVehicleTabInteractionAction
  ext.executeVehicleTabInteractionAction = function(...)
    if mwf_core and mwf_core.notePauseAction then mwf_core.notePauseAction() end
    return orig(...)
  end
  log('I', 'mwf', 'Pause menu: vehicle actions watched (a pause menu reset ends the chase)')
end

function M.onVehicleResetted(vehId)
  if S.session and vehId == be:getPlayerVehicleID(0) and S.pauseActionAt and os.clock() - S.pauseActionAt < PAUSE_RESET_WINDOW
    and not (S.breaker or os.clock() < (S.breakerLockUntil or 0) or S.inGas or S.inGarage or S.transfer or S.foot.active) then
    S.pauseActionAt = nil
    log('I', 'mwf', 'The car was reset from the pause menu: chase over')
    MWF.util.toast("warning", "Chase over", "Resetting from the pause menu counts as running away.", 4000)
    endSession('busted')
    return
  end
  if S.session and vehId == be:getPlayerVehicleID(0) then
    S.riskPauseUntil = os.clock() + 1.5
    MWF.util.resetRisk()
  end
end

local function repairing() return S.rlsRepairUntil ~= nil and os.clock() < S.rlsRepairUntil end -- an RLS computer repair is in progress

function M.onVehicleSwitched(oldId, newId)
  if not S.session then return end
  if S.inGas and newId then
    MWF.pits.scheduleTransfer(oldId, newId) -- allowed at a gas station; the chase continues
  elseif MWF.onfoot.handleSwitch(oldId, newId) then
    -- got out of the car (or into another one) during the chase: it goes on
  elseif repairing() and newId then
    MWF.pits.scheduleTransfer(oldId, newId) -- the RLS repair respawned the car: the chase goes on in it
  else
    log('I', 'mwf', string.format('Chase ends: the player car was switched from %s to %s outside a pit stop', tostring(oldId), tostring(newId)))
    endSession('busted') -- swapping cars out on the road counts as running away from the chase
  end
end

function M.onVehicleReplaced(vehId)
  if not S.session or S.breaker or vehId ~= be:getPlayerVehicleID(0) then return end
  if S.inGas or repairing() then
    MWF.pits.scheduleTransfer(vehId, vehId)
  else
    log('I', 'mwf', string.format('Chase ends: the player car %s was replaced / respawned outside a pit stop (RLS career: %s)', tostring(vehId), tostring(S.rls and S.rls.active)))
    endSession('busted')
  end
end

function M.onVehicleDestroyed(vehId)
  if S.session and vehId == be:getPlayerVehicleID(0) and not (S.inGas or S.transfer or repairing()) then
    log('I', 'mwf', 'Chase ends: the player car ' .. tostring(vehId) .. ' was destroyed / removed')
    endSession('busted')
  end
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
  S.fallbackPois, S.poiLabelTimer, S.poiLabelsDone, S.poiLabelLevel = {}, nil, true, nil -- (world/pits.lua) the next level works out its own made-up pit stops
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

MWF.session = {endSession = endSession, startSession = startSession, installPauseWatch = installPauseWatch}

return M
