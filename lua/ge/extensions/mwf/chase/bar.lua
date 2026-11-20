-- The reset bar: risky driving (drift / wrong way / speeding) fills it.
local MWF = require('/lua/ge/extensions/mwf/core/registry')
local S = MWF.S
local CFG = require('/lua/ge/extensions/mwf/data/config')

local M = {}

-- ===== reset bar =====
local function addRisk(key, rate, active, dist)
  local r = S.risk[key]
  if active then
    r.d = r.d + dist
    MWF.achievements.add(key .. 'Meters', dist)
    if r.d >= CFG.DIST_THRESHOLD then
      -- first time over the threshold, credit the whole stretch; afterwards only the new distance
      MWF.util.addBar(rate * (r.on and dist or r.d))
      r.on = true
    end
  else
    r.d = 0
    r.on = false
  end
end

local function updateBar(dtSim, veh, id)
  if os.clock() < S.riskPauseUntil or S.breaker or dtSim > 0.25 then MWF.util.resetRisk() return end
  local vel = veh:getVelocity()
  local speed = math.min(vel:length(), 150) -- m/s; reject physics spikes
  local dist = math.min(speed * dtSim, 4)    -- metres this frame, sanity-capped

  -- drifting: velocity direction diverges from where the car points
  local drifting = false
  if speed > CFG.DRIFT_MIN_SPEED then
    local fwd = veh:getDirectionVector()
    local cosA = (fwd.x * vel.x + fwd.y * vel.y + fwd.z * vel.z) / speed
    cosA = math.max(-1, math.min(1, cosA))
    drifting = math.acos(cosA) > CFG.DRIFT_MIN_ANGLE and cosA > -0.2 -- ignore reversing
  end

  local wrongWay = false
  if gameplay_traffic and gameplay_traffic.getTrafficData then
    local tv = gameplay_traffic.getTrafficData()[id]
    local tr = tv and tv.tracking
    if tr and tr.faults and tr.sideValue and tr.sideValue < 0 and (tr.faults.wrongWay or 0) >= 0.25 then
      wrongWay = true
    end
  end

  addRisk('drift', CFG.DRIFT_RATE, drifting, dist)
  addRisk('wrongWay', CFG.WRONGWAY_RATE, wrongWay, dist)
  addRisk('speeding', CFG.SPEEDING_RATE, speed > MWF.util.speedingMs(), dist)
end

MWF.bar = {updateBar = updateBar}

return M
