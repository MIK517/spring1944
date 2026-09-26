-- Landing craft that carry their own weapons and unload with a
-- turret/grabber/link crane. Replaces the old per-unit COB scripts. Everything unit specific comes from the
-- customParams.landingcraft table (parsed by lus_helper into info.landingCraft):
--
-- landingcraft = {
--   loader = "crane",
--   ramp = {piece = "ramp", angle = 90, speed = 30,      -- degrees, deg/s
--           slide = 6.8, slidespeed = 6,                  -- optional: slide out along z first
--           closedelay = 1500},                           -- optional: close this long after (un)loading
--   loadtime = 500, unloadtime = 1000,                    -- ms the craft stays busy per unit
--   slots = {"load1", "load2"},                           -- crane: pieces showing the first passengers
--   shatterseverity = 0.5,                                -- damage share above which the wreck shatters
--   weapons = {
--     [1] = {aim = "mount", pitch = "sleeve", flare = "flare", aimfrom = "mount",
--            heading = 180, aa = true, ceg = "MG_MUZZLEFLASH", dust = "...",
--            barrel = "barrel", recoil = 0.4, recoilspeed = 10, returnspeed = 1, recoiltime = 200},
--   },
-- }

local info = GG.lusHelper[unitDefID]
local cfg = info.landingCraft or {}

local rad = math.rad
local sqrt = math.sqrt
local random = math.random
local pi = math.pi

local AttachUnit = Spring.UnitScript.AttachUnit
local DropUnit = Spring.UnitScript.DropUnit
local GetUnitTransporter = Spring.GetUnitTransporter
local GetUnitIsTransporting = Spring.GetUnitIsTransporting
local GetUnitPiecePosDir = Spring.GetUnitPiecePosDir
local GetUnitHeading = Spring.GetUnitHeading
local GetHeadingFromVector = Spring.GetHeadingFromVector
local GetUnitDefID = Spring.GetUnitDefID
local GetUnitHealth = Spring.GetUnitHealth
local GetGroundHeight = Spring.GetGroundHeight
local GetGameFrame = Spring.GetGameFrame

local base = piece("base")

local function NamedPiece(name)
	if not name then
		return nil
	end
	local p = piece(name)
	if not p then
		Spring.Log("LandingCraft.lua", "error", UnitDef.name .. ": no piece '" .. name .. "'")
	end
	return p
end

--------------------------------------------------------------------------------
-- Signals
--------------------------------------------------------------------------------

local SIG_MOVE = 1
local SIG_LOAD = 2
local SIG_RAMP = 4
local nextSignal = 8

--------------------------------------------------------------------------------
-- Ramp
--------------------------------------------------------------------------------

local ramp = cfg.ramp and NamedPiece(cfg.ramp.piece)
local rampAngle, rampSpeed, rampSlide, rampSlideSpeed, rampCloseDelay
if ramp then
	rampAngle = rad(cfg.ramp.angle or 90)
	rampSpeed = rad(cfg.ramp.speed or 30)
	rampSlide = cfg.ramp.slide
	rampSlideSpeed = cfg.ramp.slidespeed or 6
	rampCloseDelay = cfg.ramp.closedelay
end

-- Blocks until the ramp is down.
local function OpenRamp()
	if not ramp then
		return
	end
	Signal(SIG_RAMP)
	if rampSlide then
		Move(ramp, z_axis, rampSlide, rampSlideSpeed)
		WaitForMove(ramp, z_axis)
	end
	Turn(ramp, x_axis, rampAngle, rampSpeed)
	WaitForTurn(ramp, x_axis)
end

local function CloseRamp()
	if not ramp then
		return
	end
	Signal(SIG_RAMP)
	SetSignalMask(SIG_RAMP)
	Turn(ramp, x_axis, 0, rampSpeed)
	WaitForTurn(ramp, x_axis)
	if rampSlide then
		Move(ramp, z_axis, 0, rampSlideSpeed)
		WaitForMove(ramp, z_axis)
	end
end

local function CloseRampLater()
	if ramp and rampCloseDelay then
		Sleep(rampCloseDelay)
		StartThread(CloseRamp)
	end
end

--------------------------------------------------------------------------------
-- Effects
--------------------------------------------------------------------------------

