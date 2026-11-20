-- Optional hiding of civilian traffic during chases.
local MWF = require('/lua/ge/extensions/mwf/core/registry')
local S = MWF.S

local M = {}

local function hideCivilianSweep()
  local traffic = gameplay_traffic and gameplay_traffic.getTrafficData and gameplay_traffic.getTrafficData()
  if not traffic then return end
  local _, pid = MWF.util.getPlayerVeh()
  for id, tv in pairs(traffic) do
    if id ~= pid and not S.hiddenCivs[id] and tv.role and tv.role.name ~= 'police' then
      local o = getObjectByID(id)
      if o and o:getActive() then
        pcall(function()
          tv.enableRespawn = false
          o:setActive(0)
        end)
        S.hiddenCivs[id] = true
      end
    end
  end
end

local function queueCivilianRestore()
  for id in pairs(S.hiddenCivs) do table.insert(S.restoreQueue, id) end
  S.hiddenCivs = {}
end

local function tickCivilians(dtReal)
  if S.session and S.options.hideCivilians then
    S.civTimer = S.civTimer + dtReal
    if S.civTimer > 3 then S.civTimer = 0 hideCivilianSweep() end
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
