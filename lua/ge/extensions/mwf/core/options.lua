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
  MWF.difficulty.refreshSensitivity()
end

local function saveOptions()
  pcall(jsonWriteFile, OPTIONS_FILE, S.options, true)
end

MWF.options = {loadOptions = loadOptions, saveOptions = saveOptions}

return M
