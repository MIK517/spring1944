function gadget:GetInfo()
	return {
		name      = "Spawn",
		desc      = "spawns start unit and sets storage levels",
		author    = "Tobi Vollebregt, Craig Lawrence (FLOZi), B. Tyler (Nemo)",
		date      = "January, 2010",
		license   = "GNU GPL, v2 or later",
		layer     = 0,
		enabled   = true  --  loaded by default?
	}
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- synced only
if (not gadgetHandler:IsSyncedCode()) then
	return false
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- localisations
-- SyncedRead
local GetFeaturesInRectangle	= Spring.GetFeaturesInRectangle
local GetGroundHeight			= Spring.GetGroundHeight
local GetSideData				= Spring.GetSideData
local GetTeamInfo				= Spring.GetTeamInfo
local GetTeamRulesParam			= Spring.GetTeamRulesParam
local GetTeamStartPosition		= Spring.GetTeamStartPosition
local GetTeamUnits				= Spring.GetTeamUnits -- backwards compat
local GetUnitDefID				= Spring.GetUnitDefID
local GetUnitPosition			= Spring.GetUnitPosition
local GetUnitsInCylinder		= Spring.GetUnitsInCylinder
local TestBuildOrder			= Spring.TestBuildOrder
local TestMoveOrder				= Spring.TestMoveOrder
local GetPlayerInfo				= Spring.GetPlayerInfo
local GetGameFrame				= Spring.GetGameFrame
-- SyncedCtrl
local CreateUnit				= Spring.CreateUnit
local DestroyFeature			= Spring.DestroyFeature
local SetTeamResource			= Spring.SetTeamResource
local SetTeamRulesParam			= Spring.SetTeamRulesParam


-- constants
-- Each time an invalid position is randomly chosen, spread is multiplied by SPREAD_MULT.
-- If spread reaches MAX_SPREAD, the unit is not deployed AT ALL.
-- (This prevents infinite loops and units being spawned over entire map.)
-- with spread defined in spawnList as 200
-- 1000|1.1 will result in approx. 16 tries before giving up (200 * 1.1^17 > 1000)
-- 1000|1.02 will result in approx. 81 tries before giving up (200 * 1.02^82 > 1000)
-- The max number of tries should at least be higher then the average number
-- of tries required when placing a HQ in the corner of the map.
-- (In this case the search space is reduced by 75% ...)
local MAX_SPREAD = 1000
local SPREAD_MULT = 1.02
-- Minimum distance between any two spawned units.
local CLEARANCE = 125
-- Minimum distance bewteen each unit and the spawn center (HQ position)
local HQ_CLEARANCE = 200
local HALF_MAP_X = Game.mapSizeX/2
local HALF_MAP_Z = Game.mapSizeZ/2
local STARTING_LOGISTICS = 1040 + 1 -- Add 1 storage so losing all storage buildings doesn't cause everything to cease working

local hqDefs = VFS.Include("LuaRules/Configs/hq_spawn.lua")
local modOptions = Spring.GetModOptions()

-- Lobbies hand bool modoptions over as "1"/"0", the engine may hand them over as
-- booleans, and a direct launch omits them entirely.
local function OptionEnabled(value)
	return (value == true) or (value == 1) or (value == "1")
end

local SET_AI_SPAWNS   = OptionEnabled(modOptions.set_ai_spawns)
local SET_AI_FACTIONS = OptionEnabled(modOptions.set_ai_factions)

