-- Pit stop economy: wallet, car and part prices, vehicle / parts guards, garage pause.
local MWF = require('/lua/ge/extensions/mwf/core/registry')
local S = MWF.S
local CFG = require('/lua/ge/extensions/mwf/data/config')

local M = {}

-- The chase is frozen (game paused) while any garage window is open, so you cannot wait for a pit stop to "roll" a better
-- offer, and the pursuit does not tick while you shop. Only unpauses what this mod paused.
local function applyGaragePause()
  local want = S.session ~= nil and ((S.inGarage and S.garage.mode ~= nil) or S.rlsComputer == true) -- RLS: also while its computer is open
  if want == S.garagePaused then return end
  S.garagePaused = want
  pcall(function()
    if want then
      -- remember the speed the game was running at: the game restores whatever it saw when it was paused, and a pause that is re-applied
      -- mid-ramp (see keepGaragePaused) makes it see a near-zero speed, which resumed the chase at 1/1000 speed
      local t = simTimeAuthority.get()
      S.garage.timeScale = (type(t) == 'number' and t > 0.05) and t or 1
    end
    simTimeAuthority.pause(want)
    if not want then simTimeAuthority.setInstant(S.garage.timeScale or 1) end
  end)
  log('I', 'mwf', 'Garage: chase ' .. (want and 'paused' or 'resumed'))
end
-- Something else (a menu closing, another mod, a UI popup) can lift the pause while the garage is still open, and the cops then
-- carry on and bust you while you shop. So while the garage holds the pause, it is put back whenever it is found lifted.
local lastRepause = 0
local function keepGaragePaused()
  if not S.garagePaused then return end
  local ok, paused = pcall(function() return simTimeAuthority.getPause() end)
  if ok and paused == false then
    pcall(function() simTimeAuthority.pause(true) end)
    if os.clock() - lastRepause > 1 then
      log('W', 'mwf', 'Garage: the game was un-paused by something else; paused it again')
    end
    lastRepause = os.clock()
  end
end
local function closeGarage()
  S.garage.mode = nil
  S.garage.show[0] = false
  applyGaragePause()
end
local function openGarage(mode)
  S.garage.mode = mode or "hub"
  S.garage.show[0] = true
  S.garage.note = ""
  applyGaragePause()
end

-- ===== pit stop economy: swapping or modifying your car costs bounty =====
-- Your wallet is the bounty you earned minus what you spent. Heat is based on what you EARNED, so spending never lowers it.
-- Only active in a pit stop during a chase, and only with the "pit stop costs" option on (default).
--   * Cars: this mod's garage window lists only cars you can afford. Any other way of swapping (pause menu, other mods)
--     goes through the same price check, so it cannot be used to dodge the cost.
--   * Parts: the normal parts configurator stays available, but each change is priced and refused if unaffordable.
-- Prices are a share of the real value (options.priceFactor, default 0.5), clamped so cheap cars are not free and
-- supercars are not out of reach forever.
local PRICE_MIN, PRICE_MAX = 1500, 60000
local PART_PRICE_MAX = 20000

local function wallet()
  return S.session and (S.session.bounty - (S.session.spent or 0)) or 0
end

local function spendBounty(amount, text)
  if not S.session or amount <= 0 then return end
  S.session.spent = (S.session.spent or 0) + amount
  table.insert(S.feed, 1, {text = text, amount = amount, mult = 1, neg = true, t = os.clock()})
  while #S.feed > CFG.FEED_LINES do table.remove(S.feed) end
  log('I', 'mwf', string.format('Spent $%d bounty: %s (wallet now $%d)', amount, text, wallet()))
end

local function carPrice(value)
  local v = tonumber(value) or 0
  return math.floor(math.max(PRICE_MIN, math.min(PRICE_MAX, v * S.options.priceFactor)) / 50 + 0.5) * 50
end

-- Only things you can actually drive: a Car or Truck, with an engine. Props (bridges, ramps), trailers, debug rigs and traffic
-- dummies are dropped. The vehicle type is usually NOT on the config itself: the game merges the model's type into the config's
-- "aggregates" table (aggregates.Type = {Car = true}), and only a few configs carry a plain `Type`. Read both.
local function typesOf(c)
  if type(c.Type) == 'string' then return {[c.Type] = true} end
  local agg = type(c.aggregates) == 'table' and c.aggregates.Type
  if type(agg) == 'table' then return agg end
  return {}
end
local function isDriveable(c)
  local t = typesOf(c)
  if t.Prop or t.Trailer or t.Debug or t.Traffic then return false end
  local power = tonumber(c.Power)
  if power ~= nil and power <= 0 then return false end
  local dt = c.Drivetrain
  if type(dt) == 'string' and (dt == 'N/A' or dt == '') then return false end
  if t.Car or t.Truck then return true end
  -- no usable type (a mod that did not set one): it counts as a car only if it clearly has an engine
  return next(t) == nil or t.Unknown ~= nil and power ~= nil and power > 0
