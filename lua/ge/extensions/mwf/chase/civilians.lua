-- Optional hiding of civilian traffic during chases.
local MWF = require('/lua/ge/extensions/mwf/core/registry')
local S = MWF.S

local M = {}

local THIN_FULL = 16   -- police on the road at which no civilians are left (traffic thins out linearly up to this)
local STEP = 2         -- civilians hidden / returned per sweep, so the change is gradual and never hitches

-- Keeps the number of visible civilians in line with the number of police: more police = fewer civilians.
-- "Hide civilian traffic" (option) forces the target to 0.
local function hideCivilianSweep()
  local traffic = gameplay_traffic and gameplay_traffic.getTrafficData and gameplay_traffic.getTrafficData()
  if not traffic then return end
  local pveh, pid = MWF.util.getPlayerVeh()
  local ppos = pveh and pveh:getPosition()
  local police, visible = 0, {}
  for id, tv in pairs(traffic) do
    if id ~= pid and tv.role then
      local o = getObjectByID(id)
      if tv.role.name == 'police' then
        if o and o:getActive() then police = police + 1 end
      elseif o and o:getActive() and not S.hiddenCivs[id] then
        table.insert(visible, {id = id, o = o, d = ppos and (o:getPosition() - ppos):length() or 0})
      end
    end
  end
  local hidden = 0
  for id in pairs(S.hiddenCivs) do
    if getObjectByID(id) then hidden = hidden + 1 else S.hiddenCivs[id] = nil end
  end
  local total = #visible + hidden
  local allowed = total
  if S.options.hideCivilians then
    allowed = 0
  elseif S.options.thinTraffic then
    allowed = math.floor(total * (1 - math.min(1, police / THIN_FULL)) + 0.5)
  end
  if #visible > allowed then
    table.sort(visible, function(x, y) return x.d > y.d end) -- the farthest ones go first
    local fullHide = S.options.hideCivilians
    for i = 1, math.min(#visible - allowed, fullHide and #visible or STEP) do
      local c = visible[i]
      pcall(function()
        local tv = traffic[c.id]
        if tv then tv.enableRespawn = false end
        c.o:setActive(0)
      end)
      S.hiddenCivs[c.id] = true
    end
  elseif #visible < allowed and hidden > 0 then
    local n = 0
    for id in pairs(S.hiddenCivs) do
      if n >= STEP or #visible + n >= allowed then break end
      S.hiddenCivs[id] = nil
      table.insert(S.restoreQueue, id)
      n = n + 1
    end
  end
end

local function queueCivilianRestore()
  for id in pairs(S.hiddenCivs) do table.insert(S.restoreQueue, id) end
  S.hiddenCivs = {}
end

local function tickCivilians(dtReal)
  if S.session and (S.options.hideCivilians or S.options.thinTraffic) then
    S.civTimer = S.civTimer + dtReal
    if S.civTimer > 2 then S.civTimer = 0 hideCivilianSweep() end
  elseif next(S.hiddenCivs) then
    queueCivilianRestore() -- chase over, or the option was switched off mid-chase
  end
  -- put civilians back a couple per frame so the return doesn't hitch
  for _ = 1, 2 do
    local id = table.remove(S.restoreQueue)
    if not id then break end
    pcall(function()
      local o = getObjectByID(id)
      if o then
        o:setActive(1)
        local tv = gameplay_traffic.getTrafficData()[id]
        if tv then tv.enableRespawn = true end
        gameplay_traffic.forceTeleport(id)
      end
    end)
  end
end

MWF.civilians = {tickCivilians = tickCivilians}

return M
