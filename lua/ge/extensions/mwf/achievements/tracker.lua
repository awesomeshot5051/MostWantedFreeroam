-- Custom in-game achievements. (Steam / EOS achievements cannot be added by a mod; they are a fixed list inside the game.)
-- Other modules report what happened with two calls:
--   MWF.achievements.add(stat, n)    accumulate (wrecks, metres drifted, ...)
--   MWF.achievements.max(stat, v)    keep the best value (heat reached, bounty in one chase, ...)
-- An achievement unlocks when its stat reaches its goal (data/achievements.lua). Progress is saved to /settings/mwf_achievements.json.
local MWF = require('/lua/ge/extensions/mwf/core/registry')
local S = MWF.S
local ACH = require('/lua/ge/extensions/mwf/data/achievements')

local M = {}
local FILE = "/settings/mwf_achievements.json"
local AUTOSAVE_EVERY = 30 -- s, while there is unsaved progress

local byStat = {}
for _, a in ipairs(ACH.LIST) do
  byStat[a.stat] = byStat[a.stat] or {}
  table.insert(byStat[a.stat], a)
end

local function save()
  pcall(jsonWriteFile, FILE, {stats = S.ach.stats, unlocked = S.ach.unlocked}, true)
  S.ach.dirty = false
end

local function load()
  S.ach.loaded = true
  local ok, data = pcall(jsonReadFile, FILE)
  if ok and type(data) == 'table' then
    if type(data.stats) == 'table' then S.ach.stats = data.stats end
    if type(data.unlocked) == 'table' then S.ach.unlocked = data.unlocked end
  end
end

local function unlock(a)
  S.ach.unlocked[a.id] = os.time()
  table.insert(S.ach.banners, {a = a, t = os.clock()})
  guihooks.trigger("toastrMsg", {type = "success", title = "ACHIEVEMENT UNLOCKED", msg = a.name .. "  -  " .. ACH.descOf(a, MWF.util.unitSystem()), config = {timeOut = 7000}})
  log('I', 'mwf', 'Achievement unlocked: ' .. a.name)
  save()
end

local function check(stat)
  local v = S.ach.stats[stat] or 0
  local system = MWF.util.unitSystem()
  for _, a in ipairs(byStat[stat] or {}) do
    if not S.ach.unlocked[a.id] and v >= ACH.goalOf(a, system) then unlock(a) end
  end
end

local function add(stat, n)
  if not S.ach.loaded then load() end
  S.ach.stats[stat] = (S.ach.stats[stat] or 0) + n
  S.ach.dirty = true
  check(stat)
end

local function max(stat, v)
  if not S.ach.loaded then load() end
  if v > (S.ach.stats[stat] or 0) then
    S.ach.stats[stat] = v
    S.ach.dirty = true
    check(stat)
  end
end

local function tick(dtReal)
  if not S.ach.loaded then load() end
  S.ach.saveTimer = S.ach.saveTimer + dtReal
  if S.ach.dirty and S.ach.saveTimer >= AUTOSAVE_EVERY then
    S.ach.saveTimer = 0
    save()
  end
end

local function flush()
  if S.ach.dirty then save() end
end

function M.toggleAchievements() S.ach.show[0] = not S.ach.show[0] end

MWF.achievements = {add = add, max = max, tick = tick, flush = flush, load = load}

return M
