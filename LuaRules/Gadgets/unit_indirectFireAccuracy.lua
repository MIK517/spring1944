function gadget:GetInfo()
	return {
		name	  = "Indirect Fire Accuracy Manager",
		desc	  = "Changes the accuracy of weapons fire based on the LoS status of the target",
		author	  = "Ben Tyler (Nemo), Craig Lawrence (FLOZi), ashdnazg",
		date	  = "Feb 10th, 2009",
		license	  = "LGPL v2.1 or later",
		layer	  = 0,
		enabled	  = true  --  loaded by default?
	}
end

if (not gadgetHandler:IsSyncedCode()) then
  return false
end

local indirectUnitDefIDs = {}
local lastHit = {}
local firingPositions = {}

local ZEROING_FACTOR = 0.75
local MIN_ZEROING = 0.15
local ZEROED_THRESHOLD = 0.25
-- if the firing unit moves more than this, wipe accuracy bonus
local MOVEMENT_THRESHOLD = 50

local function Dist2D(x1, z1, x2, z2)
    return math.sqrt((x2 - x1) ^ 2 + (z2 - z1) ^ 2)
end

-- UnitDefs[].weapons builds new tables on every access, and updateUnit runs
-- every frame, so keep what it needs per unit type
local weaponInfoCache = {} -- unitDefID -> {count = #weapons, baseAccuracy = weapon 1 accuracy}
local function GetWeaponInfo(unitDefID)
	local info = weaponInfoCache[unitDefID]
	if not info then
		local weapons = UnitDefs[unitDefID].weapons
		info = {
			count = #weapons,
			baseAccuracy = weapons[1] and WeaponDefs[weapons[1].weaponDef].accuracy,
		}
		weaponInfoCache[unitDefID] = info
	end
	return info
end

-- returns the target position as x, y, z (nil if there is none)
local function GetTargetPos(unitID, weaponNum)
	local i, _, target = Spring.GetUnitWeaponTarget(unitID, weaponNum)

	-- targeting a spot on the ground
	if i == 2 then
		return target[1], target[2], target[3]
	end

	-- targeting a unit
	if i == 1 then
		return Spring.GetUnitPosition(target)
	end

	-- targeting a projectile: seems unlikely in S44, but ... completeness!
	if i == 3 then
		return Spring.GetProjectilePosition(target)
	end

	return nil
end

local function GetNewAccuracy(baseAccuracy, currentAccuracy, hitDist, targetDist)
	local newAccuracy = math.max(currentAccuracy, (hitDist / targetDist)) * ZEROING_FACTOR
	newAccuracy = math.min(newAccuracy, baseAccuracy)
	newAccuracy = math.max(newAccuracy, MIN_ZEROING * baseAccuracy)

	return newAccuracy
end

-- this could be shimmed into updateUnit, but it is _probably_ better to keep
-- extra function calls out of a thing that runs every frame.
-- premature optimisation, etc., etc.
local function reset(unitID)
	local info = GetWeaponInfo(Spring.GetUnitDefID(unitID))
	local baseAccuracy = info.baseAccuracy

	for i=1, info.count do
		Spring.SetUnitWeaponState(unitID, i, "accuracy", baseAccuracy)
	end

	Spring.SetUnitRulesParam(unitID, "zeroed", 0)
	lastHit[unitID][1] = nil
	lastHit[unitID][2] = nil
	lastHit[unitID][3] = nil
end

local function updateUnit(unitID, coords)
	if lastHit[unitID][1] == nil then
		return
	end
	local tx, ty, tz = GetTargetPos(unitID, 1)
	if not tx then
		return
	end

	local info = GetWeaponInfo(Spring.GetUnitDefID(unitID))
	local baseAccuracy = info.baseAccuracy
	local newAccuracy

	local allyTeam = Spring.GetUnitAllyTeam(unitID)
	local targetInLosOrRadar = Spring.GetPositionLosState(tx, ty, tz, allyTeam)
	if targetInLosOrRadar then
		local ux, _ , uz = Spring.GetUnitPosition(unitID)

		local unitMoved = false
		if firingPositions[unitID] and firingPositions[unitID][1] then
			unitMoved = Dist2D(firingPositions[unitID][1], firingPositions[unitID][3], ux, uz) > MOVEMENT_THRESHOLD
		end

		if unitMoved then
			reset(unitID)
			return
		end

		local targetDist = Dist2D(tx, tz, ux, uz)
		local hitDist = Dist2D(coords[1], coords[3], tx, tz)

		local currentAccuracy = Spring.GetUnitWeaponState(unitID, 1, "accuracy")

		newAccuracy = GetNewAccuracy(baseAccuracy, currentAccuracy, hitDist, targetDist)
	else
		newAccuracy = baseAccuracy
	end

	if newAccuracy <= baseAccuracy * ZEROED_THRESHOLD then
		Spring.SetUnitRulesParam(unitID, "zeroed", 1)
	else
		Spring.SetUnitRulesParam(unitID, "zeroed", 0)
	end

	for i=1, info.count do
		Spring.SetUnitWeaponState(unitID, i, "accuracy", newAccuracy)
	end
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	if indirectUnitDefIDs[unitDefID] then
		local info = GetWeaponInfo(unitDefID)
		if info.count > 0 then
			lastHit[unitID] = {}
			firingPositions[unitID] = {}

			for i=1, info.count do
				Spring.SetUnitWeaponState(unitID, i, "accuracy", info.baseAccuracy)
			end
		end
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam)
	lastHit[unitID] = nil
	firingPositions[unitID] = nil
end

function gadget:Explosion(weaponDefID, px, py, pz, attackerID)
	if not attackerID or not lastHit[attackerID] then
		return
	end

	local allyTeam = Spring.GetUnitAllyTeam(attackerID)

	local x, y, z = Spring.GetUnitPosition(attackerID)
	-- if the unit moves, discard accuracy bonus. the check is performed in updateUnit
	firingPositions[attackerID][1] = x
	firingPositions[attackerID][2] = y
	firingPositions[attackerID][3] = z

	local visibleImpact = Spring.IsPosInAirLos(px, py, pz, allyTeam)
	if visibleImpact then
		lastHit[attackerID][1], lastHit[attackerID][2], lastHit[attackerID][3] = px, py, pz
	else
		-- fired off into the wild blue yonder somewhere. wipe out any progress
		reset(attackerID)
	end
end

function gadget:GameFrame(n)
	for unitID, coords in pairs(lastHit) do
		updateUnit(unitID, coords)
	end
end

function gadget:Initialize()
	for unitDefID, unitDef in pairs(UnitDefs) do
		if unitDef.customParams.canareaattack then
			indirectUnitDefIDs[unitDefID] = true
			for _, weapon in pairs(unitDef.weapons) do
				Script.SetWatchWeapon(weapon.weaponDef, true)
			end
		end
	end

	local allUnits = Spring.GetAllUnits()
	for i=1,#allUnits do
		local unitID = allUnits[i]
		gadget:UnitCreated(unitID, Spring.GetUnitDefID(unitID))
	end

end
