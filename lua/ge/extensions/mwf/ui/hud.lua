-- The chase HUD at the bottom of the screen and the ammo window.
local MWF = require('/lua/ge/extensions/mwf/core/registry')
local S = MWF.S
local CFG = require('/lua/ge/extensions/mwf/data/config')
local UI = require('/lua/ge/extensions/mwf/ui/theme')
local im = ui_imgui

local M = {}

local function drawHud()
  local showEnd = S.lastEnd and (os.clock() - S.lastEnd.time) < CFG.END_BANNER_TIME
  if not S.hudVisible[0] or not (S.session or showEnd) then return end

  local vp = im.GetMainViewport()
  local W = 760
  im.SetNextWindowPos(im.ImVec2(vp.Pos.x + vp.Size.x * 0.5, vp.Pos.y + vp.Size.y - 24), im.Cond_Always, im.ImVec2(0.5, 1))
  im.SetNextWindowSize(im.ImVec2(W, 0), im.Cond_Always)
  im.PushStyleColor2(im.Col_WindowBg, im.ImVec4(20/255, 22/255, 30/255, 0.93))
  im.PushStyleColor2(im.Col_Border, im.ImVec4(0, 191/255, 1, 0.25))
  im.PushStyleColor2(im.Col_Text, im.ImVec4(UI.TEXT[1], UI.TEXT[2], UI.TEXT[3], 1))
  im.PushStyleVar1(im.StyleVar_WindowRounding, 12)
  im.PushStyleVar1(im.StyleVar_WindowBorderSize, 1)
  local flags = bit.bor(im.WindowFlags_NoTitleBar, im.WindowFlags_NoResize, im.WindowFlags_NoMove, im.WindowFlags_NoScrollbar,
    im.WindowFlags_NoCollapse, im.WindowFlags_NoInputs, im.WindowFlags_NoSavedSettings, im.WindowFlags_AlwaysAutoResize)
  -- AlwaysAutoResize overrides the size; width stays stable because every row below is fixed-width
  im.Begin("##mwfHud", nil, flags)
  local dl = im.GetWindowDrawList()

  if S.session then
    local now = os.clock()
    -- on foot: stamina
    if S.foot and S.foot.active then
      local n = math.floor(S.foot.stamina / 10 + 0.5)
      local txt = string.format("ON FOOT   STAMINA  %s%s", string.rep("|", n), string.rep(".", 10 - n))
      if S.foot.exhausted then txt = txt .. "   (out of breath)" end
      if S.foot.arrest > 0.1 then txt = txt .. "   SURROUNDED!" end
      im.PushStyleColor2(im.Col_Text, UI.col((S.foot.exhausted or S.foot.arrest > 0.1) and UI.BAD or UI.GOOD, 1))
      im.Text(txt)
      im.PopStyleColor()
    end
    -- live drift counter (Forza style): only while a drift is running
    local dr = S.session.style and S.session.style.drift
    if dr and dr.state ~= 'idle' and dr.pts * dr.combo >= 20 then
      local txt = string.format("DRIFT  %d  x%.1f", math.floor(dr.pts * dr.combo), dr.combo)
      if dr.state == 'grace' then txt = txt .. "   (hold it!)" end
      if (dr.circleF or 1) < 0.9 then txt = txt .. "   (going in circles...)" end
      im.PushStyleColor2(im.Col_Text, UI.col(dr.state == 'grace' and UI.MUTED or UI.ACCENT, 1))
      im.Text(txt)
      im.PopStyleColor()
    end
    -- bounty feed: what is earning you money, newest first
    for i, e in ipairs(S.feed) do
      local age = now - e.t
      if age < CFG.FEED_LIFE then
        local a = math.min(1, (CFG.FEED_LIFE - age) / 2)
        local txt = string.format("%s$%d  %s", e.neg and "-" or "+", math.floor(math.abs(e.amount) + 0.5), e.text)
        if e.mult < 0.99 then txt = txt .. string.format("   (repeat x%.2f)", e.mult) end
        im.PushStyleColor2(im.Col_Text, UI.col(e.neg and UI.BAD or (e.mult < 0.99 and UI.PURPLE or UI.GOOD), a))
        im.Text(txt)
        im.PopStyleColor()
      end
    end
    im.PushStyleColor2(im.Col_Text, UI.col(UI.MUTED, 0.95))
    im.Text(string.format("Pursuit time  +$%d/s    (%d earned so far)", MWF.util.pursuitRate(S.session.heat), math.floor(S.session.timeBounty)))
    if S.rls.active then
      im.Text(string.format("RLS: escaping pays %d%% = about $%d   (Most Wanted Criminal level %d)", math.floor(MWF.rls.payoutPct() * 100 + 0.5), MWF.rls.payoutFor(S.session.bounty), MWF.rls.level()))
    end
    im.PopStyleColor()
    im.Separator()

    local x0, y0 = im.GetCursorScreenPos().x, im.GetCursorScreenPos().y
    local rowH = 64

    -- LEFT: heat + bounty
    im.SetWindowFontScale(1.6)
    im.PushStyleColor2(im.Col_Text, UI.col(UI.SALMON))
    im.Text(string.format("HEAT %d", S.session.heat))
    im.PopStyleColor()
    im.SetWindowFontScale(1.1)
    im.Text(string.format("%s  $%s", "BOUNTY", tostring(math.floor(S.session.bounty - (S.session.spent or 0)))))
    im.SetWindowFontScale(1.0)
    local nextLvl = MWF.util.heatThreshold(S.session.heat + 1)
    local prev = MWF.util.heatThreshold(S.session.heat)
    UI.drawBar(dl, x0, y0 + rowH - 8, 220, 8, nextLvl and (S.session.bounty - prev) / (nextLvl - prev) or 1, UI.SALMON)

    -- MIDDLE: reset bar, three slots
    local mx = x0 + 250
    UI.textAt(mx, y0, "RESET BAR", UI.MUTED)
    for i = 1, CFG.SLOTS do
      local fill = math.max(0, math.min(1, (S.bar - (i - 1) * CFG.SLOT_COST) / CFG.SLOT_COST))
      UI.drawBar(dl, mx + (i - 1) * 78, y0 + 22, 72, 16, fill, fill >= 0.999 and UI.ACCENT or UI.BLUE)
    end
    if S.resetsLocked then
      UI.textAt(mx, y0 + 44, MWF.util.canSpend() and string.format("RESET NEEDS $%d  (road teleport free)", MWF.util.resetCost()) or "RESET LOCKED  (road teleport free)", UI.BAD)
    else
      UI.textAt(mx, y0 + 44, (MWF.util.resetCost() > 0 and string.format("RESET READY  (R, 1 slot, $%d)", MWF.util.resetCost()) or ((os.clock() < S.regenSlowUntil) and "RESET READY  (R, free, slow refill)" or "RESET READY  (R, free)")), UI.GOOD)
    end

    -- RIGHT: cops
    local rx = x0 + 520
    local pd = MWF.util.getPursuit(be:getPlayerVehicleID(0))
    local lines = {
      {string.format("COPS ON YOU   %d", S.stats.copsPresent), UI.SALMON},
      {string.format("COPS WRECKED  %d", S.stats.wrecked), UI.PURPLE},
      {string.format("RAMMED        %d", S.stats.hitPolice), UI.MUTED},
    }
    for i, l in ipairs(lines) do
      UI.textAt(rx, y0 + (i - 1) * 18, l[1], l[2])
    end
    if pd and pd.timers then
      UI.drawBar(dl, rx, y0 + 58 - 4, 100, 6, pd.timers.evadeValue or 0, UI.GOOD)
      UI.drawBar(dl, rx + 108, y0 + 58 - 4, 100, 6, pd.timers.arrestValue or 0, UI.BAD)
    end
    im.SetCursorScreenPos(im.ImVec2(x0, y0 + rowH + 4))
    im.Dummy(im.ImVec2(W - 20, 1))
  else
    im.SetWindowFontScale(1.6)
    local label = S.lastEnd.kind == 'escaped' and "ESCAPED" or (S.lastEnd.kind == 'busted' and "BUSTED" or "CHASE OVER")
    im.Text(label)
    im.SetWindowFontScale(1.0)
    im.Text(string.format("Bounty  $%d   Cops wrecked  %d", math.floor(S.lastEnd.bounty), S.lastEnd.wrecked or 0))
  end

  S.hudH = im.GetWindowSize().y
  im.End()
  im.PopStyleVar(2)
  im.PopStyleColor(3)
