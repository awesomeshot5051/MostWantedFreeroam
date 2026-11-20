-- Pit stops: gas stations and garages from the level facilities (plus the POI fallback), repair and pursuit hand-over.
local MWF = require('/lua/ge/extensions/mwf/core/registry')
local S = MWF.S

local M = {}
local GAS_COOLDOWN       = 5
local GAS_RADIUS         = 10   -- metres, same as Most Wanted
local GARAGE_RADIUS      = 6    -- metres around the garage door(s); garages are laid out differently from gas stations

-- Car changed at a gas station: carry the chase over to the new car instead of ending it
local function scheduleTransfer(oldId, newId)
  S.transfer = {old = oldId, new = newId, mode = S.session and S.session.lastMode or 1, t = 0, done = false}
end

local function tickTransfer(dtReal)
  if not S.transfer then return end
  S.transfer.t = S.transfer.t + dtReal
  if not S.transfer.done and S.transfer.t >= 0.3 then
    S.transfer.done = true
    pcall(function()
      local traffic = gameplay_traffic.getTrafficData()
      if not traffic[S.transfer.new] then gameplay_traffic.insertTraffic(S.transfer.new, true) end
      traffic = gameplay_traffic.getTrafficData()
      local oldT, newT = traffic[S.transfer.old], traffic[S.transfer.new]
      if oldT and newT and S.transfer.old ~= S.transfer.new then newT.pursuit = deepcopy(oldT.pursuit) end
      if S.transfer.old ~= S.transfer.new then gameplay_police.setPursuitMode(0, S.transfer.old) end
      gameplay_police.setPursuitMode(math.max(1, S.transfer.mode), S.transfer.new)
    end)
    local pd = MWF.util.getPursuit(S.transfer.new)
    if S.session and pd then
      S.session.lastHits = pd.hitCount or 0
      S.session.lastOffCount = pd.offensesCount or 0
    end
    MWF.lockdown.setRecoveryIntercept(true)
    S.riskPauseUntil = os.clock() + 1.5
    log('I', 'mwf', 'Chase carried over to the new vehicle')
  elseif S.transfer.done and S.transfer.t >= 1.2 then
    S.transfer = nil
  end
end

local function zoneBox(facility)
  local zones = freeroam_facilities.getZonesForFacility(facility)
  if not zones then return nil end
  local x0, x1, y0, y1, z0, z1 = math.huge, -math.huge, math.huge, -math.huge, math.huge, -math.huge
  for _, zone in ipairs(zones) do
    for _, v in ipairs(zone.vertices or {}) do
      x0, x1 = math.min(x0, v.pos.x), math.max(x1, v.pos.x)
      y0, y1 = math.min(y0, v.pos.y), math.max(y1, v.pos.y)
      z0, z1 = math.min(z0, v.pos.z), math.max(z1, v.pos.z)
    end
  end
  if x0 == math.huge then return nil end
  return {x0 = x0, x1 = x1, y0 = y0, y1 = y1, z0 = z0, z1 = z1}
end

