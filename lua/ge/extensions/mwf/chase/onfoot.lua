-- Getting out of the car during a chase (Smash Mode style): stop, press the walking-mode key, run to another car and get in.
-- Free. Uses vanilla walking mode (the player becomes the "unicycle" character); this module keeps the chase alive across the
-- switch, limits sprinting with stamina, and busts you if the police close in around you on foot. Option: S.options.onFoot.
--   * Leaving / entering a car carries the pursuit over to the new body (the same hand-over a pit stop uses).
--   * Stamina: sprinting drains it, walking or standing refills it; at zero the sprint inputs are blocked until it recovers.
--   * Busted: an arrest timer fills (1.5 s) while you are surrounded (3+ police within 12 m, no gap in the ring wider than 240 degrees),
--     cornered (2+ police within 8 m while you are not sprinting) or pinned (a police car within 3.5 m while you are almost still).
--     When it is full you are arrested (vanilla arrest, so everything ends normally). A status line is logged every 3 s.
local MWF = require('/lua/ge/extensions/mwf/core/registry')
local S = MWF.S

local M = {}

local STAMINA_MAX      = 100
local SPRINT_SPEED     = 3.2   -- m/s: faster than a walk (1.8 m/s top speed) means sprinting (top speed 5 m/s)
local DRAIN_PER_S      = 100 / 8   -- 8 s of sprinting from full
local REGEN_PER_S      = 100 / 10  -- 10 s of walking to refill
local REGEN_STILL_MULT = 1.5
local RECOVER_AT       = 40    -- exhausted until stamina is back to this
local RING_R          = 12    -- m: police this close count towards surrounding you (3 or more, with no gap wider than RING_GAP)
local RING_GAP        = math.rad(240)
local CORNER_R        = 8     -- m: two police this close while you are not sprinting corner you
local CORNER_SPEED    = 3.0   -- m/s
local PINNED_R        = 3.5   -- m: one police car this close while you are almost still pins you
local PINNED_SPEED    = 1.5   -- m/s
local ARREST_TIME     = 1.5   -- s the condition must hold (pinned counts at 0.6 speed)
local SPRINT_ACTIONS  = {"unicycle__sprintHold", "unicycle__sprintToggle"}

S.foot = {active = false, stamina = STAMINA_MAX, exhausted = false, arrest = 0, warned = false, arrested = false}

local function isUnicycle(id)
  local o = id and getObjectByID(id)
  return o ~= nil and o.jbeam == 'unicycle'
end

local function blockSprint(on)
  if S.foot.sprintBlocked == on then return end
  S.foot.sprintBlocked = on
  pcall(function()
    core_input_actionFilter.setGroup('mwfStamina', SPRINT_ACTIONS)
    core_input_actionFilter.addAction(0, 'mwfStamina', on)
  end)
end

local function reset()
  S.foot.active, S.foot.stamina, S.foot.exhausted = false, STAMINA_MAX, false
  S.foot.arrest, S.foot.warned, S.foot.arrested = 0, false, false
  blockSprint(false)
end

-- called when the player's vehicle changes during a chase. Returns true if this module took care of it (the chase goes on).
local function handleSwitch(oldId, newId)
  if not S.options.onFoot or not S.session or not newId then return false end
  local toFoot, toCar = isUnicycle(newId), isUnicycle(oldId) and not isUnicycle(newId)
  if not (toFoot or toCar) then return false end
  MWF.pits.scheduleTransfer(oldId, newId)
  S.foot.arrest, S.foot.warned, S.foot.arrested = 0, false, false
  if toFoot then
    S.foot.active, S.foot.stamina, S.foot.exhausted = true, STAMINA_MAX, false
    MWF.util.toast("info", "On foot", "Find another car. Sprinting uses stamina, and the police can still catch you.", 3500)
  else
    reset()
  end
  log('I', 'mwf', toFoot and 'Player got out of the car: chase continues on foot' or 'Player got into a car: chase continues')
  return true
end

