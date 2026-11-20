-- Extra police units and roadblock props per heat level: spawning, reinforcements, clean-up.
local MWF = require('/lua/ge/extensions/mwf/core/registry')
local S = MWF.S
local CFG = require('/lua/ge/extensions/mwf/data/config')
local UNITS = require('/lua/ge/extensions/mwf/data/units')

local M = {}

S.esc = {queue = {}, groups = {}, queued = {}, props = {}, propsQueued = {}, cleanup = {}, timer = 0, info = {}, repTimer = 0, specials = {}}

local function escReset()
  -- units from a chase that just ended may still be waiting to be removed: keep that list, or they are orphaned and join the next chase
  local pendingCleanup = S.esc and S.esc.cleanup or {}
  S.esc = {queue = {}, groups = {}, queued = {}, props = {}, propsQueued = {}, cleanup = pendingCleanup, timer = 0, info = {}, repTimer = 0, specials = {}}
end

local function extraCount()
  local n = 0
  for _, ids in pairs(S.esc.groups) do n = n + #ids end
  return n
end

local function activeIdSet()
  local t = {}
  pcall(function() for vid in activeVehiclesIterator() do t[vid] = true end end)
  return t
end

local function spawnVeh(model, config)
  local before = activeIdSet()
  S.bypassGate = true
  local ok, veh = pcall(core_vehicles.spawnNewVehicle, model, {config = config, autoEnterVehicle = false})
  S.bypassGate = false
  if ok and veh and veh.getID then return veh end
  -- the spawn call did not hand back a vehicle (seen with the spike strip), but it may still have created one: adopt it
  -- so it gets tracked and cleaned up instead of lying around
  local found
  pcall(function()
    for vid in activeVehiclesIterator() do
      if not before[vid] then
        local o = getObjectByID(vid)
        if o and o.jbeam == model then found = o end
      end
    end
  end)
  if found then log('I', 'mwf', string.format('adopted spawned %s (id %d)', model, found:getID())) end
  return found
end

-- picks the car to really spawn: the entry itself, or its alternative when the mod that provides it is not installed
local function resolveCar(car)
  local seen = 0
  while car and car.mod and seen < 3 do
    seen = seen + 1
    local ok, exists = pcall(function() return FS:fileExists("/" .. car[2]) end)
    if ok and exists then return car end
    car = car.alt or UNITS.FALLBACK_CAR
  end
  return car or UNITS.FALLBACK_CAR
end

