local versionNumber = "v2.0"

function widget:GetInfo()
	return {
		name = "1944 Field of Fire",
		desc = versionNumber .. " Indicates field of fire for guns and marks the ground they can actually hit.",
		author = "Evil4Zerggin",
		date = "5 January 2009",
		license = "GNU LGPL, v2.1 or later",
		layer = 1,
		enabled = true
	}
end

------------------------------------------------
--config
------------------------------------------------
local alpha = 1
local color = {1, 0.5, 0, alpha}
local lineWidth = 1
local divsPerRadian = 16

-- Targetable ground markers (engine range/arc + line of fire checks)
local probeColorOk = {0.35, 1, 0.35, 0.85}
local probeColorBlocked = {1, 0.25, 0.25, 0.65}
local probePointSize = 4
local probeInterval = 0.5      -- seconds between re-probes
local probeMaxUnits = 4        -- selected units probed at once
local probeRings = 10
local probeSpacingFrac = 0.1   -- point spacing along a ring, fraction of range
local probeMaxPointsPerRing = 24
local probeArcShrink = 0.98    -- stay just inside the arc edge

------------------------------------------------
--vars
------------------------------------------------
-- format: unitDefID = {list, range}
local unitDefInfos = {}   -- arc drawn at the unit itself
local deployInfos = {}    -- arc drawn at the Deploy command preview
-- format: unitDefID = {halfAngle, range}
local probeDefs = {}

local lists = {}

local probes = {}         -- unitID = {n, x1, y1, z1, ok1, ...}
local probeTimer = probeInterval

------------------------------------------------
--speedups
------------------------------------------------
local FindUnitCmdDesc = Spring.FindUnitCmdDesc
local GetActiveCommand = Spring.GetActiveCommand
local GetMouseState = Spring.GetMouseState
local GetSelectedUnitsSorted = Spring.GetSelectedUnitsSorted
local GetUnitDefID = Spring.GetUnitDefID
local GetUnitHeading = Spring.GetUnitHeading
local GetUnitPosition = Spring.GetUnitPosition
local GetUnitDirection = Spring.GetUnitDirection
local GetGroundHeight = Spring.GetGroundHeight
local GetUnitWeaponTestRange = Spring.GetUnitWeaponTestRange
local GetUnitWeaponHaveFreeLineOfFire = Spring.GetUnitWeaponHaveFreeLineOfFire
local GetUnitWeaponVectors = Spring.GetUnitWeaponVectors
local IsUnitAllied = Spring.IsUnitAllied
local TraceScreenRay = Spring.TraceScreenRay

local glLineWidth = gl.LineWidth
local glColor = gl.Color
local glPointSize = gl.PointSize
local glBeginEnd = gl.BeginEnd
local glVertex = gl.Vertex

local glCreateList = gl.CreateList
local glCallList = gl.CallList
local glDeleteList = gl.DeleteList

local glPushMatrix = gl.PushMatrix
local glPopMatrix = gl.PopMatrix
local glTranslate = gl.Translate
local glRotate = gl.Rotate
local glScale = gl.Scale

local glShape = gl.Shape

local glDepthTest = gl.DepthTest

local vHeadingToDegrees
local GetUnitActiveCommandPosition

local acos = math.acos
local sin, cos = math.sin, math.cos
local atan2 = math.atan2
local ceil, min, max = math.ceil, math.min, math.max
local sqrt = math.sqrt

local GL_LINE_STRIP = GL.LINE_STRIP
local GL_LINE_LOOP = GL.LINE_LOOP
local GL_POINTS = GL.POINTS

local MAP_X = Game.mapSizeX
local MAP_Z = Game.mapSizeZ

------------------------------------------------
--helper functions
------------------------------------------------

local function DrawMobile(maxAngleDif)
	local vertices = {
		{v = {0, 0, 0}},
	}

	local angle = acos(maxAngleDif)
	local divs = ceil(2 * angle * divsPerRadian)
	local angleIncrement = 2 * angle / divs
	local i = 2
	for j = 0, divs do
		vertices[i] = {v = {sin(angle), 0, cos(angle)}}
		angle = angle - angleIncrement
		i = i + 1
	end

	glShape(GL_LINE_LOOP, vertices)
end

local function DrawStationary(maxAngleDif)
	local length = maxAngleDif
	local width = sqrt(1 - maxAngleDif * maxAngleDif)
	local vertices = {
		{v = {-width, 0, length}},
		{v = {0, 0, 0}},
		{v = {width, 0, length}},
	}

	glShape(GL_LINE_STRIP, vertices)
end