-- what the police around the player on foot are doing: returns surrounded, cornered, pinned, how many are within RING_R, nearest distance
local function copsAround(pos, speed)
  local bearings, within8, nearest = {}, 0, math.huge
  pcall(function()
    for pid, pveh in pairs(gameplay_police.getPoliceVehicles()) do
      local o = getObjectByID(pid)
      if o and o:getActive() and not (pveh.role and pveh.role.state == 'disabled') then
        local off = o:getPosition() - pos
        local d = math.sqrt(off.x * off.x + off.y * off.y)
        nearest = math.min(nearest, d)
        if d <= RING_R then table.insert(bearings, math.atan2(off.y, off.x)) end
        if d <= CORNER_R then within8 = within8 + 1 end
      end
    end
  end)
  local surrounded = false
  if #bearings >= 3 then
    table.sort(bearings)
    local maxGap = bearings[1] + 2 * math.pi - bearings[#bearings] -- the wrap-around gap
    for i = 2, #bearings do maxGap = math.max(maxGap, bearings[i] - bearings[i - 1]) end
    surrounded = maxGap <= RING_GAP
  end
  local cornered = within8 >= 2 and speed < CORNER_SPEED
  local pinned = nearest <= PINNED_R and speed < PINNED_SPEED
  return surrounded, cornered, pinned, #bearings, nearest
end

local function update(dtSim, veh, id)
  local f = S.foot
  local onFoot = S.options.onFoot and S.session ~= nil and veh.jbeam == 'unicycle'
  if not onFoot then
    if f.active then reset() end
    return
  end
  f.active = true
  if dtSim <= 0 or dtSim > 0.25 then return end
  local vel = veh:getVelocity()
  local speed = math.sqrt(vel.x * vel.x + vel.y * vel.y)

  -- stamina
  if speed > SPRINT_SPEED then
    f.stamina = math.max(0, f.stamina - DRAIN_PER_S * dtSim)
  else
    f.stamina = math.min(STAMINA_MAX, f.stamina + REGEN_PER_S * (speed < 0.5 and REGEN_STILL_MULT or 1) * dtSim)
  end
  if not f.exhausted and f.stamina <= 0 then
    f.exhausted = true
    MWF.util.toast("warning", "Out of breath", "You cannot sprint until you catch your breath.", 2500)
  elseif f.exhausted and f.stamina >= RECOVER_AT then
    f.exhausted = false
  end
  blockSprint(f.exhausted)

  -- the police closing in
  local surrounded, cornered, pinned, near, nearest = copsAround(veh:getPosition(), speed)
  local caught = surrounded or cornered or pinned
  if os.clock() - (f.logT or 0) > 3 then
    f.logT = os.clock()
    log('I', 'mwf', string.format('On foot: %d police within %d m (nearest %.1f m), speed %.1f m/s, arrest timer %.1f/%.1f%s', near, RING_R,
      nearest == math.huge and -1 or nearest, speed, f.arrest, ARREST_TIME, caught and ' [closing in]' or ''))
  end
  if caught and not f.arrested then
    f.arrest = f.arrest + dtSim * ((surrounded or cornered) and 1 or 0.6)
    if not f.warned then
      f.warned = true
      MWF.util.toast("warning", "They're closing in!", "Break out before they get to you.", 2500)
    end
    if f.arrest >= ARREST_TIME then
      f.arrested = true
      log('I', 'mwf', string.format('Arrested on foot (surrounded=%s cornered=%s pinned=%s)', tostring(surrounded), tostring(cornered), tostring(pinned)))
      local ok, err = pcall(gameplay_police.arrestVehicle, id, true)
      if not ok then log('E', 'mwf', 'arrestVehicle failed: ' .. tostring(err)) end
      -- if vanilla did not end the pursuit (no traffic entry for the character?), end the chase ourselves
      if S.session and (MWF.util.getPursuit(id) or {}).mode ~= -1 then
        pcall(gameplay_police.setPursuitMode, -1, id)
        if S.session then MWF.session.endSession('busted') end
      end
    end
  else
    f.arrest = math.max(0, f.arrest - 2 * dtSim)
    if f.arrest == 0 then f.warned = false end
  end
end

-- ===== stealing traffic cars =====
-- Vanilla keeps AI traffic cars out of walking mode's "get in" targets (they are on gameplay_walk's blacklist), so you cannot
-- enter one. The approach is borrowed from the RLS carjacking add-on: wrap gameplay_walk.toggleWalkingMode; when you are on foot
-- and vanilla has no car for you to get into, take the nearest civilian traffic car within reach out of traffic, take it off
-- the blacklist, switch its AI off and get in. Only inside a chase, and never in an RLS career (RLS and its add-on own this).
local STEAL_REACH, STEAL_MAX_SPEED, STEAL_MAX_SPEED_COP = 5.0, 8.0, 12.0 -- m, m/s (police cars keep rolling a bit while they close in on you)