local wakes = {}
local flags = {}
for pieceName, pieceNum in pairs(Spring.GetUnitPieceMap(unitID)) do
	local wakeNum = pieceName:match("^wake(%d*)$")
	if wakeNum then
		wakes[#wakes + 1] = pieceNum
	end
	local flagNum = tonumber(pieceName:match("^flag(%d+)$"))
	if flagNum then
		flags[flagNum] = pieceNum
	end
end

local WAKE_PERIOD = 300
local SMOKE_MIN_PERIOD = 240
local SMOKE_PERIOD_PER_HEALTH = 40 -- ms per % of health left
local FLAG_FLAP_ANGLE = rad(30)
local FLAG_FLAP_SPEED = rad(45)
local FLAG_FLAP_PERIOD = 50

local function Wakes()
	Signal(SIG_MOVE)
	SetSignalMask(SIG_MOVE)
	while true do
		for i = 1, #wakes do
			EmitSfx(wakes[i], SFX.WAKE)
		end
		Sleep(WAKE_PERIOD)
	end
end

local function DamageSmoke()
	local _, _, _, _, buildProgress = GetUnitHealth(unitID)
	while buildProgress < 1 do
		Sleep(200)
		_, _, _, _, buildProgress = GetUnitHealth(unitID)
	end
	Sleep(random(10, 150))
	while true do
		local health, maxHealth = GetUnitHealth(unitID)
		local healthPct = 100 * health / maxHealth
		local delay = SMOKE_MIN_PERIOD
		if healthPct < 66 then
			local smoke = SFX.BLACK_SMOKE
			if random(1, 66) < healthPct then
				smoke = SFX.WHITE_SMOKE
			end
			EmitSfx(base, smoke)
			delay = math.max(healthPct * SMOKE_PERIOD_PER_HEALTH, SMOKE_MIN_PERIOD)
		end
		Sleep(delay)
	end
end

-- flag1 is the pole, flag2... are the cloth segments
local function FlagFlap()
	local sign = 1
	while true do
		for i = 2, #flags do
			local dir = (i % 2 == 0) and -sign or sign
			Turn(flags[i], y_axis, dir * FLAG_FLAP_ANGLE, FLAG_FLAP_SPEED)
		end
		sign = -sign
		Sleep(FLAG_FLAP_PERIOD)
	end
end

--------------------------------------------------------------------------------
-- Weapons
--------------------------------------------------------------------------------

local turretTurnSpeed = info.turretTurnSpeed
local elevationSpeed = info.elevationSpeed
local RESTORE_DELAY = 2500
-- an A.A. weapon that aimed this recently keeps the turret to itself
local AA_PRIORITY_FRAMES = 30

local weapons = {}
local turretSignals = {}
local aaAimFrame = {}

for weaponNum, w in pairs(cfg.weapons or {}) do
	local aim = NamedPiece(w.aim)
	local weapon = {
		aim = aim,
		pitch = NamedPiece(w.pitch),
		flare = NamedPiece(w.flare),
		aimFrom = NamedPiece(w.aimfrom) or aim,
		barrel = NamedPiece(w.barrel),
		heading = rad(w.heading or 0),
		aa = w.aa,
		ceg = w.ceg,
		dust = w.dust,
		recoil = w.recoil,
		recoilSpeed = w.recoilspeed or 10,
		returnSpeed = w.returnspeed or 1,
		recoilTime = w.recoiltime or 200,
	}
	-- weapons sharing a turret share its signal, so they cancel each other
	if aim and not turretSignals[aim] then
		turretSignals[aim] = nextSignal
		nextSignal = nextSignal * 2
	end
	weapon.signal = aim and turretSignals[aim] or 0
	weapons[weaponNum] = weapon
end

local function RestoreTurret(weapon)
	SetSignalMask(weapon.signal)
	Sleep(RESTORE_DELAY)
	Turn(weapon.aim, y_axis, weapon.heading, turretTurnSpeed)
	if weapon.pitch then
		Turn(weapon.pitch, x_axis, 0, elevationSpeed)
	end
end

function script.AimFromWeapon(weaponNum)
	local weapon = weapons[weaponNum]
	return weapon and weapon.aimFrom or base
end

function script.QueryWeapon(weaponNum)
	local weapon = weapons[weaponNum]
	return weapon and weapon.flare or base
end

function script.AimWeapon(weaponNum, heading, pitch)
	local weapon = weapons[weaponNum]
	if not (weapon and weapon.aim) then
		return false
	end
	local aim = weapon.aim
	if weapon.aa then
		aaAimFrame[aim] = GetGameFrame()
	elseif aaAimFrame[aim] and GetGameFrame() - aaAimFrame[aim] < AA_PRIORITY_FRAMES then
		return false
	end
	Signal(weapon.signal)
	SetSignalMask(weapon.signal)
	Turn(aim, y_axis, heading, turretTurnSpeed)
	if weapon.pitch then
		Turn(weapon.pitch, x_axis, -pitch, elevationSpeed)
	end
	WaitForTurn(aim, y_axis)
	if weapon.pitch then
		WaitForTurn(weapon.pitch, x_axis)
	end
	StartThread(RestoreTurret, weapon)
	return true
end

local function Recoil(weapon)
	Move(weapon.barrel, z_axis, -weapon.recoil, weapon.recoilSpeed)
	Sleep(weapon.recoilTime)
	Move(weapon.barrel, z_axis, 0, weapon.returnSpeed)
end

function script.Shot(weaponNum)
	local weapon = weapons[weaponNum]
	if not (weapon and weapon.flare) then
		return
	end
	if weapon.ceg then
		GG.EmitSfxName(unitID, weapon.flare, weapon.ceg)
	end
	if weapon.dust then
		GG.EmitSfxName(unitID, weapon.flare, weapon.dust)
	end
	if weapon.barrel and weapon.recoil then
		StartThread(Recoil, weapon)
	end
end

--------------------------------------------------------------------------------
-- Transport
--------------------------------------------------------------------------------

local LOAD_TIME = cfg.loadtime or 500
local UNLOAD_TIME = cfg.unloadtime or 1000

local Loader

if cfg.loader == "crane" then
	local Crane = include("BoatCrane.lua")
	if not Crane then
		Spring.Log("LandingCraft.lua", "error", UnitDef.name .. ": crane loader without turret/grabber/link pieces")
	end

	-- the first few passengers are shown at these pieces, the rest ride hidden
	local slots = {}
	local slotUnits = {}
	for i, name in ipairs(cfg.slots or {}) do
		slots[i] = NamedPiece(name)
	end

	local function IsAboard(passengerID)
		return passengerID and GetUnitTransporter(passengerID) == unitID
	end

	local function FreeSlot()
		for i = 1, #slots do
			if not IsAboard(slotUnits[i]) then
				slotUnits[i] = nil
				return i
			end
		end
	end

	-- move hidden passengers into slots that became free
	local function RefillSlots()
		if #slots == 0 then
			return
		end
		local shown = {}
		for i = 1, #slots do
			if IsAboard(slotUnits[i]) then
				shown[slotUnits[i]] = true
			end
		end
		local passengers = GetUnitIsTransporting(unitID) or {}
		for i = 1, #passengers do
			local passengerID = passengers[i]
			if not shown[passengerID] then
				local slot = FreeSlot()
				if not slot then
					return
				end
				AttachUnit(slots[slot], passengerID)
				slotUnits[slot] = passengerID
			end
		end
	end

	Loader = {}

	function Loader.Pickup(passengerID, fromLua)
		if not fromLua then
			SetUnitValue(COB.BUSY, 1)
			OpenRamp()
		end
		local slot = FreeSlot()
		AttachUnit(slot and slots[slot] or -1, passengerID)
		if slot and IsAboard(passengerID) then
			slotUnits[slot] = passengerID
		end
		if not fromLua then
			Sleep(LOAD_TIME)
			SetUnitValue(COB.BUSY, 0)
			CloseRampLater()
		end
	end

	function Loader.Drop(passengerID, x, y, z)
		SetUnitValue(COB.BUSY, 1)
		OpenRamp()
		if Crane then
			Crane.Drop(passengerID, x, y, z)
		elseif IsAboard(passengerID) then
			DropUnit(passengerID)
		end
		RefillSlots()
		Sleep(UNLOAD_TIME)
		SetUnitValue(COB.BUSY, 0)
		CloseRampLater()
	end
end

function script.TransportPickup(passengerID, fromLua)
	if not Loader then
		return
	end
	Signal(SIG_LOAD)
	SetSignalMask(SIG_LOAD)
	Loader.Pickup(passengerID, fromLua)
end

function script.TransportDrop(passengerID, x, y, z)
	if not Loader then
		return
	end
	Signal(SIG_LOAD)
	SetSignalMask(SIG_LOAD)
	Loader.Drop(passengerID, x, y, z)
end

--------------------------------------------------------------------------------
-- Callins
--------------------------------------------------------------------------------

function script.Create()
	for _, weapon in pairs(weapons) do
		if weapon.flare then
			Hide(weapon.flare)
		end
		if weapon.aim and weapon.heading ~= 0 then
			Turn(weapon.aim, y_axis, weapon.heading)
		end
	end
	if flags[1] then
		Turn(flags[1], y_axis, pi)
		StartThread(FlagFlap)
	end
	StartThread(DamageSmoke)
end

function script.StartMoving()
	StartThread(Wakes)
	StartThread(CloseRamp)
end

function script.StopMoving()
	Signal(SIG_MOVE)
end

function script.Killed(recentDamage, maxHealth)
	local severity = recentDamage / maxHealth
	if severity >= (cfg.shatterseverity or 0.5) then
		Explode(base, SFX.SHATTER)
		return 2
	end
	for axis, data in pairs(info.deathAnim) do
		Turn(base, info.axes[axis] or z_axis, -rad(data.angle or 30), rad(data.speed or 10))
	end
	for axis in pairs(info.deathAnim) do
		WaitForTurn(base, info.axes[axis] or z_axis)
	end
	return 1
end