local function GetList(maxAngleDif, stationary)
	local key = (stationary and "s" or "m") .. maxAngleDif
	local list = lists[key]
	if not list then
		list = glCreateList(stationary and DrawStationary or DrawMobile, maxAngleDif)
		lists[key] = list
	end
	return list
end

local function DrawFieldOfFire2(x, y, z, list, range, rotation)
	glPushMatrix()
		glTranslate(x, y, z)
		glRotate(rotation, 0, 1, 0)
		glScale(range, range, range)
		glCallList(list)
	glPopMatrix()
end

local function DrawFieldOfFire(unitID, list, range)
	local x, y, z = GetUnitPosition(unitID)
	local rotation = vHeadingToDegrees(GetUnitHeading(unitID))

	return DrawFieldOfFire2(x, y, z, list, range, rotation)
end

-- Weapon 1 arc as the cosine the engine uses (UnitDefs maxAngleDif), or nil
-- for units that have no limited arc or hide it.
local function GetUnitDefArc(unitDef)
	local cp = unitDef.customParams
	if cp and cp.hidefirearc then return end
	local weapon1 = unitDef.weapons and unitDef.weapons[1]
	if not weapon1 then return end
	local maxAngleDif = weapon1.maxAngleDif
	if not maxAngleDif or maxAngleDif <= 0 then return end -- only arcs under 180 deg
	return maxAngleDif, weapon1
end

local function GetBasename(name)
	local underscoreIndex = name:find("_")
	if underscoreIndex then
		return name:sub(1, underscoreIndex - 1)
	end
	return name
end

-- Guns: deployed (immobile) units and crewed guns
local function ShowsOwnArc(unitDef)
	local cp = unitDef.customParams
	return unitDef.speed == 0 or (cp and cp.infgun)
end

------------------------------------------------
--probing
------------------------------------------------

local function ProbeUnit(unitID, probeDef)
	local halfAngle, range = probeDef[1], probeDef[2]
	local ux, uy, uz = GetUnitPosition(unitID)
	local dx, _, dz = GetUnitDirection(unitID)
	local sx, sy, sz = GetUnitWeaponVectors(unitID, 1)
	if not (ux and dx and sx) then
		return nil
	end
	local baseAngle = atan2(dx, dz)
	local spacing = range * probeSpacingFrac
	local result = probes[unitID] or {}
	local n = 0
	for ring = 1, probeRings do
		local r = range * ring / probeRings
		local steps = min(probeMaxPointsPerRing, max(1, ceil(2 * halfAngle * r / spacing)))
		for step = 0, steps do
			local a = baseAngle - halfAngle + 2 * halfAngle * step / steps
			local x = ux + sin(a) * r
			local z = uz + cos(a) * r
			if x >= 0 and z >= 0 and x <= MAP_X and z <= MAP_Z then
				local y = GetGroundHeight(x, z)
				local ok = GetUnitWeaponTestRange(unitID, 1, x, y, z)
					and GetUnitWeaponHaveFreeLineOfFire(unitID, 1, sx, sy, sz, x, y, z)
				result[n + 1], result[n + 2], result[n + 3], result[n + 4] = x, y + 2, z, ok and true or false
				n = n + 4
			end
		end
	end
	result.n = n
	return result
end

local function UpdateProbes(selectedUnitsSorted)
	local oldProbes = probes
	probes = {}
	local count = 0
	for unitDefID, probeDef in pairs(probeDefs) do
		local units = selectedUnitsSorted[unitDefID]
		if units then
			for i = 1, #units do
				if count >= probeMaxUnits then
					return
				end
				local unitID = units[i]
				if IsUnitAllied(unitID) then
					probes[unitID] = oldProbes[unitID] -- reuse the table
					probes[unitID] = ProbeUnit(unitID, probeDef)
					count = count + 1
				end
			end
		end
	end
end

local function DrawProbePoints(probe, wantOk)
	for i = 1, probe.n, 4 do
		if probe[i + 3] == wantOk then
			glVertex(probe[i], probe[i + 1], probe[i + 2])
		end
	end
end

local function DrawProbes()
	if not next(probes) then
		return
	end
	glPointSize(probePointSize)
	for _, probe in pairs(probes) do
		glColor(probeColorBlocked)
		glBeginEnd(GL_POINTS, DrawProbePoints, probe, false)
		glColor(probeColorOk)
		glBeginEnd(GL_POINTS, DrawProbePoints, probe, true)
	end
	glPointSize(1)
end