local function stealingAllowed()
  if not (S.options.stealCars and S.options.onFoot and S.session and S.foot.active) then return false end
  if S.rls and S.rls.active then return false end
  -- any career (vanilla career or RLS) has its own theft rules. NOT "is the RLS carjacking add-on loaded": that add-on loads itself at
  -- startup even in freeroam, where it does nothing, so checking for it switched stealing off in freeroam.
  if career_career and career_career.isActive and career_career.isActive() then return false end
  return gameplay_walk ~= nil and gameplay_walk.isWalking ~= nil and gameplay_walk.isWalking()
end

-- KARR and KITT are scripted show cars: they cannot be stolen
local function isSpecialUnit(id)
  for _, sid in ipairs(S.esc.specials or {}) do if sid == id then return true end end
  return false
end

local function findStealTarget()
  local me = MWF.util.getPlayerVeh()
  if not me then return nil end
  local mypos = me:getPosition()
  local best, bestD = nil, STEAL_REACH
  local nearestAny, nearestAnyD, count = nil, math.huge, 0
  for id, tv in pairs(gameplay_traffic.getTrafficData() or {}) do
    local o = tv.isAi and not tv.isPerson and not (tv.reserved ~= nil or tv.claimed ~= nil) and getObjectByID(id)
    if o and o:getActive() and not isSpecialUnit(id) and not (S.esc.props and S.esc.props[id]) then
      local jb = o:getJBeamFilename()
      local isCop = tv.role and tv.role.name == 'police'
      if jb ~= 'unicycle' and jb ~= 'simple_traffic' and o:getVelocity():length() <= (isCop and STEAL_MAX_SPEED_COP or STEAL_MAX_SPEED) then
        local d = (o:getPosition() - mypos):length()
        count = count + 1
        if d < nearestAnyD then nearestAny, nearestAnyD = id, d end
        if d < bestD then best, bestD = id, d end
      end
    end
  end
  if not best then
    log('I', 'mwf', string.format('Carjack: no traffic car within %.0f m (%d candidates, nearest %s)', STEAL_REACH, count,
      nearestAny and string.format('%.1f m', nearestAnyD) or 'none'))
  end
  return best
end

-- returns true if a car was taken (the walking-mode press is used up)
local function tryTheft()
  if not stealingAllowed() then
    if S.session and S.foot.active and S.options.stealCars and gameplay_walk and gameplay_walk.isWalking and gameplay_walk.isWalking() then
      log('I', 'mwf', 'Carjack not allowed right now (a career is active, or the option is off)')
    end
    return false
  end
  if gameplay_walk.getVehicleInFront and gameplay_walk.getVehicleInFront() then return false end -- vanilla has a car for you
  local id = findStealTarget()
  local o = id and getObjectByID(id)
  if not o then return false end
  local tv = gameplay_traffic.getTrafficData()[id]
  local wasCop = tv and tv.role and tv.role.name == 'police'
  if wasCop then
    -- a police car this mod spawned stops being one of our units: it must not be counted, retired or cleaned up while you drive it
    pcall(MWF.escalation.release, id)
    pcall(function() o:setDynDataFieldbyName("mwfSpawned", 0, "0") end)
  end
  pcall(gameplay_traffic.removeTraffic, id, true)
  pcall(gameplay_walk.removeVehicleFromBlacklist, id)
  pcall(function() o:setDynDataFieldbyName("isTraffic", 0, "false") end)
  pcall(function() o:queueLuaCommand('ai.setMode("disabled")') end)
  local ok = pcall(gameplay_walk.getInVehicle, o)
  if not ok then pcall(function() be:enterVehicle(0, o) end) end
  MWF.pursuit.award('steal', wasCop and "Carjacked a police car" or "Carjacked a car", wasCop and 1500 or 500)
  MWF.achievements.add('carsStolen', 1)
  log('I', 'mwf', string.format('Carjacked %s %d', wasCop and 'police car' or 'traffic car', id))
  return true
end

-- wrap the walking-mode key once. The wrapper asks the live extension, so a reload can never leave it stuck on.
local function installTheftHook()
  if not gameplay_walk or gameplay_walk.mwfWrapped or type(gameplay_walk.toggleWalkingMode) ~= 'function' then return end
  gameplay_walk.mwfWrapped = true
  gameplay_walk.mwfOrigToggleWalkingMode = gameplay_walk.toggleWalkingMode
  gameplay_walk.toggleWalkingMode = function(...)
    if mwf_core and mwf_core.tryTheft and mwf_core.tryTheft() then return end
    return gameplay_walk.mwfOrigToggleWalkingMode(...)
  end
end

M.tryTheft = tryTheft
MWF.onfoot = {handleSwitch = handleSwitch, update = update, reset = reset, installTheftHook = installTheftHook}

return M
