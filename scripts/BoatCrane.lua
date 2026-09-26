-- Crane unloading for boats with a turret > grabber > link piece chain (the
-- same rig the old COB landing craft scripts used): the passenger is hung on
-- the link, the crane is swung out to the drop point and the passenger is let
-- go there.
--
-- Usage: local Crane = include("BoatCrane.lua")
-- Returns nil if the model lacks the crane pieces.

local turret, grabber, link = piece("turret", "grabber", "link")
if not (turret and grabber and link) then
	return nil
end

local atan2 = math.atan2
local sqrt = math.sqrt
local pi = math.pi

local AttachUnit = Spring.UnitScript.AttachUnit
local DropUnit = Spring.UnitScript.DropUnit
local GetUnitPiecePosDir = Spring.GetUnitPiecePosDir
local GetUnitHeading = Spring.GetUnitHeading
local GetUnitTransporter = Spring.GetUnitTransporter
local GetHeadingFromVector = Spring.GetHeadingFromVector

-- give the passenger a couple of frames to follow the link before release
local SETTLE_TIME = 50

local Crane = {}

-- Put the passenger down at the world position x, y, z. Must be called from a
-- thread, as it sleeps.
function Crane.Drop(passengerID, x, y, z)
	local tx, ty, tz = GetUnitPiecePosDir(unitID, turret)
	local dx, dy, dz = x - tx, y - ty, z - tz
	local dist2D = sqrt(dx * dx + dz * dz)
	local heading = (GetHeadingFromVector(dx, dz) - GetUnitHeading(unitID)) / 32768 * pi

	AttachUnit(link, passengerID)
	Turn(turret, y_axis, heading)
	Turn(grabber, x_axis, -atan2(dy, dist2D))
	Move(grabber, z_axis, sqrt(dist2D * dist2D + dy * dy))
	Sleep(SETTLE_TIME)
	-- the passenger may have died in the meantime
	if GetUnitTransporter(passengerID) == unitID then
		DropUnit(passengerID)
	end

	Turn(turret, y_axis, 0)
	Turn(grabber, x_axis, 0)
	Move(grabber, z_axis, 0)
end

return Crane
