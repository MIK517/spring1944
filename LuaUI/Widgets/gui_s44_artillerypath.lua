function widget:GetInfo()
	return {
		name = "1944 Artillery Path",
		desc = "While giving an attack order, shows the shell or rocket path of selected indirect-fire weapons to the cursor.",
		author = "MIK517",
		date = "2026-10-01",
		license = "GNU GPL, v2 or later",
		layer = 1,
		enabled = true
	}
end

------------------------------------------------
--config
------------------------------------------------
local colorClear = {0.35, 1, 0.35, 0.9}
local colorBlocked = {1, 0.3, 0.3, 0.9}
local colorUnreachable = {1, 0.3, 0.3, 0.45}
local lineWidth = 2
local maxUnits = 12          -- paths drawn at once
local segments = 48          -- per shell path
local groundIgnoreFrac = 1 / 16  -- engine skips the last 1/16 of a shell path

------------------------------------------------
--vars
------------------------------------------------
-- unitDefID = {weaponNum, kind ("cannon"/"rocket"), weaponDef, highTrajectory}
local artyDefs = {}

------------------------------------------------
--speedups
------------------------------------------------
local GetActiveCommand = Spring.GetActiveCommand
local GetMouseState = Spring.GetMouseState
local TraceScreenRay = Spring.TraceScreenRay
local GetSelectedUnitsSorted = Spring.GetSelectedUnitsSorted
local GetUnitWeaponVectors = Spring.GetUnitWeaponVectors
local GetUnitPosition = Spring.GetUnitPosition
local GetGroundHeight = Spring.GetGroundHeight
local IsUnitAllied = Spring.IsUnitAllied

local glColor = gl.Color
local glLineWidth = gl.LineWidth
local glBeginEnd = gl.BeginEnd
local glVertex = gl.Vertex
local glDepthTest = gl.DepthTest

local GL_LINE_STRIP = GL.LINE_STRIP
local GL_LINES = GL.LINES

local sqrt, max, min, floor = math.sqrt, math.max, math.min, math.floor

local CMD_ATTACK = CMD.ATTACK
local CMD_MANUALFIRE = CMD.MANUALFIRE

local GAME_SPEED = Game.gameSpeed or 30
local mapGravity = Game.gravity / (GAME_SPEED * GAME_SPEED) -- elmo/frame^2

------------------------------------------------
--path building (all in elmos and sim frames)
------------------------------------------------
local px, py, pz = {}, {}, {}  -- path points
local blockedFrom              -- first point index under the ground, or nil

-- Ballistic shell path, same solution as CCannon::CalcWantedDir.
local function BuildCannonPath(sx, sy, sz, tx, ty, tz, info)
	local wd = info[3]
	local v = wd.projectilespeed
	local g = (wd.myGravity and wd.myGravity > 0) and wd.myGravity or mapGravity
	local dx, dz = tx - sx, tz - sz
	local dxz = sqrt(dx * dx + dz * dz)
	local dy = ty - sy
	if dxz < 1 or v <= 0 then
		return 0
	end
	local v2 = v * v
	local root = v2 * v2 - g * (g * dxz * dxz + 2 * dy * v2)
	if root < 0 then
		return 0 -- beyond ballistic reach
	end
	local sign = info[4] and 1 or -1
	local tanA = (v2 + sign * sqrt(root)) / (g * dxz)
	local cosA = 1 / sqrt(1 + tanA * tanA)
	local vxz, vy = v * cosA, v * cosA * tanA
	local flightTime = dxz / vxz
	local ux, uz = dx / dxz, dz / dxz
	local checkUntil = segments * (1 - groundIgnoreFrac)
	for i = 0, segments do
		local t = flightTime * i / segments
		local d = vxz * t
		local x, z = sx + ux * d, sz + uz * d
		local y = sy + vy * t - 0.5 * g * t * t
		px[i + 1], py[i + 1], pz[i + 1] = x, y, z
		if not blockedFrom and i > 0 and i < checkUntil and y < GetGroundHeight(x, z) then
			blockedFrom = i + 1
		end
	end
	return segments + 1
end

