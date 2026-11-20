-- Pit stop economy: wallet, car and part prices, vehicle / parts guards, garage pause.
local MWF = require('/lua/ge/extensions/mwf/core/registry')
local S = MWF.S
local CFG = require('/lua/ge/extensions/mwf/data/config')

local M = {}

-- The chase is frozen (game paused) while any garage window is open, so you cannot wait for a pit stop to "roll" a better
-- offer, and the pursuit does not tick while you shop. Only unpauses what this mod paused.
local function applyGaragePause()
  local want = S.session ~= nil and S.inGarage and S.garage.mode ~= nil
  if want == S.garagePaused then return end
  S.garagePaused = want
  pcall(function() simTimeAuthority.pause(want) end)
  log('I', 'mwf', 'Garage: chase ' .. (want and 'paused' or 'resumed'))
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

local function buildCatalog()
  if S.garage.catalog then return S.garage.catalog end
  local list = {}
  local ok, err = pcall(function()
    local res = core_vehicles.getConfigList(true)
    for _, c in ipairs(res.configs or {}) do
      local value = tonumber(c.Value)
      if value and value > 0 and c.Type ~= 'Prop' and c.Type ~= 'Trailer' and c.model_key and c.key then
        local name = tostring(c.Name or c.key)
        local brand = c.Brand and tostring(c.Brand) or ""
        local label = (brand ~= "" and not name:lower():find(brand:lower(), 1, true)) and (brand .. " " .. name) or name
        table.insert(list, {model = c.model_key, key = c.key, label = label, lower = label:lower(), value = value,
          pc = c.pc_file or ("vehicles/" .. c.model_key .. "/" .. c.key .. ".pc")})
      end
    end
  end)
  table.sort(list, function(a, b) return a.value > b.value end)
  log('I', 'mwf', string.format('garage catalog: %d cars%s', #list, ok and '' or (' (lookup failed: ' .. tostring(err) .. ')')))
  S.garage.catalog = list
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

local function partValue(name)
  local ok, v = pcall(function()
    local jbeamIO = require('jbeam/io')
    local vd = extensions.core_vehicle_manager.getPlayerVehicleData()
    local part = vd and jbeamIO.getPart(vd.ioCtx, name)
    return part and part.information and part.information.value
  end)
  return (ok and tonumber(v)) or 0
end

function M.partsGate(dataTree)
  if not pitCostsActive() then return true, 0 end
  local cost, names = 0, {}
  pcall(function()
    local cfg = extensions.core_vehicle_partmgmt.getConfig()
    local old = flattenParts(cfg and cfg.partsTree, {})
    for name, n in pairs(flattenParts(dataTree, {})) do
      local extra = n - (old[name] or 0)
      if extra > 0 then
        local v = math.min(PART_PRICE_MAX, partValue(name) * S.options.priceFactor)
        if v > 0 then
          cost = cost + v * extra
          table.insert(names, name)
        end
      end
    end
  end)
  cost = math.floor(cost / 5 + 0.5) * 5
  if cost > wallet() then
    MWF.util.toast("warning", "Not enough bounty", string.format("These parts cost $%d, you have $%d.", cost, math.floor(wallet())), 3500)
    return false
  end
  return true, cost, table.concat(names, ", ")
end

function M.partsCharged(cost, names)
  if cost and cost > 0 then
    spendBounty(cost, "Parts: " .. (names or ""))
    MWF.achievements.add('moneySpent', cost)
  end
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
      local ok, cost, names = true, 0, nil
      if mwf_core then ok, cost, names = mwf_core.partsGate(dataTree) end
      if ok == false then return end
      local r = origParts(dataTree, ...)
      if mwf_core and cost and cost > 0 then mwf_core.partsCharged(cost, names) end
      return r
    end
  end
end

function M.toggleGarage()
  if not (S.session and S.inGarage and S.options.pitCosts) then return end
  if S.garage.mode then closeGarage() else openGarage("hub") end
end

MWF.garage = {buildCatalog = buildCatalog, carPrice = carPrice, closeGarage = closeGarage, installVehicleGuards = installVehicleGuards, openGarage = openGarage, spendBounty = spendBounty, wallet = wallet}

return M