local function spawnPolice(heat, car, special)
  if special then
    local ok, exists = pcall(function() return FS:fileExists("/" .. car[2]) end)
    if not (ok and exists) then log('I', 'mwf', string.format('%s not installed, skipping its heat %d appearance', car.label, heat)) return end
  else
    car = resolveCar(car)
  end
  local veh = spawnVeh(car[1], car[2])
  if not veh and car ~= UNITS.FALLBACK_CAR and not special then
    log('W', 'mwf', string.format('could not spawn %s %s, using a fallback unit', tostring(car[1]), tostring(car[2])))
    car = UNITS.FALLBACK_CAR
    veh = spawnVeh(car[1], car[2])
  end
  if not veh then return end
  local id = veh:getID()
  pcall(function()
    gameplay_traffic.insertTraffic(id)
    local tv = gameplay_traffic.getTrafficData()[id]
    if tv then
      tv:setRole('police')
      tv.enableRespawn = true
      tv.useRandomPaint = false
    end
    gameplay_traffic.forceTeleport(id) -- puts it on a road out of sight, then vanilla police AI takes over
    local _, pid = MWF.util.getPlayerVeh()
    local pd = pid and MWF.util.getPursuit(pid)
    if pd and pd.mode and pd.mode > 0 then gameplay_police.setPursuitMode(pd.mode, pid, {id}) end
  end)
  if special then
    table.insert(S.esc.specials, id)
    MWF.achievements.max('knightsMet', #S.esc.specials)
  else
    S.esc.groups[heat] = S.esc.groups[heat] or {}
    table.insert(S.esc.groups[heat], id)
  end
  S.esc.info[id] = {heat = heat, mult = car.mult or 1, label = car.label or "Police car"}
  log('I', 'mwf', string.format('Heat %d unit spawned: %s %s (id %d)', heat, tostring(car[1]), tostring(car[2]), id))
end

local function spawnProp(def)
  local veh = spawnVeh(def.model, def.config)
  if not veh then log('W', 'mwf', 'could not spawn prop ' .. def.name) return end
  local id = veh:getID()
  local heat = S.session and S.session.heat or 1
  pcall(function()
    veh:setActive(0) -- parked until vanilla builds a roadblock with it
    if heat >= def.minHeat and heat <= def.maxHeat then gameplay_police.insertProp(id) end
  end)
  S.esc.props[id] = def
  log('I', 'mwf', string.format('Roadblock prop spawned: %s (id %d)', def.name, id))
end

-- props are only usable while the heat is inside their range (sawhorses at 3, spike strips at 4-6)
local function updatePropRanges(heat)
  for id, def in pairs(S.esc.props) do
    pcall(function()
      if heat >= def.minHeat and heat <= def.maxHeat then gameplay_police.insertProp(id) else gameplay_police.removeProp(id) end
    end)
  end
end

local function escalateTo(heat)
  for h = 2, math.min(heat, CFG.MAX_HEAT) do
    if not S.esc.queued[h] and UNITS.HEAT_GROUPS[h] then
      S.esc.queued[h] = true
      local g = UNITS.HEAT_GROUPS[h]
      S.esc.slot = S.esc.slot or {}
      for i = 1, math.max(1, math.ceil(g.count * S.options.waveScale)) do table.insert(S.esc.queue, {kind = 'police', heat = h, car = g.cars[(i - 1) % #g.cars + 1]}) end
      S.esc.slot[h] = 0
    end
  end
  for h = 2, math.min(heat, CFG.MAX_HEAT) do
    local sp = UNITS.HEAT_SPECIALS[h]
    if sp and not S.esc.queued['special' .. h] then
      S.esc.queued['special' .. h] = true
      table.insert(S.esc.queue, {kind = 'police', heat = h, car = sp, special = true})
    end
  end
  for _, def in ipairs(UNITS.PROP_DEFS) do
    if heat >= def.minHeat and not S.esc.propsQueued[def.name] then
      S.esc.propsQueued[def.name] = true
      for _ = 1, math.max(1, math.ceil(def.count * S.options.waveScale)) do table.insert(S.esc.queue, {kind = 'prop', def = def}) end
    end
  end
  -- retire groups that fell out of the window
  for h, ids in pairs(S.esc.groups) do
    if h < heat - UNITS.GROUP_WINDOW + 1 then
      for _, id in ipairs(ids) do table.insert(S.esc.cleanup, {id = id, t = os.clock()}) end
      S.esc.groups[h] = nil
    end
  end
  updatePropRanges(heat)
end

-- everything we spawned goes away once the chase is over (removed once 120 m away, or after 30 s at the latest)
local function retireAll()
  local n = 0
  for _, ids in pairs(S.esc.groups) do n = n + #ids end
  for _ in pairs(S.esc.props) do n = n + 1 end
  if n > 0 then log('I', 'mwf', string.format('Chase over: removing %d spawned units/props (once 120 m away, or after 30 s at the latest)', n)) end
  for h, ids in pairs(S.esc.groups) do
    for _, id in ipairs(ids) do table.insert(S.esc.cleanup, {id = id, t = os.clock()}) end
  end
  for id in pairs(S.esc.props) do table.insert(S.esc.cleanup, {id = id, t = os.clock(), prop = true}) end
  for _, id in ipairs(S.esc.specials) do table.insert(S.esc.cleanup, {id = id, t = os.clock()}) end
  S.esc.specials = {}
  S.esc.groups, S.esc.props, S.esc.queue, S.esc.queued, S.esc.propsQueued = {}, {}, {}, {}, {}
end

local function deleteVeh(item)
  pcall(function()
    if item.prop then gameplay_police.removeProp(item.id) end
    if gameplay_traffic.getTrafficData()[item.id] then gameplay_traffic.removeTraffic(item.id) end
    local o = getObjectByID(item.id)
    if o then o:delete() end
  end)
end

local function tickEscalation(dtReal)
  -- cleanup of retired vehicles
  if #S.esc.cleanup > 0 then
    local pveh = MWF.util.getPlayerVeh()
    local ppos = pveh and pveh:getPosition()
    for i = #S.esc.cleanup, 1, -1 do
      local item = S.esc.cleanup[i]
      local o = getObjectByID(item.id)
      if not o then
        table.remove(S.esc.cleanup, i)
      elseif item.prop or not ppos or os.clock() - item.t > 30 or (o:getPosition() - ppos):length() > 120 then
        deleteVeh(item)
        table.remove(S.esc.cleanup, i)
      end
    end
  end
  if S.garagePaused then return end -- nothing spawns while the garage has the chase frozen
  -- reinforcements: wrecked units of a heat group still in play are retired and replaced, so the chase keeps its pressure
  -- (this is also what keeps the special semis showing up at the top heats)
  if S.session and #S.esc.queue == 0 then
    S.esc.repTimer = S.esc.repTimer + dtReal
    if S.esc.repTimer >= (S.session.heat >= 10 and 3 or (S.session.heat >= 7 and 4 or UNITS.REPLENISH_EVERY)) then
      S.esc.repTimer = 0
      for h, ids in pairs(S.esc.groups) do
        local g = UNITS.HEAT_GROUPS[h]
        if g then
          local alive, want = {}, math.max(1, math.ceil(g.count * S.options.waveScale))
          for _, id in ipairs(ids) do
            if S.session.wrecked[id] or not getObjectByID(id) then
              table.insert(S.esc.cleanup, {id = id, t = os.clock()})
            else
              table.insert(alive, id)
            end
          end
          S.esc.groups[h] = alive
          S.esc.slot = S.esc.slot or {}
          if #alive < want and extraCount() < UNITS.MAX_EXTRA then
            S.esc.slot[h] = (S.esc.slot[h] or 0) + 1
            table.insert(S.esc.queue, {kind = 'police', heat = h, car = g.cars[(S.esc.slot[h] + g.count - 1) % #g.cars + 1]})
          end
        end
      end
    end
  end
  -- staggered spawning
  if S.session and #S.esc.queue > 0 then
    S.esc.timer = S.esc.timer + dtReal
    -- smooth mode: if the frame rate is already struggling, hold the next spawn back (but never longer than 8 s)
    local struggling = S.options.smooth and dtReal > 0.045 and S.esc.timer < 8
    if S.esc.timer >= S.options.spawnInterval and not struggling then
      S.esc.timer = 0
      local job = table.remove(S.esc.queue, 1)
      if job.kind == 'police' then
        if job.special or extraCount() < UNITS.MAX_EXTRA then spawnPolice(job.heat, job.car, job.special) end
      else
        spawnProp(job.def)
      end
    end
  end
end

MWF.escalation = {deleteVeh = deleteVeh, escReset = escReset, escalateTo = escalateTo, retireAll = retireAll, tickEscalation = tickEscalation}

return M
