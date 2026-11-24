-- The options window (Alt+M, or a controller button bound to it): Lua side of the Vue page ui/ui-vue/mods/most_wanted_freeroam/MwfOptions.vue.
-- (It is a real game UI page, not an ImGui window, so it works with a controller and the on-screen keyboard.)
-- The page reads everything with optionsGet() and changes one option at a time with optionsSet(key, value); this file only
-- validates the value, applies the side effects, saves, and tells the page when to open and close.
local MWF = require('/lua/ge/extensions/mwf/core/registry')
local S = MWF.S

local M = {}
S.optUI = {show = false, shown = false, openedAt = 0, ack = false}
local OPEN_TIMEOUT = 4 -- seconds the page gets to answer before we give up on it

-- limits of the numeric options (the page uses the same ones for its - / + buttons)
local LIMITS = {
  spawnInterval = {0.5, 6.0}, waveScale = {0.25, 1.0}, sensitivity = {0.25, 2.0}, priceFactor = {0.1, 1.0},
}
local CHOICES = {rlsResetPayment = {insurance = true, private = true}}

-- called every frame: tells the page to open or close
local function drawOptions()
  local want = S.optUI.show
  if want ~= S.optUI.shown then
    S.optUI.shown = want
    if want then S.optUI.openedAt, S.optUI.ack = os.clock(), false end
    guihooks.trigger('MwfOptions', {visible = want})
  end
  if want and not S.optUI.ack and os.clock() - S.optUI.openedAt > OPEN_TIMEOUT then
    log('E', 'mwf', 'Options UI did not answer: is ui/ui-vue/mods/most_wanted_freeroam loaded?')
    MWF.util.toast("error", "Options UI did not load", "Check BeamNG.log for errors from most_wanted_freeroam.", 6000)
    S.optUI.show = false
  end
end

function M.toggleOptions()
  if not S.optionsLoaded then MWF.options.loadOptions() end
  S.optUI.show = not S.optUI.show
end

-- the page's first call
function M.optionsInit()
  S.optUI.ack = true
  return M.optionsGet()
end

function M.optionsGet()
  local o = {}
  for k, v in pairs(S.options) do o[k] = v end
  o.rlsActive = S.rls.active == true
  return o
end

function M.optionsSet(key, value)
  key = tostring(key)
  local old = S.options[key]
  if old == nil or type(old) ~= type(value) then return M.optionsGet() end
  if type(value) == 'number' then
    local lim = LIMITS[key]
    if lim then value = math.max(lim[1], math.min(lim[2], value)) end
  elseif type(value) == 'string' then
    if not (CHOICES[key] and CHOICES[key][value]) then return M.optionsGet() end
  end
  S.options[key] = value
  if key == 'pitCosts' then MWF.lockdown.refreshBlock() end
  if key == 'sensitivity' then MWF.difficulty.refreshSensitivity() end
  MWF.options.saveOptions()
  return M.optionsGet()
end

function M.optionsClose() S.optUI.show = false end

MWF.optionsui = {drawOptions = drawOptions}

return M