-- Nations, and which side of the war each one is on. Index 1 of sidedata is the
-- "Random Team (GM)" sandbox pseudo-faction and is never handed out automatically.
local SIDE_ALLIANCE = {}   -- SIDE_ALLIANCE["ger"] = "axis"
local SIDE_POOL     = {}   -- SIDE_POOL["axis"] = {"ger", "ita", ...}
local ALL_SIDES     = {}
do
	local sideDefs = VFS.Include("gamedata/sidedata.lua")
	for i = 1, #sideDefs do
		if i > 1 then
			local name = string.lower(sideDefs[i].name)
			local alliance = sideDefs[i].alliance
			if (alliance == nil) or (alliance == "") then
				alliance = "neutral"
			end
			SIDE_ALLIANCE[name] = alliance
			SIDE_POOL[alliance] = SIDE_POOL[alliance] or {}
			SIDE_POOL[alliance][#SIDE_POOL[alliance] + 1] = name
			ALL_SIDES[#ALL_SIDES + 1] = name
		end
	end
end

-- Positions set explicitly through the ai_start_pos message, and the resolved
-- position each team actually spawned at.
local luaSetStartPositions = {}
local resolvedStartPos = {}
-- How many teams of each allyteam have already been handed an automatic start
-- point, so several of them do not pile onto the same one.
local allyTeamAutoPlaced = {}

local AIUnitReplacementTable = {}

local function IsPositionValid(teamID, unitDefID, x, z)
	-- Don't place units underwater. (this is also checked by TestBuildOrder
	-- but that needs proper maxWaterDepth/floater/etc. in the UnitDef.)
	local y = GetGroundHeight(x, z)
	if (y <= 0) then
		return false
	end
	-- Don't place units where it isn't be possible to build them normally.
	local test = TestBuildOrder(unitDefID, x, y, z, 0)
	if (test ~= 2) then
		return false
	end
	local ud = UnitDefs[unitDefID]
	-- avoid plopping units in places they can't move out of
	if ud.speed > 0 then
		local start = resolvedStartPos[teamID]
		local sx, sy, sz
		if start then
			sx, sy, sz = start[1], start[2], start[3]
		else
			sx, sy, sz = GetTeamStartPosition(teamID)
		end
		local validMoveToStart = TestMoveOrder(unitDefID, x, y, z, sx, sy, sz, true, true)
		if not validMoveToStart then
			return false
		end
	end
	-- Don't place units too close together.
	local units = GetUnitsInCylinder(x, z, CLEARANCE)
	if (units[1] ~= nil) then
		return false
	end
	return true
end

local function ClearUnitPosition(unitID)
	if not unitID then
		Spring.Log('game setup', 'error', "tried to clear unit position with a nil unitID")
		return
	end

	local unitDefID = GetUnitDefID(unitID)
	local ud = UnitDefs[unitDefID]
	
	local px, py, pz = GetUnitPosition(unitID)
	local sideLength = math.max(ud.xsize, ud.zsize) * 7 -- why 14/2?
	local xmin = px - sideLength
	local xmax = px + sideLength
	local zmin = pz - sideLength
	local zmax = pz + sideLength
			
	local features = GetFeaturesInRectangle(xmin, zmin, xmax, zmax)
			
	if features then
		for i = 1, #features do
			DestroyFeature(features[i])
		end
	end
end

local function SpawnBaseUnits(teamID, startUnit, px, pz)
	local isLuaAITeam = ((Spring.GetTeamLuaAI(teamID) or '') ~= '')
	local spawnList = hqDefs[startUnit]
	if spawnList then
		for i = 1, #spawnList.units do
			local unitName = spawnList.units[i]
			local udid = UnitDefNames[unitName].id
			local spread = spawnList.spread
			while (spread < MAX_SPREAD) do
				local dx = math.random(-spread, spread)
				local dz = math.random(-spread, spread)
				local x = px + dx
				local z = pz + dz
				if (dx*dx + dz*dz > HQ_CLEARANCE * HQ_CLEARANCE) and IsPositionValid(teamID, udid, x, z) then
					-- hack to make soviet AIs spawn with static storage instead of deployable truck
					-- and possibly other AI-specific units
					-- facing toward map center
		local facing=math.abs(HALF_MAP_X - x) > math.abs(HALF_MAP_Z - z)
			and ((x > HALF_MAP_X) and "west" or "east")
			or ((z > HALF_MAP_Z) and "north" or "south")
					if AIUnitReplacementTable[unitName] and isLuaAITeam then
						unitName = AIUnitReplacementTable[unitName]
					end
					local unitID = CreateUnit(unitName, x, 0, z, facing, teamID)
					ClearUnitPosition(unitID)
					break
				end
				spread = spread * SPREAD_MULT
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Start positions
--
-- Mirrors how Zero-K resolves a team's spawn (Zero-K/LuaRules/Gadgets/
-- start_unit_setup.lua, GetStartPos / GetRecommendedStartPosition), which matters
-- because the Zero-K launcher always sends startpostype=2 ("choose in game") with
-- no coordinates: nobody places an A.I., so without this every bot keeps the
-- engine default and spawns in the middle of the map.
--------------------------------------------------------------------------------

