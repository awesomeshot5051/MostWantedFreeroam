-- Most Wanted Freeroam: vehicle-side weapon ammo gate for the Universal Weapons mod.
--
-- This does NOT modify or copy any file from Universal Weapons. It loads into every vehicle (lua/vehicle/extensions/auto)
-- and does nothing unless the vehicle has a Universal Weapons part (a jbeam section with ammoTag + fireRate).
--
-- How it works: the fire input writes electrics.values.fireweapons (or the part's own fireElectric). For each weapon found
-- we take that key out of the electrics table and answer reads/writes through a small proxy:
--   * writes (the trigger) are remembered as "held";
--   * reads (what the weapon's controller sees) return 1 only while the trigger is held AND rounds are loaded.
-- Rounds are used up by time (fireRate/60 per second while firing). When they run out the next trigger pull asks the
-- game-side mod (mwf_core) for a reset-bar slot, which is answered through grantSlot().

local M = {}

local weapons = {}        -- [fireElectric] = {rate, perSlot, rounds, held, out, accum, awaiting, awaitT, retryT}
local scanned = false
local installed = false

local function scan()
  scanned = true
  local data = v and v.data
  if type(data) ~= 'table' then return end
  for _, d in pairs(data) do
    if type(d) == 'table' and d.ammoTag and d.fireRate and d.barrelNodeFront then
      local fe = d.fireElectric or "fireweapons"
      if not weapons[fe] then
        weapons[fe] = {
          rate = d.fireRate,
          -- machine guns (no explosion) = 100 rounds per slot, big guns = 10; a jbeam key can override
          perSlot = d.roundsPerSlot or ((d.explosionRadius or 0) > 0 and 10 or 100),
          rounds = 0, held = 0, out = 0, accum = 0, awaiting = false, awaitT = 0, retryT = 0,
        }
      end
    end
  end
end

local function install()
  if installed or not next(weapons) then return end
  installed = true
  for fe, w in pairs(weapons) do
    log('I', 'mwfWeapons', string.format('gating weapon on %q: %s rpm, %s rounds per slot', fe, tostring(w.rate), tostring(w.perSlot)))
  end
  local values = electrics.values
  local mt = getmetatable(values)
  if not mt then
    mt = {}
    setmetatable(values, mt)
  end
  local oldIndex, oldNewIndex = mt.__index, mt.__newindex
  for fe, w in pairs(weapons) do
    local cur = rawget(values, fe)
    w.held = cur or 0
    rawset(values, fe, nil) -- absent key => the metamethods below answer for it
  end
  mt.__index = function(t, k)
    local w = weapons[k]
    if w then return w.out end
    if type(oldIndex) == 'function' then return oldIndex(t, k) end
    if type(oldIndex) == 'table' then return oldIndex[k] end
    return nil
  end
  mt.__newindex = function(t, k, val)
    local w = weapons[k]
    if w then w.held = val or 0 return end
    if type(oldNewIndex) == 'function' then return oldNewIndex(t, k, val) end
    rawset(t, k, val)
  end
end

-- tell the game-side HUD how many rounds are loaded (throttled unless forced)
local function pushAmmo(fe, w, force)
  local r = math.floor(w.rounds)
  if not force and r == w.pushed then return end
  if not force and (w.pushT or 0) > 0 then return end
  w.pushed, w.pushT = r, 0.1
  obj:queueGameEngineLua(string.format("if mwf_core then mwf_core.reportAmmo(%d, %q, %d, %d) end", obj:getID(), fe, r, w.perSlot))
end

local function request(fe, w)
  log('I', 'mwfWeapons', 'out of rounds, asking for a slot for ' .. fe)
  w.awaiting = true
  w.awaitT = 1
  w.retryT = 0.5
  obj:queueGameEngineLua(string.format("extensions.load('mwf_core'); mwf_core.requestSlot(%d, %d, %q)", obj:getID(), w.perSlot, fe))
end

local function updateGFX(dt)
  if not scanned then
    scan()
    install()
  end
  if not installed then return end
  for fe, w in pairs(weapons) do
    local held = (tonumber(w.held) or 0) > 0.5
    if w.awaiting then
      w.awaitT = w.awaitT - dt
      if w.awaitT <= 0 then w.awaiting = false end
    end
    w.retryT = math.max(0, w.retryT - dt)
    w.pushT = math.max(0, (w.pushT or 0) - dt)

    if held and w.rounds > 0 then
      w.accum = w.accum + dt * (w.rate / 60)
      local n = math.floor(w.accum)
      if n >= 1 then
        w.rounds = math.max(0, w.rounds - n)
        w.accum = w.accum - n
      end
    end

    if held and w.rounds <= 0 and not w.awaiting and w.retryT <= 0 then
      request(fe, w)
    end
    w.out = (held and w.rounds > 0) and 1 or 0
    pushAmmo(fe, w, w.pushed == nil)
  end
end

-- answer from mwf_core: ok = a slot was paid (or the chase is not active, so it is free)
local function grantSlot(fe, ok, rounds)
  local w = weapons[fe]
  if not w or not w.awaiting then return end
  w.awaiting = false
  if ok then w.rounds = w.rounds + ((rounds and rounds > 0) and rounds or w.perSlot) end
  log('I', 'mwfWeapons', string.format('slot answer for %s: %s (rounds now %d)', fe, tostring(ok), w.rounds))
  pushAmmo(fe, w, true)
end

local function getRounds()
  local total = 0
  for _, w in pairs(weapons) do total = total + w.rounds end
  return total
end

-- a reset empties the guns (they must be paid for again)
local function resetRounds()
  for fe, w in pairs(weapons) do
    w.rounds, w.accum, w.awaiting = 0, 0, false
    pushAmmo(fe, w, true)
  end
end

local function onReset()
  resetRounds()
end

M.updateGFX = updateGFX
M.grantSlot = grantSlot
M.getRounds = getRounds
M.resetRounds = resetRounds
M.onReset = onReset

return M
