-- The garage shop: Lua side of the Vue UI in ui/ui-vue/mods/most_wanted_freeroam (a car picker and a parts shop in the style of
-- the RLS computer, at the listed price, no negotiating). The chase is paused while it is open (economy/garage.lua).
--
-- The Vue page asks for data by calling the shop* functions below (they are merged into mwf_core, so the page calls
-- mwf_core.shopCars(...) and friends and gets a table back). This file only tells the page when to open and close.
local MWF = require('/lua/ge/extensions/mwf/core/registry')
local S = MWF.S

local M = {}

local shown = false
local OPEN_TIMEOUT = 4 -- seconds the page gets to answer shopInit() before we give up (so a broken UI never leaves the game paused)

-- ===== open / close =====
local function wanted()
  return S.session ~= nil and S.inGarage and S.options.pitCosts and S.garage.mode ~= nil
end

-- called every frame
local function drawGarage()
  local want = wanted()
  if want ~= shown then
    shown = want
    if want then S.garage.openedAt, S.garage.ack = os.clock(), false end
    guihooks.trigger('MwfShop', {visible = want})
  end
  if want and not S.garage.ack and os.clock() - (S.garage.openedAt or 0) > OPEN_TIMEOUT then
    log('E', 'mwf', 'Garage UI did not answer: is ui/ui-vue/mods/most_wanted_freeroam loaded? Closing the garage so the game is not left paused.')
    MWF.util.toast("error", "Garage UI did not load", "Check the game console / BeamNG.log for errors from most_wanted_freeroam.", 6000)
    MWF.garage.closeGarage()
  end
end

function M.shopClose() MWF.garage.closeGarage() end

function M.shopVehicleName()
  local name = ""
  pcall(function()
    local _, id = MWF.util.getPlayerVeh()
    local vd = extensions.core_vehicle_manager.getVehicleData(id)
    name = tostring(vd and vd.model or "")
    local m = core_vehicles.getModel(name)
    if m and m.model then name = ((m.model.Brand and (m.model.Brand .. " ") or "") .. (m.model.Name or name)) end
  end)
  return name
end

-- first call of the page: it is alive. Returns what the header and the filters need.
function M.shopInit()
  S.garage.ack = true
  local brands, seen = {}, {}
  for _, c in ipairs(MWF.garage.buildCatalog()) do
    if c.brand ~= "" and not seen[c.brand] then seen[c.brand] = true table.insert(brands, c.brand) end
  end
  table.sort(brands, function(a, b) return a:lower() < b:lower() end)
  return {wallet = math.floor(MWF.garage.wallet()), factor = math.floor(S.options.priceFactor * 100 + 0.5), brands = brands, vehicle = M.shopVehicleName()}
end

function M.shopWallet() return math.floor(MWF.garage.wallet()) end

-- ===== car picker =====
local function catalogEntry(model, key)
  for _, c in ipairs(MWF.garage.buildCatalog()) do
    if c.model == model and c.key == key then return c end
  end
end

local SORTS = {
  priceDesc = function(a, b) if a.price ~= b.price then return a.price > b.price end return a.c.label < b.c.label end,
  priceAsc = function(a, b) if a.price ~= b.price then return a.price < b.price end return a.c.label < b.c.label end,
  name = function(a, b) return a.c.label:lower() < b.c.label:lower() end,
  power = function(a, b) local pa, pb = a.c.power or 0, b.c.power or 0 if pa ~= pb then return pa > pb end return a.c.label < b.c.label end,
}

local function carRow(c, price, w)
  return {model = c.model, key = c.key, name = c.name, brand = c.brand, label = c.label, price = price, value = c.value,
    preview = c.preview, power = c.power, topSpeed = c.topSpeed, accel = c.accel, weight = c.weight, drivetrain = c.drivetrain,
    transmission = c.transmission, bodyStyle = c.bodyStyle, year = c.year, afford = price <= w}
end