end

-- ammo window: sits right above the main HUD while your car has a Universal Weapons gun during a chase
local function drawAmmo()
  if not S.session or not S.hudVisible[0] then return end
  local _, pid = MWF.util.getPlayerVeh()
  local a = pid and S.ammoByVeh[pid]
  if not a or not next(a) then return end
  local cur, max = 0, 0
  for _, e in pairs(a) do cur = cur + e.rounds; max = max + e.max end
  if max <= 0 then return end

  local vp = im.GetMainViewport()
  im.SetNextWindowPos(im.ImVec2(vp.Pos.x + vp.Size.x * 0.5, vp.Pos.y + vp.Size.y - 24 - S.hudH - 10), im.Cond_Always, im.ImVec2(0.5, 1))
  im.PushStyleColor2(im.Col_WindowBg, im.ImVec4(20/255, 22/255, 30/255, 0.93))
  im.PushStyleColor2(im.Col_Border, im.ImVec4(0, 191/255, 1, 0.25))
  im.PushStyleColor2(im.Col_Text, im.ImVec4(UI.TEXT[1], UI.TEXT[2], UI.TEXT[3], 1))
  im.PushStyleVar1(im.StyleVar_WindowRounding, 10)
  im.PushStyleVar1(im.StyleVar_WindowBorderSize, 1)
  local flags = bit.bor(im.WindowFlags_NoTitleBar, im.WindowFlags_NoResize, im.WindowFlags_NoMove, im.WindowFlags_NoScrollbar,
    im.WindowFlags_NoCollapse, im.WindowFlags_NoInputs, im.WindowFlags_NoSavedSettings, im.WindowFlags_AlwaysAutoResize)
  im.Begin("##mwfAmmo", nil, flags)
  local dl = im.GetWindowDrawList()
  im.PushStyleColor2(im.Col_Text, UI.col(UI.MUTED))
  im.Text("AMMO")
  im.PopStyleColor()
  im.SameLine()
  im.SetWindowFontScale(1.4)
  local empty = cur < 1
  im.PushStyleColor2(im.Col_Text, UI.col(empty and UI.BAD or UI.ACCENT))
  im.Text(string.format("%d / %d", math.floor(cur), math.floor(max)))
  im.PopStyleColor()
  im.SetWindowFontScale(1.0)
  local p = im.GetCursorScreenPos()
  UI.drawBar(dl, p.x, p.y + 2, 190, 6, cur / max, empty and UI.BAD or UI.ACCENT)
  im.Dummy(im.ImVec2(190, 10))
  im.End()
  im.PopStyleVar(2)
  im.PopStyleColor(3)
