-- The achievement list. Each entry unlocks when its stat reaches `goal`.
--   stat : the counter it watches (see achievements/tracker.lua; "add" stats accumulate over all chases, "max" stats keep the best value)
--   fmt  : how the progress is shown ("dist" = the stat is in metres, shown in km or miles; "money"; "time" = seconds; default plain number)
--   dist : {metric = km, imperial = miles}: the goal in the player's unit system (the game's "uiUnitLength" setting). The description
--          is a format string: first %s = that distance, second %s = the speed from `speed` ({metric = "200 km/h", imperial = "125 mph"}).
--   reward : optional {bounty, money, points}: paid when it unlocks. bounty = added to the chase bounty (scaled down in RLS); money and
--            points are RLS only: real money, and Most Wanted Criminal milestone points.
local LIST = {
  -- first steps
  {id = "firstChase",  name = "You can run but you can't hide!",  desc = "Trigger a pursuit",                               stat = "chases",       goal = 1},
  {id = "firstWreck",  name = "Serve and Protect (Yourself)",     desc = "Wreck your first police car",                     stat = "wrecks",       goal = 1},
  {id = "heat3",       name = "Now We're Cooking",                desc = "Reach heat 3",                                    stat = "heat",         goal = 3},
  -- heat
  {id = "heat6",       name = "That's a lot of cops!",            desc = "Reach heat 6",                                    stat = "heat",         goal = 6},
  {id = "heat10",      name = "Public Enemy Number One",          desc = "Reach heat 10",                                   stat = "heat",         goal = 10},
  {id = "cops10",      name = "Is This a Parade?",                desc = "Have 10 police cars on you at the same time",    stat = "copsAtOnce",   goal = 10},
  -- escaping and getting caught
  {id = "escape5",     name = "You're still wanted. We just gave up the chase", desc = "Escape the police with a heat level of 5 or more", stat = "escapeHeat", goal = 5},
  {id = "escapes10",   name = "Now You See Me, Now You Don't",    desc = "Escape 10 chases",                                stat = "escapes",      goal = 10},
  {id = "busts5",      name = "Frequent Flyer",                   desc = "Get busted 5 times",                              stat = "busts",        goal = 5},
  {id = "marathon",    name = "Still Going, Officer?",            desc = "Survive a single chase for 15 minutes",           stat = "chaseSeconds", goal = 900, fmt = "time"},
  -- bounty
  {id = "bounty100k",  name = "Pocket Change",                    desc = "Reach a bounty of $100,000 in one chase",         stat = "chaseBounty",  goal = 100000, fmt = "money"},
  {id = "bounty500k",  name = "Now that's a big bounty",          desc = "Reach a bounty of $500,000",                      stat = "chaseBounty",  goal = 500000, fmt = "money"},
  {id = "bounty1m",    name = "You're a millionaire now!",        desc = "Reach a bounty of $1,000,000",                    stat = "chaseBounty",  goal = 1000000, fmt = "money"},
  -- destruction
  {id = "wreck100",    name = "You're a monster!",                desc = "Blow up 100 cops during a pursuit",               stat = "chaseWrecks",  goal = 100},
  {id = "wreck500",    name = "Donut Shortage",                   desc = "Wreck 500 police cars in total",                  stat = "wrecks",       goal = 500},
  {id = "semi",        name = "Big Rig Down",                     desc = "Wreck a special pursuit semi",                    stat = "semiWrecks",   goal = 1},
  {id = "armed",       name = "Disarming Personality",            desc = "Wreck an armed police unit",                      stat = "armedWrecks",  goal = 1},
  {id = "knights",     name = "Michael Knight Would Be Proud",    desc = "Be chased by both KARR and KITT in the same chase", stat = "knightsMet", goal = 2},
  -- weapons
  {id = "emp",         name = "Lights Out!",                      desc = "Fire the EMP",                                    stat = "empUses",      goal = 1},
  {id = "gunKills",    name = "Spray and Pray",                   desc = "Take out 25 police cars with a gun",              stat = "gunKills",     goal = 25},
  {id = "weapons50",   name = "Arms Dealer",                      desc = "Use 50 weapons during chases",                    stat = "weaponUses",   goal = 50},
  -- driving
  {id = "drift",       name = "Tokyo Drift, Local Edition",       desc = "Drift %s during chases",                        stat = "driftMeters",  goal = 5000, dist = {metric = 5, imperial = 3}, fmt = "dist"},
  {id = "wrongWay",    name = "Wrong Way Wallace",                desc = "Drive %s the wrong way during chases",          stat = "wrongWayMeters", goal = 2000, dist = {metric = 2, imperial = 1}, fmt = "dist"},
  {id = "speeding",    name = "Pedal to the Metal",               desc = "Drive %s above %s during chases",        stat = "speedingMeters", goal = 20000, dist = {metric = 20, imperial = 12}, speed = {metric = "200 km/h", imperial = "125 mph"}, fmt = "dist"},
  {id = "missile60",   name = "Dodged a Missile",                 desc = "Near-miss a police car charging straight at you at 60 mph (97 km/h) or more", stat = "missileDodgeMph", goal = 60},
  {id = "missile100",  name = "Really Dodged a Missile",          desc = "Near-miss a police car charging straight at you at 100 mph (160 km/h) or more", stat = "missileDodgeMph", goal = 100},
  {id = "nearMiss100", name = "Living on the Edge",               desc = "Get 100 near misses during chases",               stat = "nearMisses",   goal = 100, reward = {bounty = 2500, money = 300, points = 3}},
  {id = "paint100",    name = "Nearly missing the near miss",     desc = "Trade paint 100 times during chases",             stat = "paintTrades",  goal = 100, reward = {bounty = 2500, money = 300, points = 3}},
  {id = "dangerZone",  name = "Highway to the Danger Zone",       desc = "Stay above 100 mph (160 km/h) for 3 minutes in a row", stat = "fastSeconds", goal = 180, fmt = "time", reward = {bounty = 5000, money = 500, points = 5}},
  {id = "resets10",    name = "Nine Lives (Plus One)",            desc = "Use the Crash Breaker 10 times",                  stat = "resets",       goal = 10},
  -- pit stops
  {id = "firstCar",    name = "Trade-In Value: Mostly Smoke",     desc = "Buy a car at a garage during a chase",            stat = "carsBought",   goal = 1},
  {id = "spent100k",   name = "Cash Is Just a Number",            desc = "Spend $100,000 of bounty at garages",             stat = "moneySpent",   goal = 100000, fmt = "money"},
  {id = "pitHeat5",    name = "Quick Oil Change",                 desc = "Visit a garage while at heat 5 or higher",        stat = "garageHeat5",  goal = 1},
}
local KM, MILE = 1000, 1609.344

local function distText(a, system)
  local d = a.dist[system] or a.dist.metric
  if system == "imperial" then return d == 1 and "1 mile" or string.format("%g miles", d) end
  return string.format("%g km", d)
end

-- the description in the player's unit system ("metric" or "imperial")
local function descOf(a, system)
  if not a.dist then return a.desc end
  local sp = a.speed and (a.speed[system] or a.speed.metric) or ""
  return string.format(a.desc, distText(a, system), sp)
end

-- the goal (in the stat's own unit, metres for distances) in the player's unit system
local function goalOf(a, system)
  if not a.dist then return a.goal end
  return (a.dist[system] or a.dist.metric) * (system == "imperial" and MILE or KM)
end

return {LIST = LIST, descOf = descOf, goalOf = goalOf, KM = KM, MILE = MILE}
