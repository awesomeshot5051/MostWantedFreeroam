-- Most Wanted Mission (Mathkuro) minimap compatibility. That mod's "Most Wanted: Minimap" app shows a heat number with a flame and a
-- heat ring, and reads them from mathkuro_mostWantedMission.getPursuitData(). That mod only runs the heat itself during its own mission,
-- so in a freeroam chase driven by THIS mod the number never moved. Nothing in that mod is edited: this module wraps the one exported
-- function at run time and, while one of our chases is on, answers with our heat, the progress through it, and whether the police see
-- you. Outside a chase (and when that mod is not installed) the original function answers as before.
local MWF = require('/lua/ge/extensions/mwf/core/registry')
local S = MWF.S

local M = {}

local function ours()
  local h = MWF.hud.heatData()
  local pd = MWF.util.getPursuit(be:getPlayerVehicleID(0)) or {}
  return h, pd
end

-- the app can unload and re-load that extension (a new table), so this is checked every frame, like the other wrappers
local function install()
  local ext = rawget(_G, 'mathkuro_mostWantedMission')
  if type(ext) ~= 'table' or ext.mwfWrapped or type(ext.getPursuitData) ~= 'function' then return end
  ext.mwfWrapped = true
  local orig = ext.getPursuitData
  ext.getPursuitData = function(...)
    local base = orig(...)
    if not S.session then return base end
    local ok, res = pcall(function()
      local h, pd = ours()
      local out = {}
      if type(base) == 'table' then for k, v in pairs(base) do out[k] = v end end
      out.mode = (pd.mode and pd.mode > 0) and pd.mode or 1 -- the app only draws the meter while the pursuit mode is above 0
      out.currentHeatLevel = h.heat
      out.bountyProgress = h.progress
      out.bounty = h.bounty
      out.policeVisible = h.pursued
      out.timers = {main = pd.timers and pd.timers.main or 0, evadeValue = h.evadeValue, arrestValue = h.arrestValue}
      return out
    end)
    if ok and res then return res end
    return base
  end
  log('I', 'mwf', 'Most Wanted Mission minimap: its heat now follows this mod during a chase')
end

M.installMwmCompat = install
MWF.mwm = {install = install}

return M