-- Fallback for maps with no gas stations and/or no garages in their facility data (e.g. Caldera Bay): turn points of interest
-- (the game's raw POI list: spawn points and the like, each with a world position) into pit stops. Only the MISSING kind is
-- generated; real facilities are never replaced. With both missing they alternate garage / gas station; with one missing,
-- every other POI becomes that kind. POIs closer than FALLBACK_SPACING to another stop are skipped.
local FB = {radius = 12, spacing = 150}
FB.skip = {gasStation = true, garage = true, dealership = true, computer = true, inspectVehicle = true, testDriveEnd = true,
  deliveryTargetArea = true, deliveryVehicle = true, tutorialLesson = true, firstDriveDestination = true, firstDriveLearningLesson = true}
function FB.add(levelId)
  local haveGas, haveGarage = false, false
  for _, g in ipairs(S.gasStations) do
    if g.kind == "garage" then haveGarage = true else haveGas = true end
  end
  if haveGas and haveGarage then return end
  local ok, list = pcall(function() return gameplay_rawPois.getRawPoiListByLevel(levelId) end)
  if not ok or type(list) ~= 'table' then
    log('W', 'mwf', 'fallback pit stops: POI list unavailable (' .. tostring(list) .. ')')
    return
  end
  local pois = {}
  for _, e in ipairs(list) do
    local mk = e.markerInfo and e.markerInfo.bigmapMarker
    local t = e.data and e.data.type
    local p = mk and mk.pos
    if p and p.x == p.x and not FB.skip[t] then
      table.insert(pois, {id = tostring(e.id), name = type(mk.name) == 'string' and mk.name or tostring(e.id), pos = vec3(p.x, p.y, p.z)})
    end
  end
  table.sort(pois, function(a, b) return a.id < b.id end) -- stable order between runs
  local kept = {}
  for _, poi in ipairs(pois) do
    local tooClose = false
    for _, g in ipairs(S.gasStations) do if (poi.pos - g.pos):length() < FB.spacing then tooClose = true break end end
    if not tooClose then
      for _, k in ipairs(kept) do if (poi.pos - k.pos):length() < FB.spacing then tooClose = true break end end
    end
    if not tooClose then table.insert(kept, poi) end
  end
  local added = {garage = 0, ["gas station"] = 0}
  for i, poi in ipairs(kept) do
    local kind
    if not haveGas and not haveGarage then
      kind = (i % 2 == 1) and "garage" or "gas station"
    elseif i % 2 == 1 then
      kind = haveGarage and "gas station" or "garage"
    end
    if kind then
      table.insert(S.gasStations, {name = poi.name, kind = kind, pos = poi.pos, radius = FB.radius, fallback = true})
      added[kind] = added[kind] + 1
    end
  end
  log('I', 'mwf', string.format('fallback pit stops from POIs (%d POIs, %d usable): %d garages, %d gas stations added',
    #pois, #kept, added.garage, added["gas station"]))
end

-- Gas stations: same as Most Wanted - centre of the pumps, trigger within GAS_RADIUS metres (3D).
-- Garages (not in Most Wanted): their own zone box.
local function loadGasStations()
  S.gasStations = {}
  if S.rls.active then
    log('I', 'mwf', 'RLS career: pit stops are disabled (repairs and car changes are RLS\'s job)')
    return
  end
  local ok, err = pcall(function()
    local levelId = getCurrentLevelIdentifier()
    local fac = levelId and freeroam_facilities and freeroam_facilities.getFacilities(levelId)
    if not fac then return end
    for _, gs in pairs(fac.gasStations or {}) do
      local center = freeroam_gasStations.gasStationCenterRadius(gs)
      if center and center.x == center.x then
        table.insert(S.gasStations, {name = gs.name, kind = "gas station", pos = center, radius = GAS_RADIUS})
      end
    end
    for _, gar in pairs(fac.garages or {}) do
      local door = freeroam_facilities.getAverageDoorPositionForFacility(gar)
      local pos
      if door and (door.x ~= 0 or door.y ~= 0 or door.z ~= 0) and door.x == door.x then
        pos = door
      else
        local box = zoneBox(gar)
        if box then pos = vec3((box.x0 + box.x1) / 2, (box.y0 + box.y1) / 2, (box.z0 + box.z1) / 2) end
      end
      if pos then table.insert(S.gasStations, {name = gar.name or gar.id, kind = "garage", pos = pos, radius = GARAGE_RADIUS}) end
    end
    if S.options.fallbackPits and levelId then FB.add(levelId) end
  end)
  log('I', 'mwf', string.format('%d pit stops loaded%s', #S.gasStations, ok and '' or (' (lookup failed: ' .. tostring(err) .. ')')))
end

-- returns the station you are inside (or nil) and your distance to it
local function findStation(pos)
  for _, g in ipairs(S.gasStations) do
    local d = (pos - g.pos):length()
    if d < g.radius then return g, d end
  end
end

-- Like Most Wanted's "Check Inside Gas Stations" node: fires ONCE when you go from outside to inside, and not
-- again until you have left. 5 s cooldown on top. Action: recovery.saveHome() + recovery.loadHome().
local function checkGasStations(veh)
  if S.rls.active then return end -- RLS: no pit stop repair, no garage window
  local pos = veh:getPosition()
  local station, dist = findStation(pos)
  local inside = station ~= nil

  if not S.gasInit then -- chase just started: remember where we are, do nothing
    S.gasInit = true
    S.inGas = inside
    S.inGarage = inside and station.kind == "garage"
    MWF.lockdown.refreshBlock()
    return
  end
  if inside == S.inGas then return end
  S.inGas = inside
  S.inGarage = inside and station.kind == "garage"
  MWF.lockdown.refreshBlock()

  if inside then
    local repaired = os.clock() - S.lastGas >= GAS_COOLDOWN
    log('I', 'mwf', string.format('Pit stop entered: %s "%s" (%.1f m from its centre/door, radius %.0f m, pos %.1f,%.1f,%.1f)%s',
      station.kind, tostring(station.name), dist, station.radius, pos.x, pos.y, pos.z, repaired and ' -> repair' or ' -> on cooldown, no repair'))
    if repaired then
      S.lastGas = os.clock()
      veh:queueLuaCommand("recovery.saveHome()")
      veh:queueLuaCommand("recovery.loadHome()")
    end
    if S.options.pitCosts then
      if S.inGarage then
        MWF.garage.openGarage("hub")
        MWF.achievements.add('garageVisits', 1)
        if S.session and S.session.heat >= 5 then MWF.achievements.add('garageHeat5', 1) end
        MWF.util.toast("success", "Garage", "Chase paused while the garage is open. Cars and parts cost bounty (Alt+G toggles it).", 4500)
      else
        MWF.util.toast("success", "Pit Stop", "Repaired. Only garages let you swap cars or change parts.", 3500)
      end
    else
      MWF.util.toast("success", "Pit Stop", "Vehicle options are open while you stay here.", 3000)
    end
  else
    MWF.garage.closeGarage()
    log('I', 'mwf', 'Pit stop left')
    MWF.util.toast("info", "Pit Stop Closed", "Vehicle options locked again.", 2000)
  end
end

MWF.pits = {checkGasStations = checkGasStations, loadGasStations = loadGasStations, scheduleTransfer = scheduleTransfer, tickTransfer = tickTransfer}

return M
