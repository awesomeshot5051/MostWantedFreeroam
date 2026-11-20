-- The options window (Alt+M).
local MWF = require('/lua/ge/extensions/mwf/core/registry')
local S = MWF.S
local im = ui_imgui

local M = {}
S.optUI = {show = im.BoolPtr(false), hide = im.BoolPtr(false), smooth = im.BoolPtr(true), interval = im.FloatPtr(1.5), scale = im.FloatPtr(1.0),
  pit = im.BoolPtr(true), factor = im.FloatPtr(0.5), fb = im.BoolPtr(true), sens = im.FloatPtr(1.0), rlsPay = im.IntPtr(0)}

local function drawOptions()
  if not S.optUI.show[0] then return end
  im.SetNextWindowBgAlpha(0.9)
  im.Begin("Most Wanted Freeroam - Options", S.optUI.show, im.WindowFlags_AlwaysAutoResize)
  local changed = false
  if im.Checkbox("Hide civilian traffic during chases", S.optUI.hide) then S.options.hideCivilians = S.optUI.hide[0] changed = true end
  im.TextWrapped("Civilians are hidden while you are being chased and return when it ends. Police are not affected. Less load, fewer hitches.")
  im.Separator()
  if im.Checkbox("Smooth spawning (wait for a steady frame rate)", S.optUI.smooth) then S.options.smooth = S.optUI.smooth[0] changed = true end
  if im.SliderFloat("Seconds between unit spawns", S.optUI.interval, 0.5, 6.0, "%.1f") then S.options.spawnInterval = S.optUI.interval[0] changed = true end
  if im.SliderFloat("Wave size", S.optUI.scale, 0.25, 1.0, "%.2f") then S.options.waveScale = S.optUI.scale[0] changed = true end
  im.TextWrapped("Lower the wave size and raise the spacing if new waves make the game stutter.")
  im.Separator()
  if im.Checkbox("Pit stop costs: swapping and modifying cars costs bounty", S.optUI.pit) then
    S.options.pitCosts = S.optUI.pit[0] changed = true
    MWF.lockdown.refreshBlock()
  end
  im.TextWrapped("In a garage during a chase (the chase pauses while it is open), a custom window lists the cars you can afford and part changes are charged. Gas stations only repair. Turn this off for free swapping and modifying at pit stops.")
  im.Text("RLS career: how a Crash Breaker reset is paid")
  if im.RadioButton2("Insurance claim (the car's deductible)", S.optUI.rlsPay, 0) then S.options.rlsResetPayment = "insurance" changed = true end
  if im.RadioButton2("Private (repair estimate, at least $2,500)", S.optUI.rlsPay, 1) then S.options.rlsResetPayment = "private" changed = true end
  im.TextWrapped("Only used in an RLS Career Overhaul career. There, resets cost real money, escaping pays a small capped reward, and pit stops are off (use your garage's computer to change cars and parts).")
  im.Separator()
  if im.Button("Show achievements (Alt+K)") then S.ach.show[0] = true end
  im.Separator()
  if im.SliderFloat("Police sensitivity", S.optUI.sens, 0.25, 2.0, "%.2f") then
    S.options.sensitivity = S.optUI.sens[0] changed = true
    MWF.difficulty.refreshSensitivity()
  end
  im.TextWrapped("How easily police start a chase. 1.00 is the game's default. Lower: speeding alone stops triggering chases, and red lights or several offenses are needed. Higher: even minor offenses start one. Only affects starting a chase; a chase in progress is unchanged.")
  im.Separator()
  if im.Checkbox("Generate pit stops from map POIs when a map has none", S.optUI.fb) then S.options.fallbackPits = S.optUI.fb[0] changed = true end
  im.TextWrapped("Maps that define no gas stations and/or no garages get some made from their points of interest (spawn points etc.), alternating between the two, so both are always available. Maps that define their own are never touched.")
  if im.SliderFloat("Price factor (share of the real price)", S.optUI.factor, 0.1, 1.0, "%.2f") then S.options.priceFactor = S.optUI.factor[0] changed = true end
  im.End()
  if changed then MWF.options.saveOptions() end
end

function M.toggleOptions()
  if not S.optionsLoaded then MWF.options.loadOptions() end
  S.optUI.show[0] = not S.optUI.show[0]
end

MWF.optionsui = {drawOptions = drawOptions}

return M
