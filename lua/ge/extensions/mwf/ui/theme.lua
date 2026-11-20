-- Colour palette and small ImGui drawing helpers shared by every window.
local MWF = require('/lua/ge/extensions/mwf/core/registry')
local im = ui_imgui


-- ===== HUD (bottom of screen, Most Wanted style) =====
-- palette taken from the site CSS: #00bfff accent, #e0e0e0 text, #888 muted, #00e676 ok, #ff5252 bad, #9b30ff purple, #3b82f6 blue
local ACCENT = {0.0, 0.749, 1.0}
local TEXT   = {0.878, 0.878, 0.878}
local MUTED  = {0.533, 0.533, 0.533}
local GOOD   = {0.0, 0.902, 0.463}
local BAD    = {1.0, 0.322, 0.322}
local PURPLE = {0.608, 0.188, 1.0}
local BLUE   = {0.231, 0.510, 0.965}
local SALMON = ACCENT
local function col(c, a) return im.ImVec4(c[1], c[2], c[3], a or 1) end

local function drawBar(dl, x, y, w, h, fill, c)
  local u32 = function(cc, a) return im.GetColorU322(im.ImVec4(cc[1], cc[2], cc[3], a)) end
  im.ImDrawList_AddRectFilled(dl, im.ImVec2(x, y), im.ImVec2(x + w, y + h), u32({0.04, 0.04, 0.04}, 0.85), 3)
  if fill > 0 then
    im.ImDrawList_AddRectFilled(dl, im.ImVec2(x, y), im.ImVec2(x + w * math.min(1, fill), y + h), u32(c, 0.95), 3)
  end
  im.ImDrawList_AddRect(dl, im.ImVec2(x, y), im.ImVec2(x + w, y + h), u32(ACCENT, 0.3), 3)
end

local function textAt(x, y, str, c)
  im.SetCursorScreenPos(im.ImVec2(x, y))
  im.TextColored(col(c), str)
end

return {ACCENT = ACCENT, TEXT = TEXT, MUTED = MUTED, GOOD = GOOD, BAD = BAD, PURPLE = PURPLE, BLUE = BLUE, SALMON = SALMON, col = col, drawBar = drawBar, textAt = textAt}