end

local function buildCatalog()
  if S.garage.catalog then return S.garage.catalog end
  local list = {}
  local ok, err = pcall(function()
    local res = core_vehicles.getConfigList(true)
    for _, c in ipairs(res.configs or {}) do
      local value = tonumber(c.Value)
      if value and value > 0 and isDriveable(c) and c.model_key and c.key then
        local name = tostring(c.Name or c.key)
        local brand = c.Brand and tostring(c.Brand) or ""
        local label = (brand ~= "" and not name:lower():find(brand:lower(), 1, true)) and (brand .. " " .. name) or name
        local years = type(c.Years) == 'table' and c.Years or nil
        table.insert(list, {model = c.model_key, key = c.key, label = label, lower = label:lower(), value = value,
          name = name, brand = brand, preview = c.preview, power = tonumber(c.Power), topSpeed = tonumber(c['Top Speed']),
          accel = tonumber(c['0-100 km/h']), weight = tonumber(c.Weight), drivetrain = c.Drivetrain, transmission = c.Transmission,
          bodyStyle = c['Body Style'], year = years and tonumber(years.min) or nil,
          pc = c.pc_file or ("vehicles/" .. c.model_key .. "/" .. c.key .. ".pc")})
      end
    end
  end)
  table.sort(list, function(a, b) return a.value > b.value end)
  log('I', 'mwf', string.format('garage catalog: %d cars%s', #list, ok and '' or (' (lookup failed: ' .. tostring(err) .. ')')))
  if #list >= 20 then S.garage.catalog = list end -- a tiny list means the game's vehicle list was not ready: try again next time
  return list
end

local function priceFor(model, opt)
  local key = opt and type(opt.config) == 'string' and (opt.config:match('([^/\\]+)%.pc$') or opt.config) or nil
  local c
  pcall(function()
    if key then c = core_vehicles.getConfig(model, key) end
    if not c then -- unknown config (a custom/saved one): price it like the model's default config
      local m = core_vehicles.getModel(model)
      local def = m and m.model and m.model.default_pc
      if def then c = core_vehicles.getConfig(model, def) end
    end
  end)
  return carPrice(c and c.Value)
end

local function pitCostsActive()
  return S.session ~= nil and S.inGas and S.options.pitCosts and not S.bypassGate -- any pit stop prices swaps (pause menu etc.); only garages show the UI
end

function M.vehicleGate(model, opt)
  if not pitCostsActive() then return true, 0 end
  local price = priceFor(model, opt)
  if price > wallet() then
    MWF.util.toast("warning", "Not enough bounty", string.format("%s costs $%d, you have $%d.", tostring(model), price, math.floor(wallet())), 3500)
    return false
  end
  return true, price
end

function M.vehicleCharged(price, model, opt)
  local key = opt and type(opt.config) == 'string' and (opt.config:match('([^/\\]+)%.pc$') or opt.config) or "default"
  spendBounty(price, "Bought " .. tostring(model) .. " (" .. tostring(key) .. ")")
  MWF.achievements.add('carsBought', 1)
  MWF.achievements.add('moneySpent', price)
end

local function flattenParts(node, out)
  if type(node) ~= 'table' then return out end
  if node.chosenPartName and node.chosenPartName ~= '' then out[node.chosenPartName] = (out[node.chosenPartName] or 0) + 1 end
  if type(node.children) == 'table' then
    for _, child in pairs(node.children) do flattenParts(child, out) end
  end
  return out
end

-- Weapon mounts (Universal Weapons turrets, guns, ...) ship with no price in their jbeam, so they would be free. Give them a real one:
-- a part is a weapon mount if its slot type starts with "weapon" or it loads the universalweapons controller. Big mounts (the slot name
-- says "big", or a "howitzer" / "cannon" / "autocannon" in the part name) cost more. These are part VALUES; the price factor and the
-- part price cap still apply, like for every other part.
local WEAPON_VALUE, WEAPON_VALUE_BIG = 16000, 40000
local function weaponValue(part, name)
  if type(part) ~= 'table' then return nil end
  local slot = tostring(part.slotType or ""):lower()
  local isWeapon = slot:find("^weapon") ~= nil
  if not isWeapon and type(part.controller) == 'table' then
    for _, c in pairs(part.controller) do
      if type(c) == 'table' and tostring(c[1]) == 'universalweapons' then isWeapon = true end
    end
  end
  if not isWeapon then return nil end
  local label = (slot .. " " .. tostring(name or "")):lower()
  if label:find("big") or label:find("howitzer") or label:find("cannon") then return WEAPON_VALUE_BIG end
  return WEAPON_VALUE
end

local function partValue(name)
  local ok, v = pcall(function()
    local jbeamIO = require('jbeam/io')
    local vd = extensions.core_vehicle_manager.getPlayerVehicleData()
    local part = vd and jbeamIO.getPart(vd.ioCtx, name)
    local value = tonumber(part and part.information and part.information.value) or 0
    if value <= 0 then value = weaponValue(part, name) or value end
    return value
  end)
  return (ok and tonumber(v)) or 0
end

-- ===== owned parts =====
-- A part you bought is yours for the rest of THIS chase: installing it again is free, and so is putting back a part you swapped out
-- (you kept it). It lives on the session, so a Crash Breaker reset keeps it and the end of the chase forgets it. Keyed by part name.
local function isOwned(name)
  local own = S.session and S.session.ownedParts
  return own ~= nil and own[tostring(name)] == true
end
local function markOwned(names)
  if not S.session then return end
  S.session.ownedParts = S.session.ownedParts or {}
  for _, name in ipairs(names or {}) do S.session.ownedParts[name] = true end
end

local function partPrice(name)
  if isOwned(name) then return 0 end
  local v = math.min(PART_PRICE_MAX, partValue(name) * S.options.priceFactor)
  return math.floor(v / 5 + 0.5) * 5
end

-- what a new parts tree costs: the value of every part that is in it more times than in the current build
-- (parts you already own cost nothing). Also returns the names that become yours: the ones bought, and the ones this change takes off the car.
local function partsCost(dataTree)
  local cost, names, own = 0, {}, {}
  pcall(function()
    local cfg = extensions.core_vehicle_partmgmt.getConfig()
    local old = flattenParts(cfg and cfg.partsTree, {})
    local new = flattenParts(dataTree, {})
    for name, n in pairs(new) do
      local extra = n - (old[name] or 0)
      if extra > 0 and not isOwned(name) then
        local v = math.min(PART_PRICE_MAX, partValue(name) * S.options.priceFactor)
        if v > 0 then
          cost = cost + v * extra
          table.insert(names, name)
          table.insert(own, name)
        end
      end
    end
    for name, n in pairs(old) do
      if n > (new[name] or 0) and not isOwned(name) then table.insert(own, name) end -- swapped out: you keep it
    end
  end)
  return math.floor(cost / 5 + 0.5) * 5, table.concat(names, ", "), own
end

function M.partsGate(dataTree)
  if not pitCostsActive() then return true, 0 end
  local cost, names, own = partsCost(dataTree)
  if cost > wallet() then
    MWF.util.toast("warning", "Not enough bounty", string.format("These parts cost $%d, you have $%d.", cost, math.floor(wallet())), 3500)
    return false
  end
  return true, cost, names, own
end

function M.partsCharged(cost, names, own)
  if cost and cost > 0 then
    spendBounty(cost, "Parts: " .. (names or ""))
    MWF.achievements.add('moneySpent', cost)
  end
  markOwned(own) -- what you bought is yours now, and so is what you swapped out
end

local function installVehicleGuards()
  local cv = core_vehicles
  if cv and not cv.mwfWrapped and cv.replaceVehicle and cv.spawnNewVehicle then
    cv.mwfWrapped = true
    local origReplace, origSpawn = cv.replaceVehicle, cv.spawnNewVehicle
    cv.replaceVehicle = function(model, opt, ...)
      local ok, price = true, 0
      if mwf_core then ok, price = mwf_core.vehicleGate(model, opt) end
      if ok == false then return false end
      local r = origReplace(model, opt, ...)
      if r and mwf_core and price and price > 0 then mwf_core.vehicleCharged(price, model, opt) end
      return r
    end
    cv.spawnNewVehicle = function(model, opt, ...)
      local ok, price = true, 0
      if mwf_core then ok, price = mwf_core.vehicleGate(model, opt) end
      if ok == false then return false end
      local r = origSpawn(model, opt, ...)
      if r and mwf_core and price and price > 0 then mwf_core.vehicleCharged(price, model, opt) end
      return r
    end
  end
  local pm = core_vehicle_partmgmt
  if pm and not pm.mwfWrapped and pm.setPartsTreeConfig then
    pm.mwfWrapped = true
    local origParts = pm.setPartsTreeConfig
    pm.setPartsTreeConfig = function(dataTree, ...)
      local ok, cost, names, own = true, 0, nil, nil
      if mwf_core then ok, cost, names, own = mwf_core.partsGate(dataTree) end
      if ok == false then return end
      local r = origParts(dataTree, ...)
      if mwf_core and ((cost and cost > 0) or (own and #own > 0)) then mwf_core.partsCharged(cost, names, own) end
      return r
    end
  end
end

function M.toggleGarage()
  if not (S.session and S.inGarage and S.options.pitCosts) then return end
  if S.garage.mode then closeGarage() else openGarage("hub") end
end

MWF.garage = {applyGaragePause = applyGaragePause, isOwned = isOwned, keepGaragePaused = keepGaragePaused, buildCatalog = buildCatalog, carPrice = carPrice, partPrice = partPrice, partsCost = partsCost, closeGarage = closeGarage, installVehicleGuards = installVehicleGuards, openGarage = openGarage, spendBounty = spendBounty, wallet = wallet}

return M
