local info = GG.lusHelper[unitDefID]

local MAX_PASSENGERS = UnitDef.transportCapacity

local passengers = {}
local numPassengers = 0
local attachPoints = {}
local rotatePoints = {}
for i = 1, MAX_PASSENGERS do
	attachPoints[i] = piece("p" .. i)
	rotatePoints[i] = piece("r" .. i)
end

local wakes = {}
for i = 1,info.numWakes do
	wakes[i] = piece("wake" .. i)
end
local arm = piece "arm"

local ramps = {}
local turrets = {}
local sleeves = {}
local flares = {}

for i = 1, #(UnitDef.weapons) do
	turrets[i] = piece("mount" .. i)
	sleeves[i] = piece("sleeve" .. i)
	flares[i] = piece("flare" .. i)
end

for i = 1, info.numRamps do
	ramps[i] = piece("ramp" .. i)
end
-- a model with a single ramp may call it just "ramp"
if info.numRamps == 1 and not ramps[1] then
	ramps[1] = piece("ramp")
end

-- Models without seat pieces (p1, p2, ...) carry their passengers hidden and
-- put them ashore one at a time with the turret/grabber/link crane instead.
local Crane = (not attachPoints[1]) and include("BoatCrane.lua")

local function RampUp()
	--Spring.MoveCtrl.Enable(unitID)
	for i = 1, info.numRamps do
		Turn(ramps[i], x_axis, math.rad(0), math.rad(30))
	end
	WaitForTurn(ramps[1], x_axis)
	--Spring.MoveCtrl.Disable(unitID)
end

local function Wakes()
	Signal(1)
	SetSignalMask(1)
	while true do
		for i, wake in pairs(wakes) do
			Spring.UnitScript.EmitSfx(wake, SFX.WAKE)
			Sleep(90)
		end
	end
end

function script.StartMoving()
	StartThread(RampUp)
	StartThread(Wakes)
end

function script.StopMoving()
	Signal(1)
end

function script.TransportPickup(passengerID, skip)
	Signal(2)
	SetSignalMask(2)
	if not skip then
		Spring.MoveCtrl.Enable(unitID)
		SetUnitValue(COB.BUSY, 1)
		for i = 1, info.numRamps do
			Turn(ramps[i], x_axis, math.rad(95/info.numRamps), math.rad(30))
			WaitForTurn(ramps[i], x_axis)
		end
		if numPassengers == 0 and arm then
			Move(arm, z_axis, 0)
		end
	end
	Spring.UnitScript.AttachUnit(attachPoints[numPassengers + 1] or -1, passengerID)
	-- only keep track of passengers the engine actually let us load
	if Spring.GetUnitTransporter(passengerID) == unitID then
		numPassengers = numPassengers + 1
		passengers[numPassengers] = passengerID
		Spring.SetUnitNoMinimap(passengerID, true)
	end
	--Spring.Echo("TransportPickup", numPassengers, "ID", passengerID, info.rampLength)
	SetUnitValue(COB.BUSY, 0)
	Spring.MoveCtrl.Disable(unitID)
end

local function CraneDrop(passengerID, x, y, z)
	SetUnitValue(COB.BUSY, 1)
	for i = 1, info.numRamps do
		Turn(ramps[i], x_axis, math.rad(95/info.numRamps), math.rad(30))
		WaitForTurn(ramps[i], x_axis)
	end
	Crane.Drop(passengerID, x, y, z)
	for i = 1, numPassengers do
		if passengers[i] == passengerID then
			table.remove(passengers, i)
			numPassengers = numPassengers - 1
			break
		end
	end
	SetUnitValue(COB.BUSY, 0)
end

function script.TransportDrop(passengerID, x, y, z)
	Signal(2)
	SetSignalMask(2)
	if Crane then
		CraneDrop(passengerID, x, y, z)
		return
	end
	Spring.MoveCtrl.Enable(unitID)
	SetUnitValue(COB.BUSY, 1)
	for i = 1, info.numRamps do
		Turn(ramps[i], x_axis, math.rad(95/info.numRamps), math.rad(30))
		WaitForTurn(ramps[i], x_axis)
	end
	for i = 1, numPassengers do
		env = Spring.UnitScript.GetScriptEnv(passengers[i])
		Spring.UnitScript.CallAsUnit(passengers[i], env.script.StartMoving)
	end
	Move(arm, z_axis, info.armLength - math.floor(numPassengers/info.rowSize)*info.colSize, 9) -- 42
	WaitForMove(arm, z_axis)
	local dropped = 0
	for i = 1, info.rowSize do
		local passNum = numPassengers - (i - 1)
		if passNum > 0 then
			if rotatePoints[passNum] then
				Turn(rotatePoints[passNum], x_axis, math.rad(13), math.rad(13))
				WaitForTurn(rotatePoints[passNum], x_axis)
				Move(attachPoints[passNum], z_axis, info.rampLength, 9)
				WaitForMove(attachPoints[passNum], z_axis)
			end
			--Spring.Echo("TransportDrop", passNum, x, y, z, "ID", passengerID)
			Spring.UnitScript.DropUnit(passengers[passNum])
			Spring.GiveOrderToUnit(passengers[passNum], CMD.MOVE, {x,y,z}, {})
			Spring.SetUnitNoMinimap(passengers[passNum], true)
			dropped = dropped + 1
			if rotatePoints[passNum] then
				Move(attachPoints[passNum], z_axis, 0)
				Turn(rotatePoints[passNum], x_axis, 0)
			end
		end
	end
	numPassengers = numPassengers - dropped
	SetUnitValue(COB.BUSY, 0)
	if numPassengers == 0 then
		Move(arm, z_axis, 0)
		Spring.MoveCtrl.Disable(unitID)
	end
end

function script.TransportEnd()
	--Spring.Echo("TransportEnd")
end

function script.QueryWeapon(weaponNum)
	return flares[weaponNum]
end


function script.AimWeapon(weaponNum, heading, pitch)
	Turn(turrets[weaponNum], y_axis, heading, math.rad(40))
	Turn(sleeves[weaponNum], x_axis, -pitch, math.rad(80))
	WaitForTurn(turrets[weaponNum], y_axis)
	WaitForTurn(sleeves[weaponNum], x_axis)
	return true
end

function script.Shot(weaponNum)
	GG.EmitSfxName(unitID, flares[weaponNum], "MG_MUZZLEFLASH")
end