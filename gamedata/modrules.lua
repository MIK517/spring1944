-- QTPFS is the default. Only an explicit "off" selects HAPFS: lobbies generally
-- send only the modoptions that differ from their default, so an absent key must
-- mean "default" here. Testing for qtpfs == "1" would silently keep everyone on
-- HAPFS whenever the option was left alone.
local function QTPFSSwitchedOff()
	local v = (Spring.GetModOptions() or {}).qtpfs
	return (v == "0") or (v == 0) or (v == false) or (v == "false")
end

local modRules = {
	flankingBonus = {
		defaultMode					=	0,
	},
	experience = {
		powerScale					=	1.5,
		healthScale					=	1.5,
		reloadScale					=	0,
		experienceMult			=	1.25,
	},
	sensors = {
		los = {
			losMipLevel				=	3,
			airMipLevel				=	5,
		},
	},
	movement = {
		allowPushingEnemyUnits = true,
		allowUnitCollisionDamage  = false,
		allowUnitCollisionOverlap  = false,
		allowSepAxisCollisionTest = true,
		allowGroundUnitGravity = true,
	},
	nanospray = {
		allow_team_colours	=	false,
	},
	system = {
		-- 1 = QTPFS (default), 0 = HAPFS (the engine's own default).
		-- Benchmarked on engine 2026.07.04 with a fixed RNG seed and paired
		-- within-pass comparison: QTPFS was faster in 9 of 9 pairs (median +20%
		-- on a large open map, +12% on a maze), its units closed 21-32% more
		-- distance toward their goals, and it reproduced the same simulation on
		-- every run where HAPFS did not.
		pathFinderSystem = QTPFSSwitchedOff() and 0 or 1,

		-- How far a unit may "raw move" -- walk a straight line without a path
		-- search -- when the direct route is passable. Engine default 1.25;
		-- Zero-K and BAR both use 100000.
		--
		-- HAPFS-only: the engine reads this solely in
		-- HAPFS::CPathManager::RequestPath, so it has no effect under the
		-- default QTPFS. Kept for anyone who switches back to HAPFS.
		pathFinderRawDistMult = 100000,
	},
	transportability = {
		targetableTransportedUnits = true,
	},
}

return modRules
