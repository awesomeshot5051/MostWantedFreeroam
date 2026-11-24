-- Style bonuses (Forza Horizon style), paid into the bounty while a chase is on:
--   * Drift:         our own Forza-style counter (vanilla BeamNG's is far too insensitive): a drift starts at a small slip
--                    angle, scores by angle and speed, and a combo multiplier grows with time and with direction changes.
--                    Banked when you straighten out, and also on a spinout. A crash forfeits it. Circling in place decays fast.
--                    The bounty is 10 x the counter.
--   * Near miss:     passing a car (traffic or police) closely at speed without touching it. Back-to-back ones chain.
--   * Trading paint: a glancing side-swipe against another car at speed. Back-to-back ones chain.
--   * "Dodged a missile" achievements: a near miss with a police car that was charging straight at you.
local MWF = require('/lua/ge/extensions/mwf/core/registry')
local S = MWF.S

local M = {}

local MPH = 0.44704
local DRIFT_BOUNTY_MULT = 10     -- bounty per drift point

local NEAR_MISS_BASE   = 250     -- bounty for the first near miss of a chain
local PAINT_BASE       = 300     -- bounty for the first paint trade of a chain
local CHAIN_STEP       = 0.5     -- every further link adds this share of the base
local CHAIN_MAX        = 8       -- the multiplier stops growing at this many links
local CHAIN_WINDOW     = 5       -- s: the next one must come within this long to extend the chain

local NEAR_MISS_GAP    = 1.3     -- m between the two bodies at the closest point (bigger = not a near miss)
local NEAR_MISS_SPEED  = 10      -- m/s: your own minimum speed (about 22 mph)
local NEAR_MISS_REL    = 8       -- m/s: minimum speed of the two cars relative to each other
local TRACK_RANGE      = 30      -- m: other cars are watched inside this distance
local PAINT_MIN_SPEED  = 6       -- m/s: your speed at the moment of contact
local PAINT_MAX_DOT    = 0.2     -- contact more head-on than this is a "hit", paid by the pursuit module (and not here)

-- "Dodged a missile": the police car's own speed while it was heading straight at you
local MISSILE_COS      = 0.8     -- how directly it must be aimed at you (1 = dead on)
local MISSILE_MIN_MPH  = 60      -- below this it is not a missile at all

local function now() return os.clock() end

local newDrift
local function newStyle()
  return {track = {}, paint = {}, nm = {n = 0, t = -1e9}, tp = {n = 0, t = -1e9}, drift = nil}
end

local function style()
  local s = S.session
  if not s then return nil end
  s.style = s.style or newStyle()
  s.style.drift = s.style.drift or newDrift()
  return s.style
end

-- extends or restarts a chain and returns its multiplier
local function link(chain)
  local t = now()
  chain.n = (t - chain.t <= CHAIN_WINDOW) and chain.n + 1 or 1
  chain.t = t
  return 1 + CHAIN_STEP * (math.min(chain.n, CHAIN_MAX) - 1), chain.n
end

local function pay(key, label, base, chain)
  local mult, n = link(chain)
  MWF.pursuit.award(key, n > 1 and string.format("%s x%d", label, n) or label, base * mult)
end

-- ===== drift =====
-- Detection (much more sensitive than vanilla): the car's velocity points DRIFT_MIN_ANGLE or more away from where it faces.
local DRIFT_MIN_ANGLE  = math.rad(10)  -- slip angle that starts / keeps a drift
local DRIFT_MAX_ANGLE  = math.rad(60)  -- angle at which the angle bonus tops out
local DRIFT_SPIN_ANGLE = math.rad(100) -- beyond this the car is spinning, not drifting
local DRIFT_MIN_SPEED  = 7             -- m/s (about 16 mph)
local DRIFT_START_HOLD = 0.25          -- s you must hold the angle before the drift counts
local DRIFT_GRACE      = 1.0           -- s you may straighten out before the drift is banked (so you can link drifts)
local DRIFT_CRASH_DECEL = 30           -- m/s^2 of sudden braking while drifting = you hit something: the drift is lost
local DRIFT_RATE       = 12            -- counter points per second at "average" angle and speed
local DRIFT_BANK_MIN   = 100           -- smaller drifts are not paid
local DRIFT_BOUNTY_CAP = 25000         -- the most one drift can pay (before RLS scaling)
-- the combo multiplier: +0.25 per second of drifting, +0.5 for every change of direction while linked, capped
local COMBO_PER_SEC, COMBO_PER_FLIP, COMBO_MAX = 0.25, 0.5, 5
-- circling: after this much net turning in one drift chain the rate falls off, so a donut cannot be farmed
local CIRCLE_FREE_ROT  = math.rad(270)
local CIRCLE_FALLOFF   = math.rad(540) -- further turning that takes the rate down to its floor
local CIRCLE_FLOOR     = 0.05

newDrift = function() return {state = 'idle', pts = 0, combo = 1, hold = 0, grace = 0, rot = 0, maxRot = 0, dir = 0, t = 0} end

local function bankDrift(st, why)
  local d = st.drift
  local pot = math.floor(d.pts * d.combo)
  st.drift = newDrift()
  if why == 'crash' then
    if pot >= DRIFT_BANK_MIN then MWF.util.toast("warning", "Drift lost", "You hit something", 1800) end
    return
  end
  if pot < DRIFT_BANK_MIN then return end
  local label = string.format(why == 'spinout' and "Drift (spun out)  %d pts" or "Drift  %d pts", pot)
  -- repeats fade like traffic offenses do ('off_' keys), so chaining drift after drift pays a bit less each time
  local amount = math.min(DRIFT_BOUNTY_CAP, pot * DRIFT_BOUNTY_MULT)
  MWF.pursuit.award('off_drift', label, amount)
  MWF.achievements.add('drifts', 1)
end

local function updateDrift(dtSim, veh, st)
  local d = st.drift
  local vel = veh:getVelocity()
  local speed = math.sqrt(vel.x * vel.x + vel.y * vel.y)
  local fwd = veh:getDirectionVector()
  local f = math.sqrt(fwd.x * fwd.x + fwd.y * fwd.y)
  local slip, dir, turn = 0, 0, 0
  if speed > 1 and f > 0.1 then
    local fx, fy = fwd.x / f, fwd.y / f
    local vx, vy = vel.x / speed, vel.y / speed
    local dot, cross = fx * vx + fy * vy, fx * vy - fy * vx
    slip = math.atan2(math.abs(cross), dot) -- 0 = straight ahead, pi = reversing
    dir = cross >= 0 and 1 or -1
    if d.pvx then turn = math.atan2(d.pvx * vy - d.pvy * vx, d.pvx * vx + d.pvy * vy) end -- how far the travel direction swung this frame
    d.pvx, d.pvy = vx, vy
  else
    d.pvx, d.pvy = nil, nil
  end
  local decel = d.lastSpeed and dtSim > 0 and (d.lastSpeed - speed) / dtSim or 0
  d.lastSpeed = speed

  local sliding = speed >= DRIFT_MIN_SPEED and slip >= DRIFT_MIN_ANGLE and slip < DRIFT_SPIN_ANGLE

  if d.state == 'idle' then
    d.hold = sliding and d.hold + dtSim or 0
    if d.hold >= DRIFT_START_HOLD then
      d.state, d.t, d.dir, d.lastDir = 'drifting', 0, dir, dir
      d.rot, d.maxRot = 0, 0
    end
    return
  end

  -- a drift is running (state 'drifting', or 'grace' while the car is momentarily straight)
  if decel > DRIFT_CRASH_DECEL and d.state == 'drifting' then bankDrift(st, 'crash') return end
  if slip >= DRIFT_SPIN_ANGLE or (speed < 3 and d.t > 0) then bankDrift(st, 'spinout') return end

  if sliding then
    if d.state == 'grace' then d.state, d.grace = 'drifting', 0 end
    d.t = d.t + dtSim
    if dir ~= d.lastDir then -- swung the other way: a transition, which is what Forza rewards most
      d.combo = math.min(COMBO_MAX, d.combo + COMBO_PER_FLIP)
      d.lastDir = dir
    end
    d.rot = d.rot + turn
    d.maxRot = math.max(d.maxRot, math.abs(d.rot))
    local angleF = 0.4 + 1.1 * math.min(1, (slip - DRIFT_MIN_ANGLE) / (DRIFT_MAX_ANGLE - DRIFT_MIN_ANGLE))
    local speedF = math.max(0.4, math.min(2.2, speed / 25))
    local circleF = 1
    if d.maxRot > CIRCLE_FREE_ROT then
      circleF = math.max(CIRCLE_FLOOR, 1 - (d.maxRot - CIRCLE_FREE_ROT) / CIRCLE_FALLOFF)
    end
    d.pts = d.pts + DRIFT_RATE * angleF * speedF * circleF * dtSim
    if circleF >= 0.99 then d.combo = math.min(COMBO_MAX, d.combo + COMBO_PER_SEC * dtSim) end -- no combo for going round in circles
    d.circleF = circleF
  else
    d.state = 'grace'
    d.grace = d.grace + dtSim
    if d.grace >= DRIFT_GRACE then bankDrift(st, 'done') end
  end
end

-- ===== near misses, trading paint, missiles =====
local function widthOf(obj, tv)
  if tv and tv.width then return tv.width end
  local w = 1.9
  pcall(function() w = obj:getInitialWidth() end)
  return w
end

local function isPolice(tv)
  return tv and tv.role and tv.role.name == 'police'
end

local function scanOthers(dtSim, veh, id, st)
  local traffic = gameplay_traffic and gameplay_traffic.getTrafficData and gameplay_traffic.getTrafficData()
  if not traffic then return end
  local ptv = traffic[id]
  local pp, pv = veh:getPosition(), veh:getVelocity()
  local pSpeed = pv:length()
  local pw = widthOf(veh, ptv)
  local t = now()
  local seen = {}

  for vid, o in pairs(traffic) do
    if vid ~= id and o.pos and not o.isPerson and (not isPolice(o) or not (S.session.wrecked and S.session.wrecked[vid])) then
      local rel = o.pos - pp
      local d = rel:length()
      if d < TRACK_RANGE then
        seen[vid] = true
        local tr = st.track[vid]
        local firstSight = false
        if not tr then
          tr = {minD = d, rel = 0, threat = 0, done = false, touched = false}
          st.track[vid] = tr
          firstSight = true
        end
        local ov = o.vel or vec3(0, 0, 0)
        local vrel = ov - pv
        local closing = d > 0.01 and -(rel:dot(vrel)) / d or 0
        if d < tr.minD then
          tr.minD, tr.rel = d, vrel:length()
        end
        -- how fast is this car coming straight at us?
        local os_ = ov:length()
        if os_ > 5 and d > 0.5 and closing > 0 and (-(rel:dot(ov)) / (os_ * d)) > MISSILE_COS then
          tr.threat = math.max(tr.threat, os_)
        end
        if d < 0.5 * (pw + widthOf(nil, o)) + 0.25 then tr.touched = true end

        -- closest point passed: the two cars are drawing apart again
        if not tr.done and closing < -0.5 then
          tr.done = true
          local gap = tr.minD - 0.5 * (pw + widthOf(nil, o))
          local rubbed = st.paint[vid] and t - st.paint[vid].t < 3 -- we scraped it a moment ago: that is not a miss
          if not tr.touched and not rubbed
            and gap > 0 and gap <= NEAR_MISS_GAP and pSpeed >= NEAR_MISS_SPEED and tr.rel >= NEAR_MISS_REL then
            pay('style_nearmiss', "Near miss", NEAR_MISS_BASE, st.nm)
            MWF.achievements.add('nearMisses', 1)
            if isPolice(o) and tr.threat >= MISSILE_MIN_MPH * MPH then
              MWF.achievements.max('missileDodgeMph', math.floor(tr.threat / MPH))
              MWF.util.toast("success", "DODGED A MISSILE", string.format("A police car came at you at %d mph", math.floor(tr.threat / MPH)), 3000)
            end
          end
        end

        -- trading paint: a new contact that is a glancing, side-on one
        local coll = ptv and ptv.collisions and ptv.collisions[vid]
        if coll then
          local rec = st.paint[vid]
          -- a contact that was already there when this car first came into range is old news; a car that was being watched and then touched is a new contact
          if not rec then rec = {count = firstSight and (coll.count or 0) or 0, t = -1e9}; st.paint[vid] = rec end
          if (coll.count or 0) > rec.count then
            rec.count = coll.count
            rec.t = t
            if (coll.dot or 1) < PAINT_MAX_DOT and (coll.speed or 0) >= PAINT_MIN_SPEED then
              pay('style_paint', "Trading paint", PAINT_BASE, st.tp)
              MWF.achievements.add('paintTrades', 1)
            end
          end
        end
      end
    end
  end

  -- forget cars that left the area (so passing the same car again later can count again)
  for vid, tr in pairs(st.track) do
    if not seen[vid] then st.track[vid] = nil end
  end
  for vid in pairs(st.paint) do
    if not traffic[vid] then st.paint[vid] = nil end
  end
end

local DANGER_SPEED = 100 * MPH -- "Highway to the Danger Zone": seconds in a row above this

local function updateStyle(dtSim, veh, id)
  if not S.session or dtSim <= 0 or dtSim > 0.25 then return end
  local st = style()
  if S.breaker or veh:getVelocity():length() < DANGER_SPEED then
    st.fastT = 0
  else
    st.fastT = (st.fastT or 0) + dtSim
    MWF.achievements.max('fastSeconds', math.floor(st.fastT))
  end
  if S.breaker then st.drift = newDrift() else updateDrift(dtSim, veh, st) end
  scanOthers(dtSim, veh, id, st)
end

MWF.style = {updateStyle = updateStyle}

return M