local MIN_START_SEPARATION = 200
local MIN_START_SEPARATION_SQ = MIN_START_SEPARATION * MIN_START_SEPARATION

local function StartPositionIsTaken(x, z)
	for _, pos in pairs(resolvedStartPos) do
		local dx, dz = pos[1] - x, pos[3] - z
		if (dx * dx + dz * dz) < MIN_START_SEPARATION_SQ then
			return true
		end
	end
	return false
end

-- Record where every team that has already settled on a position will spawn, so
-- automatic placement can steer around them.
local function SeedKnownStartPositions()
	local gaiaTeamID = Spring.GetGaiaTeamID()
	local teams = Spring.GetTeamList()
	for i = 1, #teams do
		local teamID = teams[i]
		if teamID ~= gaiaTeamID then
			local set = luaSetStartPositions[teamID]
			if set then
				resolvedStartPos[teamID] = {set.x, set.y, set.z}
			elseif GetTeamRulesParam(teamID, "valid_startpos") then
				local x, y, z = GetTeamStartPosition(teamID)
				if x then
					resolvedStartPos[teamID] = {x, y, z}
				end
			end
		end
	end
end

-- Hand out a start point of the team's own start box, skipping any point that is
-- already spoken for -- otherwise an AFK player lands on top of the team-mate who
-- placed there. Once every point in the box is taken it falls back to plain
-- recycling, which is what Zero-K does unconditionally.
local function TakeAutoStartPosition(teamID)
	local allyTeamID = select(6, GetTeamInfo(teamID, false))
	local boxID = GetTeamRulesParam(teamID, "start_box_id")
	local boxConfig = boxID and GG.startBoxConfig and GG.startBoxConfig[boxID]
	local startpoints = boxConfig and boxConfig.startpoints

	if not (startpoints and #startpoints > 0) then
		return HALF_MAP_X, GetGroundHeight(HALF_MAP_X, HALF_MAP_Z), HALF_MAP_Z
	end

	local n = allyTeamAutoPlaced[allyTeamID] or 0
	for _ = 1, #startpoints do
		local point = startpoints[(n % #startpoints) + 1]
		n = n + 1
		if not StartPositionIsTaken(point[1], point[2]) then
			allyTeamAutoPlaced[allyTeamID] = n
			return point[1], GetGroundHeight(point[1], point[2]), point[2]
		end
	end

	local index = allyTeamAutoPlaced[allyTeamID] or 0
	allyTeamAutoPlaced[allyTeamID] = index + 1
	local point = startpoints[(index % #startpoints) + 1]
	return point[1], GetGroundHeight(point[1], point[2]), point[2]
end

local function ResolveStartPos(teamID)
	-- 1. an explicit placement from the pre-game UI always wins
	local set = luaSetStartPositions[teamID]
	if set then
		return set.x, set.y, set.z
	end

	local isAI = select(4, GetTeamInfo(teamID, false))
	local x, y, z = GetTeamStartPosition(teamID)

	-- 2. a human who never placed (AFK, or a lobby that does not place at all)
	-- gets a start point of their own box. Native A.I.s are deliberately excluded
	-- here: they can place themselves through AllowStartPosition, where playerID
	-- is 255 and start_boxes.lua cannot attribute the position to a team, so it
	-- never sets valid_startpos even for a perfectly good position.
	if not (GetTeamRulesParam(teamID, "valid_startpos") or isAI) then
		return TakeAutoStartPosition(teamID)
	end

	-- 3. whatever the team ended up with has to be inside its box
	local boxID = isAI and GetTeamRulesParam(teamID, "start_box_id")
	if boxID and GG.CheckStartbox and not GG.CheckStartbox(boxID, x, z) then
		return TakeAutoStartPosition(teamID)
	end

	-- 4. no box to check against, and the engine default was never replaced
	if (not x) or (not z) or ((x <= 0) and (z <= 0)) then
		return TakeAutoStartPosition(teamID)
	end

	return x, y, z
end

--------------------------------------------------------------------------------
-- Nations
--------------------------------------------------------------------------------

-- Which side of the war an allyteam is already committed to, judged by whatever
-- nations on it are settled: a human's pick, a script-supplied side, or a bot that
-- was given one explicitly.
local function GetAllyTeamAlliance(allyTeamID)
	local teams = Spring.GetTeamList(allyTeamID)
	for i = 1, #teams do
		local side = GG.teamSide[teams[i]]
		if (not side) or (side == "") then
			side = select(5, GetTeamInfo(teams[i]))
		end
		local alliance = side and side ~= "" and SIDE_ALLIANCE[string.lower(side)]
		if (alliance == "axis") or (alliance == "allies") then
			return alliance
		end
	end
	return nil
end

-- Random nation, never the sandbox pseudo-faction, and drawn from the allyteam's
-- own side of the war once anything on that allyteam has settled the question.
local function PickRandomSide(teamID)
	local allyTeamID = select(6, GetTeamInfo(teamID, false))
	local pool = SIDE_POOL[GetAllyTeamAlliance(allyTeamID) or ""] or ALL_SIDES
	if #pool == 0 then
		pool = ALL_SIDES
	end
	return pool[math.random(1, #pool)]
end

local function GetStartUnit(teamID)
	-- get the team startup info
	local side = GG.teamSide[teamID]
	if side == "" then side = select(5, GetTeamInfo(teamID)) end
	local startUnit
	if (side == "") then
		-- startscript didn't specify a side for this team
		local sidedata = GetSideData()
		if (sidedata and #sidedata > 0) then
			side = PickRandomSide(teamID)
			startUnit = GetSideData(side)
		end
		-- set the gamerules param to notify other gadgets it was a direct launch
		Spring.SetGameRulesParam("runningWithoutScript", 1)
	else
		startUnit = GetSideData(side)
	end
	-- Check for GM / Random team
	if startUnit == "gmtoolbox" then
		local randSide = PickRandomSide(teamID)
		if (modOptions.gm_team_enable == "0") then
			side, startUnit = randSide, GetSideData(randSide)
		else
			side = randSide
		end
	end
	GG.teamSide[teamID] = side
	SetTeamRulesParam(teamID, "side", side)
	return startUnit
end

local function SpawnStartUnit(teamID)
	local startUnit = GetStartUnit(teamID)
	if (startUnit and startUnit ~= "") then
		-- spawn the specified start unit
		local x,y,z = ResolveStartPos(teamID)
		-- Erase start position marker while we're here
		local mx, my, mz = GetTeamStartPosition(teamID)
		Spring.MarkerErasePosition(mx or 0, my or 0, mz or 0)
		-- snap to 16x16 grid
		x, z = 16*math.floor((x+8)/16), 16*math.floor((z+8)/16)
		y = GetGroundHeight(x, z)
		-- record where we actually put the HQ, so IsPositionValid can path the
		-- rest of the starting units back to it
		resolvedStartPos[teamID] = {x, y, z}
		-- facing toward map center
		local facing=math.abs(HALF_MAP_X - x) > math.abs(HALF_MAP_Z - z)
			and ((x > HALF_MAP_X) and "west" or "east")
			or ((z > HALF_MAP_Z) and "north" or "south")
		
		local unitID = CreateUnit(startUnit, x, y, z, facing, teamID)
		ClearUnitPosition(unitID)
		SpawnBaseUnits(teamID, startUnit, x, z)
	end
end

local function SetStartResources(teamID)
	-- in S44, starting logisticsStorage is always 1k
	SetTeamResource(teamID, "es", STARTING_LOGISTICS)
	-- and teams start with full logistics
	SetTeamResource(teamID, "e", STARTING_LOGISTICS)
	-- commandStorage is set through modOptions, default 1k
	local commandStorage = tonumber(modOptions.command_storage) or 1000
	SetTeamResource(teamID, "ms", commandStorage)
	-- and teams start with 1k command
	SetTeamResource(teamID, "m", 1000)
end

local function InitAIUnitReplacementTable()
	Spring.Log('game setup', 'info', "Loading AI unit replacement tables...")
	local SideFiles = VFS.DirList("luarules/configs/side_ai_unit_replacement", "*.lua")
	Spring.Log('game setup', 'info', "Found "..#SideFiles.." tables")
	-- then add their contents to the main table
	for _, SideFile in pairs(SideFiles) do
		Spring.Log('game setup', 'info', " - Processing "..SideFile)
		local tmpTable = VFS.Include(SideFile)
		if tmpTable then
			local tmpCount = 0
			for unitName, replacementName in pairs(tmpTable) do
				AIUnitReplacementTable[unitName] = replacementName
				tmpCount = tmpCount + 1
			end
			Spring.Log('game setup', 'info', " -- Added "..tmpCount.." entries")
			tmpTable = nil
		end
	end
end

function gadget:Initialize()
	GG.teamSide = {}
	local teams = Spring.GetTeamList()
	for i = 1,#teams do
		local teamID = teams[i]
		-- don't spawn a start unit for the Gaia team
		if (teamID ~= gaiaTeamID) then
			local side = GetTeamRulesParam(teamID, "side")
			if side then
				GG.teamSide[teamID] = side
			else
				GG.teamSide[teamID] = ""
			end
		end
	end
end

function gadget:GameStart()
	local gaiaTeamID = Spring.GetGaiaTeamID()
	local teams = Spring.GetTeamList()

	InitAIUnitReplacementTable()
	SeedKnownStartPositions()

	--Make a global list of the side for each team, because with random faction
	--it is not trivial to find out the side of a team using Spring's API.
	-- data set in GetStartUnit function. NB. The only use for this currently is flags

	-- spawn start units
	for i = 1,#teams do
		local teamID = teams[i]
		-- don't spawn a start unit for the Gaia team
		if (teamID ~= gaiaTeamID) then
			SpawnStartUnit(teamID)
			SetStartResources(teamID)
		end
	end
	-- not needed after spawning everyone
	GG.RemoveGadget(self)
end

--------------------------------------------------------------------------------
-- Pre-game A.I. setup
--------------------------------------------------------------------------------

-- A player may configure an A.I. team if they share its allyteam, if they are the
-- player that added it, or if they are the game host. Spectators never may.
-- In a Zero-K launcher skirmish every A.I. is hosted by player 0, who is also the
-- only human, so all three tests collapse to "you".
local function MayConfigureAITeam(playerID, teamID)
	local _, _, playerIsSpec, playerTeamID = GetPlayerInfo(playerID, false)
	if playerIsSpec then
		return false
	end

	local _, _, _, isAI, _, aiAllyTeamID = GetTeamInfo(teamID, false)
	if not isAI then
		return false
	end

	if playerID == 0 then
		return true -- game host
	end
	if Spring.GetAIInfo and (select(3, Spring.GetAIInfo(teamID)) == playerID) then
		return true -- the player who added this A.I.
	end

	local playerAllyTeamID = select(6, GetTeamInfo(playerTeamID, false))
	return playerAllyTeamID == aiAllyTeamID
end

local function SplitMessage(msg)
	local fields = {}
	for field in string.gmatch(msg, "([^:]+)") do
		fields[#fields + 1] = field
	end
	return fields
end

local function HandleSetAIStartPos(msg, playerID)
	if not SET_AI_SPAWNS then
		return
	end

	local fields = SplitMessage(msg)
	local teamID, x, z = tonumber(fields[2]), tonumber(fields[3]), tonumber(fields[4])
	if (not teamID) or (not x) or (not z) then
		return
	end
	if not MayConfigureAITeam(playerID, teamID) then
		return
	end

	-- Hold A.I.s to the same rule start_boxes.lua holds humans to in
	-- AllowStartPosition: inside your own allyteam's box, or not at all.
	local boxID = GetTeamRulesParam(teamID, "start_box_id")
	if boxID and GG.CheckStartbox and not GG.CheckStartbox(boxID, x, z) then
		return
	end

	luaSetStartPositions[teamID] = {x = x, y = GetGroundHeight(x, z), z = z}
	SetTeamRulesParam(teamID, "ai_start_x", x, {allied = true, public = false})
	SetTeamRulesParam(teamID, "ai_start_z", z, {allied = true, public = false})
	return true
end

local function HandleSetAISide(msg, playerID)
	if not SET_AI_FACTIONS then
		return
	end

	local fields = SplitMessage(msg)
	local teamID = tonumber(fields[2])
	local side = fields[3] and string.lower(fields[3])
	if (not teamID) or (not side) then
		return
	end
	-- SIDE_ALLIANCE only holds the real nations, so this also rejects the
	-- "Random Team (GM)" sandbox pseudo-faction.
	if not SIDE_ALLIANCE[side] then
		return
	end
	if not MayConfigureAITeam(playerID, teamID) then
		return
	end

	GG.teamSide[teamID] = side
	SetTeamRulesParam(teamID, "side", side, {allied = true, public = false})
	return true
end

-- Both settings can be put back to "decide it for me at game start".
local function HandleClearAIStartPos(msg, playerID)
	if not SET_AI_SPAWNS then
		return
	end
	local teamID = tonumber(SplitMessage(msg)[2])
	if (not teamID) or (not MayConfigureAITeam(playerID, teamID)) then
		return
	end
	luaSetStartPositions[teamID] = nil
	-- team rules params cannot be removed, so -1 is the "nothing chosen" value
	SetTeamRulesParam(teamID, "ai_start_x", -1, {allied = true, public = false})
	SetTeamRulesParam(teamID, "ai_start_z", -1, {allied = true, public = false})
	return true
end

local function HandleClearAISide(msg, playerID)
	if not SET_AI_FACTIONS then
		return
	end
	local teamID = tonumber(SplitMessage(msg)[2])
	if (not teamID) or (not MayConfigureAITeam(playerID, teamID)) then
		return
	end
	GG.teamSide[teamID] = ""
	SetTeamRulesParam(teamID, "side", "", {allied = true, public = false})
	return true
end

-- keep track of choosing faction ingame
function gadget:RecvLuaMsg(msg, playerID)
	-- these messages are only useful during pre-game placement
	if GetGameFrame() > 0 then
		return false
	end

	if string.sub(msg, 1, 13) == "ai_start_pos:" then
		return HandleSetAIStartPos(msg, playerID)
	end
	if string.sub(msg, 1, 8) == "ai_side:" then
		return HandleSetAISide(msg, playerID)
	end
	if string.sub(msg, 1, 19) == "ai_clear_start_pos:" then
		return HandleClearAIStartPos(msg, playerID)
	end
	if string.sub(msg, 1, 14) == "ai_clear_side:" then
		return HandleClearAISide(msg, playerID)
	end

	local code = string.sub(msg,1,1)
	if code ~= '\138' then
		return
	end
	local side = string.sub(msg,2,string.len(msg))
	local _, _, playerIsSpec, playerTeam = GetPlayerInfo(playerID)
	if not playerIsSpec then
		GG.teamSide[playerTeam] = side
		SetTeamRulesParam(playerTeam, "side", side, {allied=true, public=false}) -- visible to allies only, set visible to all on GameStart
		side = select(5, GetTeamInfo(playerTeam))
		return true
	end
end