-- q = {search, brand, affordable, sort, page, perPage}
function M.shopCars(q)
  q = type(q) == 'table' and q or {}
  local w = MWF.garage.wallet()
  local search = tostring(q.search or ""):lower()
  local brand = tostring(q.brand or "")
  local rows = {}
  for _, c in ipairs(MWF.garage.buildCatalog()) do
    local price = MWF.garage.carPrice(c.value)
    if (search == "" or c.lower:find(search, 1, true)) and (brand == "" or c.brand == brand) and not (q.affordable and price > w) then
      table.insert(rows, {c = c, price = price})
    end
  end
  table.sort(rows, SORTS[q.sort] or SORTS.priceDesc)
  local per = math.max(1, math.min(100, tonumber(q.perPage) or 30))
  local page = math.max(0, tonumber(q.page) or 0)
  local items = {}
  for i = page * per + 1, math.min(#rows, (page + 1) * per) do
    items[#items + 1] = carRow(rows[i].c, rows[i].price, w)
  end
  return {items = items, total = #rows, wallet = math.floor(w), page = page, perPage = per}
end

-- the whole catalog in one go: the page filters, sorts and pages it itself
function M.shopAllCars()
  local w = MWF.garage.wallet()
  local items = {}
  for _, c in ipairs(MWF.garage.buildCatalog()) do
    local row = carRow(c, MWF.garage.carPrice(c.value), w)
    row.search = c.lower
    items[#items + 1] = row
  end
  return {items = items, total = #items, wallet = math.floor(w)}
end

function M.shopBuyCar(model, key)
  local c = catalogEntry(tostring(model), tostring(key))
  if not c then return {ok = false, msg = "That car is no longer in the catalog."} end
  local price = MWF.garage.carPrice(c.value)
  if price > MWF.garage.wallet() then
    return {ok = false, msg = string.format("Not enough bounty: it costs $%d, you have $%d.", price, math.floor(MWF.garage.wallet()))}
  end
  local ok, res = pcall(core_vehicles.replaceVehicle, c.model, {config = c.pc}, MWF.util.getPlayerVeh())
  if not ok then return {ok = false, msg = "Could not swap: " .. tostring(res):sub(1, 80)} end
  if res == false then return {ok = false, msg = "The swap was refused."} end
  return {ok = true, msg = "Bought " .. c.label .. " for $" .. price, wallet = math.floor(MWF.garage.wallet()), vehicle = c.label}
end

-- ===== parts shop =====
-- Categories are grouped from the slot's path: the first pattern that matches wins.
local CATEGORIES = {
  {"Interior", {"interior", "seat", "steer", "dash", "gauge", "cluster", "pedal", "shifter", "console", "airbag", "belt"}},
  {"Engine", {"engine", "turbo", "supercharg", "intake", "exhaust", "radiator", "fuel", "ecu", "nitrous", "flywheel", "header", "manifold", "coolant", "oil", "battery", "alternator"}},
  {"Drivetrain", {"transmission", "gearbox", "transfer", "driveshaft", "differential", "diff", "clutch", "axle", "halfshaft", "gear"}},
  {"Wheels & Tires", {"wheel", "tire", "tyre", "rim", "hubcap"}},
  {"Suspension & Brakes", {"suspension", "spring", "shock", "strut", "brake", "caliper", "rotor", "sway", "swaybar", "arm", "knuckle", "hub"}},
  {"Body", {"body", "bumper", "hood", "bonnet", "fender", "door", "trunk", "spoiler", "wing", "mirror", "light", "grille", "skirt", "glass", "window", "roof", "tailgate", "bed", "cab", "paint", "wiper"}},
}
local CATEGORY_ORDER = {"Engine", "Drivetrain", "Suspension & Brakes", "Wheels & Tires", "Body", "Interior", "Other"}

local function categoryOf(path)
  local p = tostring(path):lower()
  for _, cat in ipairs(CATEGORIES) do
    for _, pat in ipairs(cat[2]) do
      if p:find(pat, 1, true) then return cat[1] end
    end
  end
  return "Other"
end

local function partCtx()
  local vd = extensions.core_vehicle_manager.getPlayerVehicleData()
  local cfg = extensions.core_vehicle_partmgmt.getConfig()
  if not (vd and cfg and cfg.partsTree) then return nil end
  local jbeamIO = require('jbeam/io')
  return {vd = vd, tree = cfg.partsTree, avail = jbeamIO.getAvailableParts(vd.ioCtx) or {}}
end

local function partLabel(avail, name)
  if not name or name == "" then return "(empty)" end
  local info = avail[name]
  local desc = info and info.description
  if type(desc) == 'table' then desc = desc.description end
  local out
  if desc then pcall(function() out = core_vehicle_partmgmt.getTranslation(desc, "ui.vehicleconfig.information.name.") end) end
  return tostring(out or desc or name)
end

local function slotLabel(parentInfo, slotName)
  local info = parentInfo and parentInfo.slotInfoUi and parentInfo.slotInfoUi[slotName]
  local out
  if info and info.description then pcall(function() out = core_vehicle_partmgmt.getTranslation(info.description, "ui.vehicleconfig.slot.description.") end) end
  return (tostring(out or slotName):gsub("_", " "))
end

local function findNode(tree, path)
  if path == "/" then return tree end
  local node = tree
  for seg in tostring(path):gmatch("[^/]+") do
    node = node and node.children and node.children[seg]
    if not node then return nil end
  end
  return node
end

local function buyable(avail, name)
  local info = avail[name]
  return not (info and info.isAuxiliary)
end

-- every slot that has something other than the installed part to choose from
function M.shopParts()
  local ctx = partCtx()
  if not ctx then return {error = "No vehicle data. Get in your car first.", categories = {}} end
  local cats = {}
  local function walk(node, slotName, parentInfo, depth)
    local info = ctx.avail[node.chosenPartName]
    if depth > 0 then
      local n = 0
      for _, name in ipairs(node.suitablePartNames or {}) do
        if name ~= node.chosenPartName and buyable(ctx.avail, name) then n = n + 1 end
      end
      if n > 0 then
        local cat = categoryOf(node.path or slotName)
        cats[cat] = cats[cat] or {name = cat, slots = {}}
        table.insert(cats[cat].slots, {path = node.path, name = slotLabel(parentInfo, slotName), installed = partLabel(ctx.avail, node.chosenPartName), count = n})
      end
    end
    local names = {}
    for childSlot in pairs(node.children or {}) do table.insert(names, childSlot) end
    table.sort(names)
    for _, childSlot in ipairs(names) do walk(node.children[childSlot], childSlot, info, depth + 1) end
  end
  walk(ctx.tree, "main", nil, 0)
  local out = {}
  for _, name in ipairs(CATEGORY_ORDER) do
    if cats[name] then
      table.sort(cats[name].slots, function(a, b) return a.name:lower() < b.name:lower() end)
      table.insert(out, cats[name])
    end
  end
  return {categories = out, wallet = math.floor(MWF.garage.wallet()), vehicle = M.shopVehicleName()}
end

function M.shopSlotParts(path)
  local ctx = partCtx()
  local node = ctx and findNode(ctx.tree, tostring(path))
  if not node then return {parts = {}} end
  local out = {}
  for _, name in ipairs(node.suitablePartNames or {}) do
    if buyable(ctx.avail, name) then
      local installed = name == node.chosenPartName
      table.insert(out, {name = name, label = partLabel(ctx.avail, name), price = installed and 0 or MWF.garage.partPrice(name), installed = installed,
        owned = not installed and MWF.garage.isOwned(name)})
    end
  end
  table.sort(out, function(a, b)
    if a.installed ~= b.installed then return a.installed end
    if a.price ~= b.price then return a.price < b.price end
    return a.label:lower() < b.label:lower()
  end)
  return {parts = out}
end

-- the parts tree with the cart applied; cart = {{path, part}, ...}
local function applyCart(ctx, cart)
  local tree = deepcopy(ctx.tree)
  for _, item in pairs(type(cart) == 'table' and cart or {}) do
    local node = findNode(tree, tostring(item.path))
    if node and tostring(item.part or "") ~= "" then node.chosenPartName = tostring(item.part) end
  end
  return tree
end

function M.shopQuote(cart)
  local ctx = partCtx()
  if not ctx then return {cost = 0, ok = false} end
  local cost = MWF.garage.partsCost(applyCart(ctx, cart))
  local w = MWF.garage.wallet()
  return {cost = cost, wallet = math.floor(w), ok = cost <= w}
end

function M.shopBuyParts(cart)
  local ctx = partCtx()
  if not ctx then return {ok = false, msg = "No vehicle data."} end
  local tree = applyCart(ctx, cart)
  local cost = MWF.garage.partsCost(tree)
  if not next(type(cart) == 'table' and cart or {}) then return {ok = false, msg = "Nothing to buy."} end
  if cost > MWF.garage.wallet() then
    return {ok = false, msg = string.format("Not enough bounty: the parts cost $%d, you have $%d.", cost, math.floor(MWF.garage.wallet()))}
  end
  -- the price guard around setPartsTreeConfig (economy/garage.lua) takes the money
  local ok, err = pcall(core_vehicle_partmgmt.setPartsTreeConfig, tree, true)
  if not ok then return {ok = false, msg = "Could not change parts: " .. tostring(err):sub(1, 80)} end
  return {ok = true, msg = cost > 0 and string.format("Parts installed for $%d.", cost) or "Parts installed (you already own them).", wallet = math.floor(MWF.garage.wallet())}
end

-- ===== tuning =====
local function listOf(t) -- the page sends lists; they arrive as arrays, or as tables keyed 1..n
  local out = {}
  if type(t) == 'table' then
    for i = 1, #t do out[i] = t[i] end
    if #out == 0 then for _, v in pairs(t) do out[#out + 1] = v end end
  end
  return out
end
-- The car's tuning variables (the same ones the game's tuning screen and the RLS tuning menu edit: suspension, tyre pressure, gear
-- ratios, boost, ...), plus saved tunes per car model (what RLS calls saved tunes). It is free: tuning only changes variables on the
-- car you already own, never its parts. The page edits "display" values; the maths below is the game's own raw <-> display conversion.
local TUNES_FILE = "/settings/mwf_tunes.json"

local function tuneCtx()
  local _, id = MWF.util.getPlayerVeh()
  local vd = id and extensions.core_vehicle_manager.getVehicleData(id)
  local vars = vd and vd.vdata and vd.vdata.variables
  if type(vars) ~= 'table' then return nil end
  return vd, vars
end

local function decimalsOf(step)
  step = tonumber(step) or 1
  for n = 0, 5 do
    if math.abs(step * 10 ^ n - math.floor(step * 10 ^ n + 0.5)) < 1e-9 then return n end
  end
  return 5
end

local function rawToDis(v, raw)
  local span = v.max - v.min
  local t = span ~= 0 and (raw - v.min) / span or 0
  local d = t * (v.maxDis - v.minDis)
  local step = tonumber(v.stepDis) or 0
  if step > 0 then d = math.floor(d / step + 0.5) * step end
  local n = decimalsOf(step)
  return tonumber(string.format("%." .. n .. "f", d + v.minDis))
end

local function disToRaw(v, dis)
  local span = v.maxDis - v.minDis
  local t = span ~= 0 and (dis - v.minDis) / span or 0
  return t * (v.max - v.min) + v.min
end

local function tunable(v)
  return type(v) == 'table' and not v.hideInUI and tonumber(v.min) and tonumber(v.max) and tonumber(v.minDis) and tonumber(v.maxDis)
    and tonumber(v.val) ~= nil
end

function M.shopTuning()
  local vd, vars = tuneCtx()
  if not vd then return {error = "No vehicle data. Get in your car first.", categories = {}} end
  local shown = deepcopy(vars)
  pcall(function() shown = core_vehicle_partmgmt.translateTuningData(shown) end) -- readable titles, categories
  local cats, order = {}, {}
  for name, v in pairs(shown) do
    if tunable(v) then
      local cat, sub = tostring(v.category or "Other"), tostring(v.subCategory or "Other")
      local c = cats[cat]
      if not c then c = {name = cat, subs = {}, byName = {}} cats[cat] = c table.insert(order, c) end
      local sc = c.byName[sub]
      if not sc then sc = {name = sub, vars = {}} c.byName[sub] = sc table.insert(c.subs, sc) end
      table.insert(sc.vars, {name = tostring(v.name or name), title = tostring(v.title or name), desc = v.description and tostring(v.description) or "",
        unit = v.unit and tostring(v.unit) or "", minDis = v.minDis, maxDis = v.maxDis, stepDis = tonumber(v.stepDis) or 1,
        decimals = decimalsOf(v.stepDis), valDis = rawToDis(v, v.val), defDis = rawToDis(v, tonumber(v.default) or v.val)})
    end
  end
  table.sort(order, function(a, b) return a.name < b.name end)
  for _, c in ipairs(order) do
    c.byName = nil
    table.sort(c.subs, function(a, b) return a.name < b.name end)
    for _, sc in ipairs(c.subs) do table.sort(sc.vars, function(a, b) return a.title < b.title end) end
  end
  return {categories = order, vehicle = M.shopVehicleName()}
end

-- values = a list of {name = variable name, v = display value} (a list, because names like "$fuel" are awkward table keys to send); the car is rebuilt with them
function M.shopTuneApply(values)
  local vd, vars = tuneCtx()
  if not vd or type(values) ~= 'table' then return {ok = false, msg = "No vehicle data."} end
  local raw, n = {}, 0
  for _, e in ipairs(listOf(values)) do
    local name, dis = e.name, e.v
    local v = vars[name]
    if tunable(v) and tonumber(dis) then
      local r = disToRaw(v, tonumber(dis))
      raw[name] = math.max(math.min(v.min, v.max), math.min(math.max(v.min, v.max), r))
      n = n + 1
    end
  end
  if n == 0 then return {ok = false, msg = "Nothing to change."} end
  local ok, err = pcall(core_vehicle_partmgmt.setConfigVars, raw)
  if not ok then return {ok = false, msg = "Could not tune: " .. tostring(err):sub(1, 80)} end
  MWF.achievements.add('tunesApplied', 1)
  return {ok = true, msg = string.format("Tune applied (%d setting%s).", n, n == 1 and "" or "s")}
end

-- back to the car's own defaults (the values in its jbeam), for every variable
function M.shopTuneDefaults()
  local vd, vars = tuneCtx()
  if not vd then return {ok = false, msg = "No vehicle data."} end
  local raw = {}
  for name, v in pairs(vars) do
    if tunable(v) and tonumber(v.default) then raw[name] = tonumber(v.default) end
  end
  local ok, err = pcall(core_vehicle_partmgmt.setConfigVars, raw)
  if not ok then return {ok = false, msg = "Could not reset: " .. tostring(err):sub(1, 80)} end
  return {ok = true, msg = "Tuning reset to the car's defaults."}
end

-- saved tunes, per car model
local function loadTunes()
  local ok, data = pcall(jsonReadFile, TUNES_FILE)
  if ok and type(data) == 'table' and type(data.models) == 'table' then return data end
  return {models = {}}
end
local function modelKey()
  local vd = tuneCtx()
  return vd and tostring(vd.model or "") or ""
end
local function tuneList(data, key)
  local out = {}
  for _, t in ipairs(data.models[key] or {}) do
    local n = 0
    for _ in pairs(t.vars or {}) do n = n + 1 end
    out[#out + 1] = {id = t.id, name = t.name, count = n}
  end
  return out
end

function M.shopTunes()
  return {tunes = tuneList(loadTunes(), modelKey())}
end

function M.shopSaveTune(name, values)
  local vd, vars = tuneCtx()
  name = tostring(name or ""):gsub("^%s+", ""):gsub("%s+$", "")
  if not vd or name == "" or type(values) ~= 'table' then return {ok = false, msg = "Give the tune a name."} end
  local raw = {}
  for _, e in ipairs(listOf(values)) do
    local v = vars[e.name]
    if tunable(v) and tonumber(e.v) then raw[e.name] = disToRaw(v, tonumber(e.v)) end
  end
  local data, key = loadTunes(), modelKey()
  data.models[key] = data.models[key] or {}
  local list, replaced = data.models[key], false
  for _, t in ipairs(list) do
    if t.name:lower() == name:lower() then t.vars, t.time, replaced = raw, os.time(), true end
  end
  if not replaced then list[#list + 1] = {id = tostring(os.time()) .. tostring(math.random(1000, 9999)), name = name, vars = raw, time = os.time()} end
  if not pcall(jsonWriteFile, TUNES_FILE, data, true) then return {ok = false, msg = "Could not save the tune."} end
  return {ok = true, msg = (replaced and "Updated tune " or "Saved tune ") .. name, tunes = tuneList(data, key)}
end

-- returns the display values of a saved tune; the page puts them in its edits and the player presses Apply
function M.shopLoadTune(id)
  local vd, vars = tuneCtx()
  if not vd then return {ok = false, msg = "No vehicle data."} end
  for _, t in ipairs(loadTunes().models[modelKey()] or {}) do
    if t.id == id then
      local values = {}
      for varName, raw in pairs(t.vars or {}) do
        local v = vars[varName]
        if tunable(v) and tonumber(raw) then values[varName] = rawToDis(v, tonumber(raw)) end
      end
      return {ok = true, values = values, msg = "Loaded tune " .. t.name .. ". Press Apply to use it."}
    end
  end
  return {ok = false, msg = "That tune is gone."}
end

function M.shopDeleteTune(id)
  local data, key = loadTunes(), modelKey()
  local list = data.models[key] or {}
  for i, t in ipairs(list) do
    if t.id == id then table.remove(list, i) break end
  end
  pcall(jsonWriteFile, TUNES_FILE, data, true)
  return {ok = true, tunes = tuneList(data, key)}
end

MWF.garageui = {drawGarage = drawGarage}

return M
