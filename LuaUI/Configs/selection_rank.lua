-- Default selection ranks for Spring: 1944 (see gui_selection_hierarchy.lua).
-- Box selection keeps only the units of the highest rank in the box, so by
-- default dragging over an army selects its combat units only:
--  3: armed mobile units (including armed spotters and radio units)
--  2: engineers and other builders, supply trucks, unarmed transports, boats
--     and spotters
--  1: buildings, emplacements and mines
-- Hold Shift (configurable) to select all ranks. A unit def can set its rank
-- with customParams.selection_rank.

local defaultRank = {}
local morphRankTransfer = {}

-- A weapon that does not harm anything: binoculars, bullet-proof shields,
-- paratrooper drops and similar gameplay helpers.
local function IsRealWeapon(weaponDefID)
	local wd = WeaponDefs[weaponDefID]
	if not wd then
		return false
	end
	local cp = wd.customParams or {}
	if cp.binocs or cp.paratrooper or cp.damagetype == "none" then
		return false
	end
	if wd.type == "Shield" or cp.onlytargetcategory == "NONE" then
		return false
	end
	return true
end

local function IsArmed(ud)
	local weapons = ud.weapons
	for i = 1, #weapons do
		if IsRealWeapon(weapons[i].weaponDef) then
			return true
		end
	end
	return false
end

for i = 1, #UnitDefs do
	local ud = UnitDefs[i]
	defaultRank[i] = ud.customParams.selection_rank and tonumber(ud.customParams.selection_rank)
	if not defaultRank[i] then
		if ud.isImmobile or ud.isBuilding or ud.isFactory or (ud.speed or 0) == 0 then
			defaultRank[i] = 1
		elseif ud.isMobileBuilder or not IsArmed(ud) then
			defaultRank[i] = 2
		else
			defaultRank[i] = 3
		end
	end
	-- S:44 units morph into other units (e.g. deploying guns); keep the rank
	-- a player set by hand.
	morphRankTransfer[i] = true
end

return defaultRank, morphRankTransfer
