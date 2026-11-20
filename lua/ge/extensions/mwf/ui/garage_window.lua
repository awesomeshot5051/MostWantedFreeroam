-- The garage windows (hub, vehicles, parts).
local MWF = require('/lua/ge/extensions/mwf/core/registry')
local S = MWF.S
local CFG = require('/lua/ge/extensions/mwf/data/config')
local UI = require('/lua/ge/extensions/mwf/ui/theme')
local im = ui_imgui

local M = {}

-- The garage UI (garages only; the chase is paused while it is open). Three screens so nobody is overwhelmed:
--   hub   : two big buttons, Vehicles and Parts
--   cars  : only the cars you can afford right now
--   parts : explanation + the priced parts configurator
local function pushGarageStyle()
  im.PushStyleColor2(im.Col_WindowBg, im.ImVec4(20/255, 22/255, 30/255, 0.96))
  im.PushStyleColor2(im.Col_Border, im.ImVec4(0, 191/255, 1, 0.35))
  im.PushStyleColor2(im.Col_Text, im.ImVec4(UI.TEXT[1], UI.TEXT[2], UI.TEXT[3], 1))
  im.PushStyleColor2(im.Col_TitleBg, im.ImVec4(10/255, 12/255, 18/255, 1))
  im.PushStyleColor2(im.Col_TitleBgActive, im.ImVec4(0, 90/255, 130/255, 1))
  im.PushStyleColor2(im.Col_Button, im.ImVec4(0, 120/255, 170/255, 0.9))
  im.PushStyleColor2(im.Col_ButtonHovered, im.ImVec4(0, 191/255, 1, 0.9))
  im.PushStyleColor2(im.Col_ButtonActive, im.ImVec4(0, 150/255, 210/255, 1))
  im.PushStyleColor2(im.Col_FrameBg, im.ImVec4(30/255, 33/255, 44/255, 1))
  im.PushStyleVar1(im.StyleVar_WindowRounding, 12)
  im.PushStyleVar1(im.StyleVar_WindowBorderSize, 1)
end
local function popGarageStyle()
  im.PopStyleVar(2)
  im.PopStyleColor(9)
end

local function garageHeader(sub)
  im.SetWindowFontScale(1.3)
  im.TextColored(UI.col(UI.ACCENT), string.format("WALLET  $%d", math.floor(MWF.garage.wallet())))
  im.SetWindowFontScale(1.0)
  im.TextColored(UI.col(UI.PURPLE), "CHASE PAUSED")
  im.SameLine()
  im.TextColored(UI.col(UI.MUTED), sub or "")
  if S.garage.note ~= "" then im.TextColored(UI.col(UI.BAD), S.garage.note) end
  im.Separator()
end

local function drawGarageHub()
  im.SetNextWindowSize(im.ImVec2(380, 0), im.Cond_Always)
  if im.Begin("Garage##mwfGarageHub", S.garage.show, im.WindowFlags_NoResize) then
    garageHeader("while this window is open")
    im.TextColored(UI.col(UI.MUTED), "Pick one. Heat follows what you EARNED, so spending never cools you down.")
    im.Spacing()
    if im.Button("Vehicles", im.ImVec2(-1, 48)) then S.garage.mode = "cars" S.garage.note = "" end
    im.Spacing()
    if im.Button("Parts", im.ImVec2(-1, 48)) then S.garage.mode = "parts" S.garage.note = "" end
    im.Spacing()
    if im.Button("Leave garage (resume chase)", im.ImVec2(-1, 0)) then MWF.garage.closeGarage() end
  end
  im.End()
end

local function drawGarageCars()
  local vp = im.GetMainViewport()
  im.SetNextWindowPos(im.ImVec2(vp.Pos.x + 40, vp.Pos.y + 110), im.Cond_FirstUseEver)
  im.SetNextWindowSize(im.ImVec2(600, 520), im.Cond_FirstUseEver)
  if im.Begin("Garage - Vehicles##mwfGarageCars", S.garage.show) then
    local w = MWF.garage.wallet()
    garageHeader(string.format("prices are %d%% of the real value", math.floor(S.options.priceFactor * 100 + 0.5)))
    if im.Button("< Back") then S.garage.mode = "hub" end
    im.SameLine()
    im.InputText("Search", S.garage.search, 128)
    local q = (require('ffi').string(S.garage.search) or ""):lower()
    im.Separator()
    local catalog = MWF.garage.buildCatalog()
    local shown, hidden = 0, 0
    for i, c in ipairs(catalog) do
      local price = MWF.garage.carPrice(c.value)
      if price > w then
        hidden = hidden + 1
      elseif q == "" or c.lower:find(q, 1, true) then
        if shown < CFG.GARAGE_ROWS then
          shown = shown + 1
          im.Text(c.label)
          im.SameLine(400)
          im.TextColored(UI.col(UI.GOOD), string.format("$%d", price))
          im.SameLine(490)
          if im.Button("Buy##car" .. i) then
            S.garage.note = ""
            local ok, res = pcall(core_vehicles.replaceVehicle, c.model, {config = c.pc}, MWF.util.getPlayerVeh())
            if not ok then S.garage.note = "Could not swap: " .. tostring(res):sub(1, 80) end
          end
        end
      end
    end
    if shown >= CFG.GARAGE_ROWS then im.TextColored(UI.col(UI.MUTED), "Showing the first " .. CFG.GARAGE_ROWS .. " matches. Use search to narrow it down.") end
    if hidden > 0 then im.TextColored(UI.col(UI.MUTED), string.format("%d more cars need a bigger bounty.", hidden)) end
  end
  im.End()
end

local function drawGarageParts()
  im.SetNextWindowSize(im.ImVec2(460, 0), im.Cond_Always)
  if im.Begin("Garage - Parts##mwfGarageParts", S.garage.show, im.WindowFlags_NoResize) then
    garageHeader("")
    if im.Button("< Back") then S.garage.mode = "hub" end
    im.Spacing()
    im.TextWrapped("Every part you change costs its value x the price factor, and a change you cannot afford is refused. Parts that stay the same are free.")
    im.Spacing()
    if im.Button("Open parts configurator", im.ImVec2(-1, 40)) then
      pcall(function() core_vehicles.openPartsSelectorUI() end)
    end
  end
  im.End()
end

local function drawGarage()
  if not S.session or not S.inGarage or not S.options.pitCosts or not S.garage.mode then return end
  pushGarageStyle()
  if S.garage.mode == "cars" then drawGarageCars()
  elseif S.garage.mode == "parts" then drawGarageParts()
  else drawGarageHub() end
  popGarageStyle()
  -- the window's own close button
  if not S.garage.show[0] then MWF.garage.closeGarage() end
end

MWF.garageui = {drawGarage = drawGarage}

return M
