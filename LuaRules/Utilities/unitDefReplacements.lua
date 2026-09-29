-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-- Unit def helpers used by the Zero-K interface widgets, for Spring: 1944.
--
-- Same API as Zero-K's LuaRules/Utilities/unitDefReplacements.lua. Zero-K
-- measures cost in build time and has commanders, overdrive and tech levels;
-- none of that applies here. In S:44 a unit costs Command Points, which the
-- engine calls metal, so cost is the unit def's metal cost.
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------

local buildPowerCache = {}
local rangeCache = {}

local function GetCachedBaseBuildPower(unitDefID, ud)
	if not buildPowerCache[unitDefID] then
		ud = ud or UnitDefs[unitDefID]
		buildPowerCache[unitDefID] = (ud and ((ud.customParams.nobuildpower and 0) or ud.buildSpeed)) or 0
	end
	return buildPowerCache[unitDefID]
end

local function GetCachedBaseRange(unitDefID, ud)
	if not rangeCache[unitDefID] then
		ud = ud or UnitDefs[unitDefID]
		rangeCache[unitDefID] = ud.maxWeaponRange
	end
	return rangeCache[unitDefID]
end

-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------

function Spring.Utilities.GetUnitCost(unitID, unitDefID)
	unitDefID = unitDefID or (unitID and Spring.GetUnitDefID(unitID))
	local ud = unitDefID and UnitDefs[unitDefID]
	if not ud then
		return 50
	end
	return ud.metalCost or ud.buildTime or 0
end

function Spring.Utilities.GetUnitValue(unitID, unitDefID)
	local cost = Spring.Utilities.GetUnitCost(unitID, unitDefID)
	local _, buildProgress = Spring.GetUnitIsBeingBuilt(unitID)
	return cost * (buildProgress or 1)
end

function Spring.Utilities.GetUnitCanBuild(unitID, unitDefID)
	unitDefID = unitDefID or Spring.GetUnitDefID(unitID)
	if not unitDefID then
		return false
	end
	return GetCachedBaseBuildPower(unitDefID) > 0
end

function Spring.Utilities.GetUnitBuildSpeed(unitID, unitDefID)
	unitDefID = unitDefID or Spring.GetUnitDefID(unitID)
	if not unitDefID then
		return 0
	end
	local buildPower = GetCachedBaseBuildPower(unitDefID)
	return buildPower, buildPower
end

function Spring.Utilities.GetUnitRange(unitID, unitDefID)
	unitDefID = unitDefID or Spring.GetUnitDefID(unitID)
	if not unitDefID then
		return false
	end
	local range = GetCachedBaseRange(unitDefID)
	return (range > 0) and range
end

function Spring.Utilities.GetBaseDefID(unitDefID)
	return unitDefID
end

-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------

local function Translate(db, key)
	return WG and WG.Translate and WG.Translate(db, key, nil, {suppressWarnings = true})
end

function Spring.Utilities.GetHumanName(ud, unitID)
	if not ud then
		return ""
	end
	return Translate("units", ud.name .. ".name") or ud.humanName
end

function Spring.Utilities.GetDescription(ud, unitID)
	if not ud then
		return ""
	end
	return Translate("units", ud.name .. ".description") or ud.tooltip
end

Spring.Utilities.GetHumanNameForWreck = Spring.Utilities.GetHumanName
Spring.Utilities.GetDescriptionForWreck = Spring.Utilities.GetDescription

function Spring.Utilities.GetHelptext(ud, unitID)
	local helptext = Translate("units", ud.name .. ".helptext") or ud.customParams.helptext
	if helptext and helptext ~= "" then
		return helptext
	end
	return Translate("interface", "no_helptext") or ""
end

function Spring.Utilities.GetUnitHeight(ud)
	local customHeight = ud.customParams.custom_height
	return (customHeight and tonumber(customHeight)) or ud.height
end

-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------

function Spring.Utilities.UnitEcho(unitID, st)
	if type(st) == "boolean" then
		st = st and "T" or "F"
	end
	st = st or unitID
	if Spring.ValidUnitID(unitID) then
		local x,y,z = Spring.GetUnitPosition(unitID)
		Spring.MarkerAddPoint(x,y,z, st)
	else
		Spring.Echo("Invalid unitID")
		Spring.Echo(unitID)
		Spring.Echo(st)
	end
end

function Spring.Utilities.FeatureEcho(featureID, st)
	st = st or featureID
	if Spring.ValidFeatureID(featureID) then
		local x,y,z = Spring.GetFeaturePosition(featureID)
		Spring.MarkerAddPoint(x,y,z, st)
	else
		Spring.Echo("Invalid featureID")
		Spring.Echo(featureID)
		Spring.Echo(st)
	end
end
