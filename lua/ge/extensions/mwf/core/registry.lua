-- The one object every module shares.
--   S    : the mod's mutable state (see core/state.lua)
--   MWF  : lookup of every function module by name, e.g. MWF.pits.loadGasStations(). Filled as modules load, read at call time,
--          so modules never need to require each other (no circular requires).
--   MWF.core is the extension table itself (mwf_core); the game calls its on* hooks.
return {S = {}}
