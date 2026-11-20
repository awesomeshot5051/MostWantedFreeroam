-- Per-frame pursuit scoring: bounty awards, wreck payouts, heat changes.
local MWF = require('/lua/ge/extensions/mwf/core/registry')
local S = MWF.S
local CFG = require('/lua/ge/extensions/mwf/data/config')
local UNITS = require('/lua/ge/extensions/mwf/data/units')

local M = {}

-- ===== pursuit / heat =====
local OFFENSE_LABELS = {
  speeding = "Speeding", racing = "Street racing", reckless = "Reckless driving",
  wrongWay = "Driving wrong way", intersection = "Ran a red light", hitPolice = "Hit a police car", hitTraffic = "Hit traffic",
}

-- Pay out bounty for an event. Repeating the same source pays less and less; the penalty fades with time.
local function award(key, text, base, floor, ceil)
  -- only traffic offenses (speeding, wrong way, ...) get the repeat penalty; destroying/ramming cars and weapon hits never do
  local penalised = key:sub(1, 4) == 'off_' or key == 'repeatOffense'
  local n = penalised and (S.recent[key] or 0) or 0
  local mult = math.max(CFG.MIN_MULT, CFG.REPEAT_FALLOFF ^ n)
  local amount = base * mult
  if floor then amount = math.max(floor, amount) end
  if ceil then amount = math.min(ceil, amount) end
  if penalised then S.recent[key] = n + 1 end
  local gained = amount * MWF.util.bountyScale() -- RLS career: much smaller bounty
  S.session.bounty = S.session.bounty + gained
  MWF.util.addBar(amount * CFG.PASSIVE_BOUNTY_PCT) -- the bar refills as if bounty were not scaled
  table.insert(S.feed, 1, {text = text, amount = gained, mult = mult, t = os.clock()})
  while #S.feed > CFG.FEED_LINES do table.remove(S.feed) end
  return gained
end

-- what wrecking a given police car is worth: grows with the heat level the unit belongs to, and with its class (semis, armed units)
local HEAVY_MODELS = {us_semi = 1.5, van = 1.25}
local function wreckValue(pid)
  local info = S.esc.info[pid]
  local heat, mult, label = 1, 1, "Police car smashed"
  if info then
    heat, mult, label = info.heat, info.mult, info.label .. " smashed"
  else
    local o = getObjectByID(pid)
    mult = (o and HEAVY_MODELS[o.jbeam]) or 1
  end
  local amount = math.min(CFG.WRECK_MAX, (CFG.WRECK_BASE + CFG.WRECK_PER_HEAT * (heat - 1)) * mult)
  return amount, label
end

