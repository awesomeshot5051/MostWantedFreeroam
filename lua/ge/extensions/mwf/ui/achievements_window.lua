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

local function pushStyle()
  im.PushStyleColor2(im.Col_WindowBg, im.ImVec4(20/255, 22/255, 30/255, 0.96))
  im.PushStyleColor2(im.Col_Border, im.ImVec4(0, 191/255, 1, 0.35))
  im.PushStyleColor2(im.Col_Text, im.ImVec4(UI.TEXT[1], UI.TEXT[2], UI.TEXT[3], 1))
  im.PushStyleColor2(im.Col_TitleBg, im.ImVec4(10/255, 12/255, 18/255, 1))
  im.PushStyleColor2(im.Col_TitleBgActive, im.ImVec4(0, 90/255, 130/255, 1))
  im.PushStyleVar1(im.StyleVar_WindowRounding, 12)
  im.PushStyleVar1(im.StyleVar_WindowBorderSize, 1)
end
local function popStyle()
  im.PopStyleVar(2)
  im.PopStyleColor(5)
end

local function drawWindow()
  if not S.ach.show[0] then return end
  if not S.ach.loaded then MWF.achievements.load() end
  local vp = im.GetMainViewport()
  im.SetNextWindowPos(im.ImVec2(vp.Pos.x + 60, vp.Pos.y + 90), im.Cond_FirstUseEver)
  im.SetNextWindowSize(im.ImVec2(560, 560), im.Cond_FirstUseEver)
  pushStyle()
  if im.Begin("Most Wanted - Achievements", S.ach.show) then
    local done = 0
    for _, a in ipairs(ACH.LIST) do if S.ach.unlocked[a.id] then done = done + 1 end end
    im.SetWindowFontScale(1.3)
    im.TextColored(UI.col(UI.ACCENT), string.format("ACHIEVEMENTS  %d / %d", done, #ACH.LIST))
    im.SetWindowFontScale(1.0)
    im.Separator()
    local system = MWF.util.unitSystem()
    for _, a in ipairs(ACH.LIST) do
      local got = S.ach.unlocked[a.id]
      local goal = ACH.goalOf(a, system)
      im.TextColored(UI.col(got and UI.GOOD or UI.TEXT), (got and "[x] " or "[ ] ") .. a.name)
      im.TextColored(UI.col(UI.MUTED), "      " .. ACH.descOf(a, system))
      if not got and goal > 1 then
        local v = math.min(goal, S.ach.stats[a.stat] or 0)
        local p = im.GetCursorScreenPos()
        UI.drawBar(im.GetWindowDrawList(), p.x + 24, p.y + 2, 220, 6, v / goal, UI.BLUE)
        im.Dummy(im.ImVec2(1, 10))
        im.SameLine(280)
        im.TextColored(UI.col(UI.MUTED), fmtValue(v, a.fmt, system) .. " / " .. fmtValue(goal, a.fmt, system))
      end
      im.Spacing()
    end
  end
  im.End()
  popStyle()
end

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
