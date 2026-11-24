-- Most Wanted Freeroam (mwf_core)
-- Standalone Most Wanted for BeamNG freeroam: 10 heat levels, bounty, a 3-slot reset bar spent on weapons and resets, pit stops,
-- escalating police. Depends only on vanilla gameplay_police / gameplay_traffic.
--
-- This file only LOADS the modules and wires the game's hooks. The logic lives in:
--   core/    registry (shared object), state, util, options (load / save)
--   data/    config (tuning numbers), units (police units per heat level)
--   chase/   session, pursuit, bar, difficulty, escalation, breaker, lockdown, civilians
--   world/   pits (gas stations, garages, POI fallback)
--   economy/ garage (prices, guards), weapons (Weapon Panel / Universal Weapons gating)
--   ui/      theme, hud, garage_window, options_window
-- Modules are plain Lua files that return a table. Their on* hooks and public functions are merged into this extension so the
-- game (and the vehicle-side mwfWeapons extension) can call them as mwf_core.<name>.
--
-- Public API used from outside: mwf_core.spendSlot / requestSlot / reportAmmo (weapons), toggleHud / toggleOptions / toggleGarage.

local M = {}
local BASE = '/lua/ge/extensions/mwf/'

local MWF = rerequire(BASE .. 'core/registry') -- fresh table on every (re)load
MWF.core = M
local S = MWF.S
local im = ui_imgui

-- load order: data and helpers first, then the modules that use them (rerequire = always read the files again)
local DATA = {'data/config', 'data/units', 'data/achievements', 'ui/theme'}
local LOGIC = {'core/state', 'core/util', 'core/options', 'chase/lockdown', 'chase/breaker', 'chase/difficulty', 'chase/escalation',
  'chase/pursuit', 'chase/bar', 'chase/style', 'chase/onfoot', 'chase/civilians', 'world/pits', 'economy/garage', 'economy/weapons', 'ui/hud', 'ui/garage_window',
  'ui/options_window', 'compat/rls', 'compat/mwm', 'achievements/tracker', 'ui/achievements_window', 'chase/session'}
for _, path in ipairs(DATA) do rerequire(BASE .. path) end
local CFG = require(BASE .. 'data/config')
for _, path in ipairs(LOGIC) do
  local mod = rerequire(BASE .. path)
  if type(mod) == 'table' then
    for k, v in pairs(mod) do M[k] = v end -- hooks and public functions of that module
  end
end


function M.isFastTravelLocked() return S.session ~= nil end
function M.getBar() return S.bar, CFG.BAR_MAX, CFG.SLOTS end
function M.getSession() return S.session end
function M.toggleHud() S.hudVisible[0] = not S.hudVisible[0] end

function M.onExtensionLoaded()
  MWF.options.loadOptions()
  MWF.achievements.load()
  pcall(MWF.weapons.installWeaponPanelHooks)
  pcall(MWF.garage.installVehicleGuards)
  -- clear any intercept flag left on a vehicle by an earlier run of this mod
  pcall(function() for vid in activeVehiclesIterator() do MWF.lockdown.sendIntercept(vid, false) end end)
end

-- ===== main loop =====
function M.onUpdate(dtReal, dtSim)
  if not S.optionsLoaded then MWF.options.loadOptions() end
  if not im.mwfWrapped then pcall(MWF.weapons.installWeaponPanelHooks) end
  if gameplay_walk and not gameplay_walk.mwfWrapped then pcall(MWF.onfoot.installTheftHook) end
  if ui_pause_providers_vehicleTabInteractions and not ui_pause_providers_vehicleTabInteractions.mwfWrapped then pcall(MWF.session.installPauseWatch) end
  pcall(MWF.mwm.install)
  if not (core_vehicles and core_vehicles.mwfWrapped and core_vehicle_partmgmt and core_vehicle_partmgmt.mwfWrapped) then pcall(MWF.garage.installVehicleGuards) end
  if not S.session and not S.breaker then
    S.idleClear = (S.idleClear or 0) + dtReal
    if S.idleClear > 3 then S.idleClear = 0 MWF.lockdown.sendIntercept(be:getPlayerVehicleID(0), false) end
  end
  if S.resetTrace then
    S.resetTrace.t = S.resetTrace.t + dtReal
    if S.resetTrace.t > 2.5 then
      local v = MWF.util.getPlayerVeh()
      if v then
        local p = v:getPosition()
        log('I', 'mwf', string.format('Reset: now at %.1f,%.1f,%.1f (moved %.0f m)', p.x, p.y, p.z, (p - S.resetTrace.pos):length()))
      end
      S.resetTrace = nil
    end
  end
  MWF.garage.keepGaragePaused()
  MWF.escalation.tickEscalation(dtReal)
  MWF.civilians.tickCivilians(dtReal)
  MWF.difficulty.tickSensitivity(dtReal)
  MWF.achievements.tick(dtReal)
  MWF.pits.tickPoiLabels(dtReal)
  MWF.rls.tick(dtReal)
  MWF.breaker.tickBreaker(dtReal)
  MWF.pits.tickTransfer(dtReal)
  local veh, id = MWF.util.getPlayerVeh()
  if veh then
    local pd = MWF.util.getPursuit(id)

    if S.session and pd and pd.mode and pd.mode > 0 then S.session.lastMode = pd.mode end
    if S.transfer then
      -- chase is being handed to the new car; do nothing until it is done
    elseif pd and pd.mode and pd.mode > 0 then
      if not S.session and (pd.timers and (pd.timers.main or 0) > 0.5 and (pd.timers.main or 0) < 5) then MWF.session.startSession(pd) end -- only if the 'start' hook was missed on a fresh chase
    elseif S.session and pd and pd.mode ~= nil and pd.mode <= 0 then
      -- hooks normally end the chase; this catches resets done by other mods
      MWF.session.endSession(pd.mode == -1 and 'busted' or 'escaped')
    end

    if S.session and pd and not S.transfer then
      MWF.pursuit.updatePursuit(dtSim, pd, id)
      MWF.pits.checkGasStations(veh)
      MWF.bar.updateBar(dtSim, veh, id)
      MWF.style.updateStyle(dtSim, veh, id)
      MWF.onfoot.update(dtSim, veh, id)
    end
  end

  -- no slot, no reset (only while a chase is on)
  S.resetsLocked = S.session ~= nil and not (MWF.util.canSpend() and MWF.util.canAffordReset())

  MWF.hud.drawHud()
  MWF.hud.drawAmmo()
  MWF.garageui.drawGarage()
  MWF.optionsui.drawOptions()
  MWF.achievementsui.draw()
end

return M