local function updatePursuit(dtSim, pd, id)
  local s = S.session

  -- repeat penalties fade
  for k, v in pairs(S.recent) do
    S.recent[k] = v - dtSim / CFG.REPEAT_DECAY
    if S.recent[k] <= 0 then S.recent[k] = nil end
  end

  -- steady income just for staying alive (shown as a rate, not as feed spam)
  local live = MWF.util.pursuitRate(s.heat) * dtSim
  s.bounty = s.bounty + live
  s.timeBounty = s.timeBounty + live
  MWF.util.addBar((CFG.PURSUIT_RATE[s.heat] or CFG.PURSUIT_RATE[1]) * dtSim * CFG.PASSIVE_BOUNTY_PCT)

  local traffic = gameplay_traffic and gameplay_traffic.getTrafficData and gameplay_traffic.getTrafficData()
  local tv = traffic and traffic[id]

  -- collisions: who did you hit?
  local hits = pd.hitCount or 0
  if hits > s.lastHits then
    local now = os.clock()
    if tv and tv.collisions then
      for vid, coll in pairs(tv.collisions) do
        if coll.dot and coll.dot >= 0.2 and (not S.seenColl[vid] or now - S.seenColl[vid] > 1.5) then
          local other = traffic[vid]
          if other then
            S.seenColl[vid] = now
            if other.role and other.role.name == 'police' then
              S.stats.hitPolice = S.stats.hitPolice + 1
              award('hitPolice', "Rammed a police car", CFG.BOUNTY_PER_HIT)
            else
              award('hitTraffic', "Hit traffic", CFG.BOUNTY_PER_TRAFFIC)
            end
          end
        end
      end
    end
  end
  s.lastHits = hits

  -- offenses: new unique ones are named; repeats of an already-recorded offense still pay (diminished)
  if pd.offenses then
    for key, data in pairs(pd.offenses) do
      if key ~= 'hitPolice' and key ~= 'hitTraffic' and not S.seenOffenses[key] then
        S.seenOffenses[key] = true
        award('off_' .. key, OFFENSE_LABELS[key] or key, ((type(data) == 'table' and data.score) or 100) * CFG.OFFENSE_MULT)
      end
    end
  end
  local oc = pd.offensesCount or 0
  if oc > s.lastOffCount and pd.offenses then
    local unique = 0
    for _ in pairs(pd.offenses) do unique = unique + 1 end
    -- offenses beyond the unique ones are repeats of something we already paid for
    if oc - unique > (s.repeatPaid or 0) then
      s.repeatPaid = oc - unique
      award('repeatOffense', "Repeat offense", 100 * CFG.OFFENSE_MULT * 0.5)
    end
  end
  s.lastOffCount = oc

  -- police cars: count who is still in the chase, and credit every one put out of action
  local present = 0
  if gameplay_police and gameplay_police.getPoliceVehicles then
    for pid, pveh in pairs(gameplay_police.getPoliceVehicles()) do
      local obj = getObjectByID(pid)
      local disabled = pveh.role and pveh.role.state == 'disabled'
      if disabled and not s.wrecked[pid] then
        s.wrecked[pid] = true
        S.stats.wrecked = S.stats.wrecked + 1
        local amount, label = wreckValue(pid)
        local gunKill = os.clock() - S.lastGunFire < CFG.GUN_CREDIT_WINDOW
        local tag = s.weaponTag[pid]
        if not (tag and os.clock() - tag < CFG.WEAPON_TAG_WINDOW) then -- weapon kills already paid a bigger bounty
          if gunKill then
            -- you were firing a gun when it went down: it pays only a share, so a gun cannot farm bounty
            award('wreck', label .. " (gun kill)", amount * CFG.GUN_WRECK_FRACTION)
          else
            award('wreck', label, amount)
          end
        end
        local ach = MWF.achievements
        ach.add('wrecks', 1)
        ach.max('chaseWrecks', S.stats.wrecked)
        if label:find('semi') then ach.add('semiWrecks', 1) end
        if label:find('Armed') or label:find('Howitzer') then ach.add('armedWrecks', 1) end
        if gunKill and not (tag and os.clock() - tag < CFG.WEAPON_TAG_WINDOW) then ach.add('gunKills', 1) end
      elseif not disabled then
        s.wrecked[pid] = nil
        if obj and obj:getActive() then present = present + 1 end
      end
    end
  end
  S.stats.copsPresent = present

  -- achievement stats that follow the chase as it runs
  s.time = (s.time or 0) + dtSim
  MWF.achievements.max('chaseBounty', math.floor(s.bounty / MWF.util.bountyScale()))
  MWF.achievements.max('chaseSeconds', math.floor(s.time))
  MWF.achievements.max('copsAtOnce', present)

  local heat = math.max(1, MWF.util.heatForBounty(s.bounty))
  if heat ~= s.heat then
    if heat > s.heat then
      local note = UNITS.HEAT_GROUPS[heat] and UNITS.HEAT_GROUPS[heat].note or "more units"
      guihooks.trigger("toastrMsg", {type = "warning", title = "HEAT " .. heat,
        msg = string.format("Incoming: %s. Pursuit pay now +$%d/s", note, MWF.util.pursuitRate(heat)), config = {timeOut = 3800}})
    end
    s.heat = heat
    MWF.achievements.max('heat', heat)
    MWF.difficulty.applyHeatTuning(heat)
    MWF.escalation.escalateTo(heat)
  end

  -- keep vanilla police pressure in step with our heat level
  local want = CFG.HEAT_TO_MODE[heat] or 1
  if pd.mode and pd.mode > 0 and pd.mode < want and gameplay_police.setPursuitMode then
    pcall(gameplay_police.setPursuitMode, want, id)
  end

  -- passive refill while the chase is on
  MWF.util.addBar((CFG.PASSIVE_BASE + CFG.PASSIVE_PER_HEAT * heat) * dtSim)
end

MWF.pursuit = {award = award, updatePursuit = updatePursuit}

return M