-- Rocket pursuit curve, same 8-segment Heun approximation as
-- CMissileLauncher::HaveFreeLineOfFire.
local mdist, mheight = {}, {}
local function BuildRocketPath(sx, sy, sz, tx, ty, tz, info)
	local wd = info[3]
	local dx, dy, dz = tx - sx, ty - sy, tz - sz
	local rt = sqrt(dx * dx + dz * dz)
	local dist = sqrt(rt * rt + dy * dy)
	if rt < 1 then
		return 0
	end
	local ux, uz = dx / rt, dz / rt
	local maxSpeed = wd.projectilespeed
	local pSpeed = wd.startvelocity or 0
	local pAcc = wd.weaponAcceleration or 0
	local eH = dist * wd.trajectoryHeight
	local eHT = floor(dist / maxSpeed)
	local hstep = eHT / 8

	mdist[0], mheight[0] = 0, 0
	mdist[8], mheight[8] = rt, dy
	if hstep < 1 then
		for i = 1, 7 do
			mdist[i], mheight[i] = rt * i / 8, dy * i / 8
		end
	else
		local t = 0
		for i = 1, 7 do
			local r0, y0 = mdist[i - 1], mheight[i - 1]
			local aimY = dy + eH * (1 - t / eHT)
			local d = sqrt((rt - r0) ^ 2 + (aimY - y0) ^ 2)
			local speed = min(pSpeed + pAcc * t, maxSpeed)
			local drdt, dydt = speed * (rt - r0) / d, speed * (aimY - y0) / d
			local rEst, yEst = r0 + hstep * drdt, y0 + hstep * dydt
			t = t + hstep
			aimY = dy + eH * (1 - t / eHT)
			d = sqrt((rt - rEst) ^ 2 + (aimY - yEst) ^ 2)
			speed = min(pSpeed + pAcc * t, maxSpeed)
			local drdtEst, dydtEst = speed * (rt - rEst) / d, speed * (aimY - yEst) / d
			mdist[i] = r0 + hstep * 0.5 * (drdt + drdtEst)
			mheight[i] = y0 + hstep * 0.5 * (dydt + dydtEst)
		end
	end

	-- subdivide the 8 segments so ground checks are not too coarse
	local sub = 6
	local n = 0
	local aoe = wd.damageAreaOfEffect or 0
	for i = 0, 7 do
		for s = 0, (i == 7) and sub or (sub - 1) do
			local f = s / sub
			local r = mdist[i] + (mdist[i + 1] - mdist[i]) * f
			local h = mheight[i] + (mheight[i + 1] - mheight[i]) * f
			local x, z = sx + ux * r, sz + uz * r
			local y = sy + h
			n = n + 1
			px[n], py[n], pz[n] = x, y, z
			if not blockedFrom and n > 1 and r < rt - aoe and y < GetGroundHeight(x, z) then
				blockedFrom = n
			end
		end
	end
	return n
end

local function PathVertices(first, last)
	for i = first, last do
		glVertex(px[i], py[i], pz[i])
	end
end

local function LineVertices(sx, sy, sz, tx, ty, tz)
	glVertex(sx, sy, sz)
	glVertex(tx, ty, tz)
end

local function DrawPath(n)
	glColor(colorClear)
	glBeginEnd(GL_LINE_STRIP, PathVertices, 1, blockedFrom or n)
	if blockedFrom then
		glColor(colorBlocked)
		glBeginEnd(GL_LINE_STRIP, PathVertices, blockedFrom, n)
	end
end

local function DrawUnreachable(sx, sy, sz, tx, ty, tz)
	glColor(colorUnreachable)
	glBeginEnd(GL_LINES, LineVertices, sx, sy, sz, tx, ty, tz)
end

local function GetCursorTarget()
	local mx, my = GetMouseState()
	local what, data = TraceScreenRay(mx, my, false, true)
	if what == "ground" then
		return data[1], data[2], data[3]
	elseif what == "unit" then
		local x, y, z = GetUnitPosition(data)
		if x then
			return x, y, z
		end
	end
end

------------------------------------------------
--callins
------------------------------------------------
function widget:Initialize()
	for unitDefID, unitDef in pairs(UnitDefs) do
		local weapon = unitDef.weapons and unitDef.weapons[1]
		local wd = weapon and WeaponDefs[weapon.weaponDef]
		if wd and wd.canAttackGround then
			local cp = wd.customParams or {}
			local indirect = cp.howitzer or unitDef.highTrajectoryType == 1
			if indirect then
				local high = (wd.highTrajectory == 1) or (wd.highTrajectory == 2 and unitDef.highTrajectoryType == 1)
				if wd.type == "Cannon" then
					artyDefs[unitDefID] = {1, "cannon", wd, high}
				elseif wd.type == "MissileLauncher" and (wd.trajectoryHeight or 0) > 0 then
					artyDefs[unitDefID] = {1, "rocket", wd, false}
				end
			end
		end
	end
	if not next(artyDefs) then
		WG.RemoveWidget(self)
	end
end

function widget:DrawWorld()
	local _, cmdID = GetActiveCommand()
	if cmdID ~= CMD_ATTACK and cmdID ~= CMD_MANUALFIRE then
		return
	end
	local selected = GetSelectedUnitsSorted()
	local tx, ty, tz
	local count = 0

	for unitDefID, info in pairs(artyDefs) do
		local units = selected[unitDefID]
		if units then
			if not tx then
				tx, ty, tz = GetCursorTarget()
				if not tx then
					return
				end
				glDepthTest(false)
				glLineWidth(lineWidth)
			end
			local build = (info[2] == "cannon") and BuildCannonPath or BuildRocketPath
			for i = 1, #units do
				if count >= maxUnits then
					break
				end
				local unitID = units[i]
				if IsUnitAllied(unitID) then
					local sx, sy, sz = GetUnitWeaponVectors(unitID, info[1])
					if sx then
						count = count + 1
						blockedFrom = nil
						local n = build(sx, sy, sz, tx, ty, tz, info)
						local outOfRange = (tx - sx) ^ 2 + (tz - sz) ^ 2 > info[3].range ^ 2
						if n == 0 or outOfRange then
							DrawUnreachable(sx, sy, sz, tx, ty, tz)
						else
							DrawPath(n)
						end
					end
				end
			end
		end
	end

	if tx then
		glLineWidth(1)
		glColor(1, 1, 1, 1)
	end
end