end

-- The heat, for the minimap app (ui/modules/apps/MwfMinimap) and for the Most Wanted Mission minimap (compat/mwm.lua):
-- the heat level, how far through it the bounty is (0 to 1), whether the police can see you, and whether you are slipping away.
local function heatData()
  local s = S.session
  if not s then return {active = false} end
  local pd = MWF.util.getPursuit(be:getPlayerVehicleID(0))
  local prev, nxt = MWF.util.heatThreshold(s.heat) or 0, MWF.util.heatThreshold(s.heat + 1)
  local progress = 1
  if nxt and nxt > prev then progress = math.max(0, math.min(1, (s.bounty - prev) / (nxt - prev))) end
  local visible = (pd and pd.mode and pd.mode > 0 and pd.policeVisible) and true or false
  local t = pd and pd.timers or {}
  local cooling = (pd and pd.mode and pd.mode > 0 and not visible and (t.evadeValue or 0) > (t.arrestValue or 0)) and true or false
  return {active = true, heat = s.heat, maxHeat = CFG.MAX_HEAT, progress = progress, pursued = visible, cooling = cooling,
    mode = pd and pd.mode or 0, evadeValue = t.evadeValue or 0, arrestValue = t.arrestValue or 0, bounty = math.floor(s.bounty)}
end
function M.getHeatHud() return heatData() end

MWF.hud = {drawAmmo = drawAmmo, drawHud = drawHud, heatData = heatData}

return M
