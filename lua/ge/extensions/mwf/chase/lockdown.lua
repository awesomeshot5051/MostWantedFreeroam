-- Input lockdown during a chase (action filter), recovery intercept and the fast-travel guard.
local MWF = require('/lua/ge/extensions/mwf/core/registry')
local S = MWF.S

local M = {}

-- While a chase is on, these vanilla input groups are blocked (anything that resets/teleports/replaces the car,
-- changes vehicle, opens configurators, free cam, cheats...). The plain reset key (reset_physics) is NOT blocked:
-- it is intercepted instead and runs the Crash Breaker sequence for one slot.
-- Teleport-to-last-road is the only free recovery.
local BLOCK_TEMPLATES = {"vehicleTeleporting", "vehicleMenues", "vehicleSwitching", "vehicleRecovery", "vehicleTeleportOnly",
  "freeCam", "funStuff", "walkingMode", "aiControls", "physicsControls", "photoMode", "trackBuilder", "editor"}
local ALWAYS_ALLOWED = {recover_to_last_road = true, reset_physics = true, recover_vehicle = true, recover_vehicle_alt = true}
local FALLBACK_BLOCKED = {"recover_vehicle", "recover_vehicle_alt", "loadHome", "saveHome", "reset_all_physics", "reload_vehicle",
  "reload_all_vehicles", "dropPlayerAtCamera", "dropPlayerAtCameraNoReset", "vehicle_selector", "parts_selector", "vehicledebugMenu",
  "switch_next_vehicle", "switch_previous_vehicle", "toggleCamera", "dropCameraAtPlayer", "toggleWalkingMode"}

-- inside a gas station these are available again (configurator, parts, vehicle switching/selector)
local GAS_OPEN_TEMPLATES = {vehicleMenues = true, vehicleSwitching = true}
local GAS_OPEN_ACTIONS = {vehicle_selector = true, parts_selector = true, vehicledebugMenu = true,
  switch_next_vehicle = true, switch_previous_vehicle = true}

local function buildBlockedList()
  local list, seen = {}, {}
  local templates = core_input_actionFilter and core_input_actionFilter.getActionTemplates and core_input_actionFilter.getActionTemplates()
  -- free pit stops open the selector, parts and switching; with pit costs only the parts configurator opens (it is priced)
  -- and the car-buying UI is this mod's own garage window
  local function gasOpen(a, tname)
    if not S.inGas then return false end
    if S.options.pitCosts then return S.inGarage and a == 'parts_selector' end
    return GAS_OPEN_ACTIONS[a] or (tname and GAS_OPEN_TEMPLATES[tname]) or false
  end
  local function add(a)
    if not ALWAYS_ALLOWED[a] and not seen[a] then seen[a] = true; table.insert(list, a) end
  end
  if type(templates) == 'table' then
    for _, tname in ipairs(BLOCK_TEMPLATES) do
      if not (tname == "walkingMode" and S.options.onFoot) then -- getting out of the car is allowed with the on-foot option
        for _, a in ipairs(templates[tname] or {}) do
          if not gasOpen(a, tname) then add(a) end
        end
      end
    end
  end
  for _, a in ipairs(FALLBACK_BLOCKED) do
    if not gasOpen(a) and not (a == "toggleWalkingMode" and S.options.onFoot) then add(a) end
  end
  return list
end

-- The big map itself stays usable during a chase (set waypoints, look around); only quick/fast travel from it is blocked.
-- The wrapper stays installed and just asks the live extension, so a reload can never leave it stuck on.
local function installFastTravelGuard()
  local bm = freeroam_bigMapMode
  if not bm or bm.mwfOrigTeleportToPoi or not bm.teleportToPoi then return end
  bm.mwfOrigTeleportToPoi = bm.teleportToPoi
  bm.teleportToPoi = function(...)
    if mwf_core and mwf_core.isFastTravelLocked and mwf_core.isFastTravelLocked() then
      guihooks.trigger("toastrMsg", {type = "warning", title = "Fast Travel Locked", msg = "No fast travel during a chase. Waypoints still work.", config = {timeOut = 2500}})
      return
    end
    return bm.mwfOrigTeleportToPoi(...)
  end
end

S.chaseBlocked = false
local function setChaseBlock(on)
  if on == S.chaseBlocked then return end
  S.chaseBlocked = on
  if on then installFastTravelGuard() end
  if core_input_actionFilter then
    core_input_actionFilter.setGroup('mwfChaseBlocked', buildBlockedList())
    core_input_actionFilter.addAction(0, 'mwfChaseBlocked', on)
  end
end

-- recover_vehicle / recover_vehicle_alt (the usual controller 'reset' button) are not blocked; instead the vehicle is told
-- to report the press to us (recovery.recoveryHooksOnly -> hook onStartRecovering) so it can run the Crash Breaker.
-- Remember every vehicle we ever switched the flag on for, so it can always be switched back off - a stuck flag
-- would make recover_vehicle do nothing outside a chase.
local interceptIds = {}
local function sendIntercept(id, on)
  local veh = getObjectByID(id)
  if veh then veh:queueLuaCommand("recovery.recoveryHooksOnly = " .. tostring(on and true or false)) end
end

local function setRecoveryIntercept(on)
  local pid = be:getPlayerVehicleID(0)
  if on then
    if pid and pid >= 0 then interceptIds[pid] = true sendIntercept(pid, true) end
  else
    for id in pairs(interceptIds) do sendIntercept(id, false) end
    if pid and pid >= 0 then sendIntercept(pid, false) end
    interceptIds = {}
  end
end

local function refreshBlock()
  if S.chaseBlocked and core_input_actionFilter then
    core_input_actionFilter.setGroup('mwfChaseBlocked', buildBlockedList())
    core_input_actionFilter.addAction(0, 'mwfChaseBlocked', true)
  end
end

MWF.lockdown = {refreshBlock = refreshBlock, sendIntercept = sendIntercept, setChaseBlock = setChaseBlock, setRecoveryIntercept = setRecoveryIntercept}

return M
