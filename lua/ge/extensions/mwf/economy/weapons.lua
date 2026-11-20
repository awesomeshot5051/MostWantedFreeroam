-- Weapon gating: Weapon Panel wrapper, Universal Weapons slot requests, weapon bounty and costs.
local MWF = require('/lua/ge/extensions/mwf/core/registry')
local S = MWF.S
local CFG = require('/lua/ge/extensions/mwf/data/config')
local im = ui_imgui

local M = {}

-- ===== public API =====
-- Pays bounty for a paid Weapon Panel use on a vehicle (called from the panel gating below).
function M.weaponHit(name, vehId)
  if not S.session then return end
  local _, pid = MWF.util.getPlayerVeh()
  if vehId == pid then return end -- self-target gives nothing
  local def = CFG.WEAPON_BOUNTY[name]
  if not def then return end
  local tv = gameplay_traffic and gameplay_traffic.getTrafficData and gameplay_traffic.getTrafficData()[vehId]
  local isCop = tv and tv.role and tv.role.name == 'police'
  if isCop then S.session.weaponTag[vehId] = os.clock() end
  MWF.pursuit.award('weapon_' .. name .. (isCop and '_cop' or '_civ'),
    string.format("%s %s", isCop and "Police car" or "Civilian car", def[3]), isCop and def[1] or def[2], CFG.WEAPON_MIN, CFG.WEAPON_MAX)
end

-- Pays for one weapon use: `slots` of reset bar (default 1) and `cost` bounty. Free outside a chase. Never lowers heat.
function M.spendSlot(name, slots, cost)
  if not S.session then return true end -- weapons are free outside an active chase
  slots = slots or 1
  if not MWF.util.canSpend(slots) then return false end
  if cost and cost > 0 then
    cost = math.max(1, math.floor(cost * MWF.util.bountyScale())) -- RLS career: weapons cost scaled-down bounty
    if cost > MWF.garage.wallet() then
      if os.clock() - S.lastCostToast > 2 then -- a held trigger retries every half second
        S.lastCostToast = os.clock()
        MWF.util.toast("warning", "Not enough bounty", string.format("%s costs $%d bounty, you have $%d.", tostring(name), cost, math.floor(MWF.garage.wallet())), 2500)
      end
      return false
    end
    MWF.garage.spendBounty(cost, tostring(name))
  end
  S.bar = math.max(0, S.bar - CFG.SLOT_COST * slots)
  log('I', 'mwf', string.format('Spent %d reset-bar slot(s) and $%d on %s', slots, cost or 0, tostring(name)))
  return true
end

function M.requestSlot(vehId, roundsPerSlot, weaponKey)
  local _, pid = MWF.util.getPlayerVeh()
  -- only the player's own gun is part of the economy, and only while a chase is active
  local ok = true
  local paid = S.session and vehId == pid
  if paid then
    local rounds = tonumber(roundsPerSlot) or 0
    ok = MWF.core.spendSlot('Gun ammo', 1, rounds >= 50 and CFG.GUN_COST_MG or CFG.GUN_COST_BIG)
    if ok then MWF.achievements.add('weaponUses', 1) end
  end
  log('I', 'mwf', string.format('Universal Weapon slot request from vehicle %s (%s): %s%s', tostring(vehId), tostring(weaponKey),
    ok and 'granted' or 'DENIED (bar or bounty too low)', paid and ' [chase: paid]' or ' [free: no chase or not your car]'))
  be:queueObjectLua(vehId, string.format(
    "if extensions.mwfWeapons then extensions.mwfWeapons.grantSlot(%q, %s, %d) end",
    tostring(weaponKey or "fireweapons"), tostring(ok and true or false), tonumber(roundsPerSlot) or 0))
end

function M.reportAmmo(vehId, fe, current, max)
  S.ammoByVeh[vehId] = S.ammoByVeh[vehId] or {}
  local prev = S.ammoByVeh[vehId][fe]
  -- rounds going down on the player's car = the player is shooting (used to discount gun kills)
  if prev and (current or 0) < prev.rounds and vehId == select(2, MWF.util.getPlayerVeh()) then S.lastGunFire = os.clock() end
  S.ammoByVeh[vehId][fe] = {rounds = current or 0, max = max or 0}
end

