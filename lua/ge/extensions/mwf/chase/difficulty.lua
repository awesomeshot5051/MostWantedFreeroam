-- Pursuit difficulty: heat scaling (evade / arrest / roadblocks) and police sensitivity to offenses.
local MWF = require('/lua/ge/extensions/mwf/core/registry')
local S = MWF.S

local M = {}

local function applyHeatTuning(heat)
  -- harder police as heat rises; restored when the chase ends
  if not (gameplay_police and gameplay_police.setPursuitVars) then return end
  local base = S.session and S.session.baseVars
  if not base then return end
  pcall(gameplay_police.setPursuitVars, {
    evadeTime = (base.evadeTime or 45) * math.min(2.0, 1 + 0.15 * (heat - 1)),
    arrestTime = math.max(2.5, (base.arrestTime or 5) - 0.4 * (heat - 1)),
    roadblockFrequency = math.min(1, (base.roadblockFrequency or 0.5) + 0.1 * (heat - 1)),
  })
end

local function restoreTuning()
  if S.session and S.session.baseVars and gameplay_police and gameplay_police.setPursuitVars then
    pcall(gameplay_police.setPursuitVars, {
      evadeTime = S.session.baseVars.evadeTime,
      arrestTime = S.session.baseVars.arrestTime,
      roadblockFrequency = S.session.baseVars.roadblockFrequency,
    })
  end
end

-- ===== police sensitivity (option "Police sensitivity") =====
-- Vanilla starts a pursuit once a car's offense score reaches scoreLevels[1] (100), and a single speeding offense is worth
-- exactly 100, so any speeding near a cop starts a chase. Two knobs are scaled by the sensitivity s (1.0 = vanilla):
--   * strictness (how large a fault must be to count as an offense): 0.5 * s, clamped to 0.1 .. 0.8
--   * the score needed to start a pursuit: 100 / s  (s = 0.5 -> 200: speeding alone no longer starts one, but running a red
--     light or speeding plus another offense does; s = 0.25 -> 400; s = 2 -> 50)
-- Only applied outside chases (a running chase always uses vanilla values so its difficulty is unchanged). When s = 1 and
-- this mod never changed anything, other mods' settings are left alone.
local VANILLA_STRICTNESS, VANILLA_START = 0.5, 100
local sensChanged = false
local sensTimer = 0
local sensForce = true

local function sensitivityTarget()
  local s = S.options.sensitivity or 1
  if S.session or math.abs(s - 1) < 0.001 then return VANILLA_STRICTNESS, VANILLA_START end
  return math.max(0.1, math.min(0.8, VANILLA_STRICTNESS * s)), math.floor(VANILLA_START / s + 0.5)
end

local function applySensitivity()
  if not (gameplay_police and gameplay_police.getPursuitVars and gameplay_police.setPursuitVars) then return end
  local strictness, start = sensitivityTarget()
  local isVanilla = strictness == VANILLA_STRICTNESS and start == VANILLA_START
  if isVanilla and not sensChanged then return end -- nothing of ours to undo
  local ok, v = pcall(gameplay_police.getPursuitVars)
  if not ok or type(v) ~= 'table' then return end
  local levels = v.scoreLevels or {VANILLA_START, 500, 2000}
  if v.strictness == strictness and levels[1] == start then
    if isVanilla then sensChanged = false end
    return
  end
  local newLevels = {start, levels[2] or 500, levels[3] or 2000}
  pcall(gameplay_police.setPursuitVars, {strictness = strictness, scoreLevels = newLevels})
  sensChanged = not isVanilla
  log('I', 'mwf', string.format('Police sensitivity %.2f: strictness %.2f, pursuit starts at score %d', S.options.sensitivity or 1, strictness, start))
end

-- called every frame; re-checks every couple of seconds (vanilla resets its variables on level load, and a chase end switches back)
local function tickSensitivity(dtReal)
  sensTimer = sensTimer + dtReal
  if sensForce or sensTimer >= 2 then
    sensTimer = 0
    sensForce = false
    applySensitivity()
  end
end
local function refreshSensitivity() sensForce = true end

MWF.difficulty = {applyHeatTuning = applyHeatTuning, restoreTuning = restoreTuning, tickSensitivity = tickSensitivity,
  refreshSensitivity = refreshSensitivity}

return M
