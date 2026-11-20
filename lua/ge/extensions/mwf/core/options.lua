-- Player options: defaults, load from / save to /settings/mwf_options.json.
local MWF = require('/lua/ge/extensions/mwf/core/registry')
local S = MWF.S

local M = {}
-- player options (saved to /settings/mwf_options.json, window opened with Alt+M or mwf_core.toggleOptions())
local OPTIONS_FILE = "/settings/mwf_options.json"

local function loadOptions()
  S.optionsLoaded = true
  local ok, data = pcall(jsonReadFile, OPTIONS_FILE)
  if ok and type(data) == 'table' then
    for k, v in pairs(data) do if S.options[k] ~= nil and type(v) == type(S.options[k]) then S.options[k] = v end end
  end
  S.optUI.hide[0], S.optUI.smooth[0] = S.options.hideCivilians, S.options.smooth
  S.optUI.interval[0], S.optUI.scale[0] = S.options.spawnInterval, S.options.waveScale
  S.optUI.pit[0], S.optUI.factor[0], S.optUI.fb[0] = S.options.pitCosts, S.options.priceFactor, S.options.fallbackPits
  S.optUI.sens[0] = S.options.sensitivity
  S.optUI.rlsPay[0] = (S.options.rlsResetPayment == "private") and 1 or 0
  MWF.difficulty.refreshSensitivity()
end

local function saveOptions()
  pcall(jsonWriteFile, OPTIONS_FILE, S.options, true)
end

MWF.options = {loadOptions = loadOptions, saveOptions = saveOptions}

return M