------------------------------------------------
--callins
------------------------------------------------
function widget:Initialize()
	vHeadingToDegrees = WG.Vector.HeadingToDegrees
	GetUnitActiveCommandPosition = WG.CmdQueue.GetUnitActiveCommandPosition

	-- Units showing their own weapon arc
	local ownInfos = {}
	for unitDefID, unitDef in pairs(UnitDefs) do
		if ShowsOwnArc(unitDef) then
			local maxAngleDif, weapon1 = GetUnitDefArc(unitDef)
			if maxAngleDif then
				local range = unitDef.maxWeaponRange
				ownInfos[unitDefID] = {GetList(maxAngleDif, unitDef.speed == 0), range, maxAngleDif}
				unitDefInfos[unitDefID] = ownInfos[unitDefID]
				local weaponDef = WeaponDefs[weapon1.weaponDef]
				local cp = unitDef.customParams
				if weaponDef and weaponDef.canAttackGround
						and ((cp and cp.infgun) or unitDef.iconType == "artillery") then
					probeDefs[unitDefID] = {acos(maxAngleDif) * probeArcShrink, weaponDef.range}
				end
			end
		end
	end

	local deployedByBasename = {}
	for unitDefID = 1, #UnitDefs do
		local unitDef = UnitDefs[unitDefID]
		if unitDef.speed == 0 and ownInfos[unitDefID] then
			local basename = GetBasename(unitDef.name)
			deployedByBasename[basename] = deployedByBasename[basename] or ownInfos[unitDefID]
		end
	end

	-- Deploy previews and trucks: borrow the arc of what they turn into
	for unitDefID, unitDef in pairs(UnitDefs) do
		if unitDef.speed > 0 then
			local name = unitDef.name
			if ownInfos[unitDefID] then
				local deployed = UnitDefNames[name .. "_stationary"]
				if deployed and ownInfos[deployed.id] then
					deployInfos[unitDefID] = ownInfos[deployed.id]
				end
			else
				local base = name:gsub("_truck$", ""):gsub("_mobile$", "")
				local targetInfo
				for _, targetName in ipairs({base, base .. "_stationary"}) do
					local target = UnitDefNames[targetName]
					targetInfo = target and target.id ~= unitDefID and ownInfos[target.id]
					if targetInfo then
						break
					end
				end
				-- other deploy pairs (e.g. HMG teams -> *_sandbag): same name
				-- up to the first underscore, deployed (immobile) form
				targetInfo = targetInfo or deployedByBasename[GetBasename(name)]
				if targetInfo then
					unitDefInfos[unitDefID] = {GetList(targetInfo[3], false), targetInfo[2]}
					deployInfos[unitDefID] = targetInfo
				end
			end
		end
	end

	--remove self if unused
	if not next(unitDefInfos) then
		WG.RemoveWidget(self)
	end
end

function widget:Shutdown()
	for _, list in pairs(lists) do
		glDeleteList(list)
	end
end

function widget:Update(dt)
	probeTimer = probeTimer + dt
	if probeTimer < probeInterval then
		return
	end
	probeTimer = 0
	UpdateProbes(GetSelectedUnitsSorted())
end

function widget:SelectionChanged()
	-- re-probe right away for the new selection
	probeTimer = probeInterval
end

function widget:DrawWorld()
	glColor(color)
	glLineWidth(lineWidth)
	glDepthTest(false)

	local selectedUnitsSorted = GetSelectedUnitsSorted()

	local tx, tz
	local _, cmdDescID, _, cmdDescName = GetActiveCommand()
	local inDeployCmd = (cmdDescName == "Deploy")

	if inDeployCmd then
		local mx, my = GetMouseState()
		local what, coors = TraceScreenRay(mx, my, true)
		if (what == "ground") then
			tx, tz = coors[1], coors[3]
		else
			inDeployCmd = false
		end
	end

	for unitDefID, info in pairs(unitDefInfos) do
		local units = selectedUnitsSorted[unitDefID]
		if units then
			local deployInfo = deployInfos[unitDefID]
			for i=1,#units do
				local unitID = units[i]
				if GetUnitDefID(unitID) then
					if inDeployCmd and deployInfo and FindUnitCmdDesc(unitID, cmdDescID) then
						local ux, uy, uz = GetUnitActiveCommandPosition(unitID)
						local dx, dz = tx - ux, tz - uz
						local rotation = atan2(dx, dz) * (180 / math.pi)
						DrawFieldOfFire2(ux, uy, uz, deployInfo[1], deployInfo[2], rotation)
					else
						DrawFieldOfFire(unitID, info[1], info[2])
					end
				end
			end
		end
	end

	DrawProbes()

	glLineWidth(1)
	glColor(1, 1, 1, 1)
end