-- ===== Weapon Panel gating WITHOUT touching that mod's files =====
-- The Weapon Panel draws its buttons with ImGui inside a window titled "Weapons Panel". We wrap ui_imgui's Begin/End/Button
-- (and guihooks.trigger, to see the panel's own "success" toasts) once, and only act while that window is being drawn.
-- During a chase: a press with no slot available is swallowed (the panel never sees the click); a press that goes through is
-- charged one slot only if the panel reports success (so cooldowns and "no target" cost nothing). If the Weapon Panel mod is
-- not installed, its window is never drawn and none of this does anything.
local WP_BUTTONS = {
  ["Fire EMP"] = "EMP", ["Fire Missile"] = "Missile", ["Fire Chain Missile"] = "Chain Missile",
  ["Throttle Lock Target"] = "Throttle Lock", ["Brake Lock Target"] = "Brake Lock",
  ["Steering Jam LEFT"] = "Steering Jam", ["Steering Jam RIGHT"] = "Steering Jam",
  ["Lock Parking Brake"] = "Parking Brake Lock", ["Pop Tires"] = "Tire Pop",
}
local wp = {inPanel = false, pending = {}, success = 0}

local function guessWeaponTarget(name)
  local pveh, pid = MWF.util.getPlayerVeh()
  if not pveh then return nil end
  local ppos, pdir = pveh:getPosition(), pveh:getDirectionVector()
  local traffic = gameplay_traffic and gameplay_traffic.getTrafficData and gameplay_traffic.getTrafficData() or {}
  local best, bestD
  for id in pairs(traffic) do
    local o = id ~= pid and getObjectByID(id)
    if o and o:getActive() then
      local off = o:getPosition() - ppos
      local d = off:length()
      local ok
      if name == "Tire Pop" then ok = d < 20 else ok = d < 200 and d > 0.1 and (off / d):dot(pdir) > 0.3 end
      if ok and (not bestD or d < bestD) then best, bestD = id, d end
    end
  end
  return best
end

function M.wpGate(label)
  local name = WP_BUTTONS[label]
  if not name or not S.session then return true end -- not a weapon button, or no chase: free, as in the original mod
  local slots = CFG.WEAPON_SLOTS[name] or 1
  if not MWF.util.canSpend(slots) then
    MWF.util.toast("warning", "Reset Bar Empty", slots > 1 and string.format("%s drains all %d reset bars. Fill the whole bar first.", name, slots)
      or ("Not enough reset bar for " .. name .. ". Drive risky to refill."), 2500)
    return false
  end
  local cost = math.floor((CFG.WEAPON_COST[name] or 0) * MWF.util.bountyScale())
  if cost > MWF.garage.wallet() then
    MWF.util.toast("warning", "Not enough bounty", string.format("%s costs $%d bounty, you have $%d.", name, cost, math.floor(MWF.garage.wallet())), 2500)
    return false
  end
  table.insert(wp.pending, name)
  return true
end

function M.wpToast(data)
  if wp.inPanel and #wp.pending > 0 and type(data) == 'table' and data.type == "success" then wp.success = wp.success + 1 end
end

function M.wpPanelEnd()
  local n = math.min(#wp.pending, wp.success)
  for i = 1, n do
    local name = wp.pending[i]
    if MWF.core.spendSlot(name, CFG.WEAPON_SLOTS[name], CFG.WEAPON_COST[name]) then
      MWF.achievements.add('weaponUses', 1)
      if name == 'EMP' then MWF.achievements.add('empUses', 1) end
      local target = guessWeaponTarget(name)
      if target then MWF.core.weaponHit(name, target) end
    end
  end
  wp.pending, wp.success, wp.inPanel = {}, 0, false
end

local function installWeaponPanelHooks()
  if not im or im.mwfWrapped then return end
  im.mwfWrapped = true
  local origBegin, origEnd, origButton = im.Begin, im.End, im.Button
  im.Begin = function(name, ...)
    if name == "Weapons Panel" and mwf_core then mwf_core.wpBegin() end
    return origBegin(name, ...)
  end
  im.End = function(...)
    if mwf_core and mwf_core.wpIsOpen() then mwf_core.wpPanelEnd() end
    return origEnd(...)
  end
  im.Button = function(label, ...)
    local pressed = origButton(label, ...)
    if pressed and mwf_core and mwf_core.wpIsOpen() then return mwf_core.wpGate(label) end
    return pressed
  end
  if guihooks and not guihooks.mwfWrapped then
    guihooks.mwfWrapped = true
    local origTrigger = guihooks.trigger
    guihooks.trigger = function(hook, data, ...)
      if hook == "toastrMsg" and mwf_core then mwf_core.wpToast(data) end
      return origTrigger(hook, data, ...)
    end
  end
end

function M.wpBegin() wp.inPanel = true end
function M.wpIsOpen() return wp.inPanel end

MWF.weapons = {installWeaponPanelHooks = installWeaponPanelHooks}

return M
