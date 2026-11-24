-- The achievements window (Alt+K) and the banner that slides in when one unlocks.
local MWF = require('/lua/ge/extensions/mwf/core/registry')
local S = MWF.S
local UI = require('/lua/ge/extensions/mwf/ui/theme')
local ACH = require('/lua/ge/extensions/mwf/data/achievements')
local im = ui_imgui

local M = {}
local BANNER_TIME = 6

local function fmtValue(v, fmt, system)
  if fmt == "dist" then
    if system == "imperial" then return string.format("%.1f mi", v / ACH.MILE) end
    return string.format("%.1f km", v / ACH.KM)
  end
  if fmt == "money" then return string.format("$%d", math.floor(v)) end
  if fmt == "time" then return string.format("%d:%02d", math.floor(v / 60), math.floor(v % 60)) end
  return tostring(math.floor(v))
end

-- ===== the list: Lua side of the Vue page MwfAchievements.vue =====
local shown, openedAt, acked = false, 0, false
local OPEN_TIMEOUT = 4

-- called every frame: tells the page to open or close
local function drawWindow()
  local want = S.ach.show[0] == true
  if want ~= shown then
    shown = want
    if want then openedAt, acked = os.clock(), false end
    guihooks.trigger('MwfAchievements', {visible = want})
  end
  if want and not acked and os.clock() - openedAt > OPEN_TIMEOUT then
    log('E', 'mwf', 'Achievements UI did not answer: is ui/ui-vue/mods/most_wanted_freeroam loaded?')
    MWF.util.toast("error", "Achievements UI did not load", "Check BeamNG.log for errors from most_wanted_freeroam.", 6000)
    S.ach.show[0] = false
  end
end

-- everything the page shows, with the numbers already formatted for the player's unit system
function M.achievementsGet()
  acked = true
  if not S.ach.loaded then MWF.achievements.load() end
  local system = MWF.util.unitSystem()
  local items, done = {}, 0
  for _, a in ipairs(ACH.LIST) do
    local got = S.ach.unlocked[a.id] ~= nil
    if got then done = done + 1 end
    local goal = ACH.goalOf(a, system)
    local v = math.min(goal, S.ach.stats[a.stat] or 0)
    items[#items + 1] = {id = a.id, name = a.name, desc = ACH.descOf(a, system), got = got,
      progress = goal > 1 and not got and (v / goal) or nil,
      progressText = goal > 1 and not got and (fmtValue(v, a.fmt, system) .. " / " .. fmtValue(goal, a.fmt, system)) or nil}
  end
  return {done = done, total = #ACH.LIST, items = items}
end

-- the Reset button on the page (it asks to confirm first); answers with the fresh list
function M.achievementsReset()
  MWF.achievements.reset()
  return M.achievementsGet()
end

function M.achievementsClose() S.ach.show[0] = false end
function M.openAchievements() S.ach.show[0] = true end

-- banner at the top centre for a few seconds after an unlock (one at a time, queued)
local function drawBanner()
  local b = S.ach.banners[1]
  if not b then return end
  if not b.shown then b.shown = os.clock() end
  local age = os.clock() - b.shown
  if age > BANNER_TIME then table.remove(S.ach.banners, 1) return end
  local alpha = math.min(1, math.min(age * 3, (BANNER_TIME - age) * 2))
  local vp = im.GetMainViewport()
  im.SetNextWindowPos(im.ImVec2(vp.Pos.x + vp.Size.x * 0.5, vp.Pos.y + 70), im.Cond_Always, im.ImVec2(0.5, 0))
  im.SetNextWindowBgAlpha(0.93 * alpha)
  im.PushStyleColor2(im.Col_Border, im.ImVec4(0, 191/255, 1, 0.6 * alpha))
  im.PushStyleVar1(im.StyleVar_WindowRounding, 12)
  im.PushStyleVar1(im.StyleVar_WindowBorderSize, 1)
  local flags = bit.bor(im.WindowFlags_NoTitleBar, im.WindowFlags_NoResize, im.WindowFlags_NoMove, im.WindowFlags_NoScrollbar,
    im.WindowFlags_NoCollapse, im.WindowFlags_NoInputs, im.WindowFlags_NoSavedSettings, im.WindowFlags_AlwaysAutoResize)
  im.Begin("##mwfAchBanner", nil, flags)
  im.TextColored(UI.col(UI.PURPLE, alpha), "ACHIEVEMENT UNLOCKED")
  im.SetWindowFontScale(1.3)
  im.TextColored(UI.col(UI.GOOD, alpha), b.a.name)
  im.SetWindowFontScale(1.0)
  im.TextColored(UI.col(UI.MUTED, alpha), ACH.descOf(b.a, MWF.util.unitSystem()))
  im.End()
  im.PopStyleVar(2)
  im.PopStyleColor(1)
end

local function draw()
  drawBanner()
  drawWindow()
end

MWF.achievementsui = {draw = draw}

return M
