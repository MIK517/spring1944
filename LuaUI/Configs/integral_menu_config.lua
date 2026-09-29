-- Command panel (gui_chili_integral_menu.lua) configuration for Spring: 1944.
--
-- Follows the structure of Zero-K's integral_menu_config.lua. Differences:
--  * S:44 assigns most custom command IDs at runtime, so commands are also
--    matched by their action name (displayConfigByAction, cmdPosByAction).
--  * State commands without an entry get their icons from the names of their
--    states (stateIconByName), which covers the S:44 weapon and APC toggles.
--  * Build tabs are sorted by what a unit is rather than by Zero-K unit
--    names: yards, support buildings, defences and mobile units.
--  * Factory unit buttons follow the factory's build list; factories with
--    more than eleven options get extra columns (see GetFactoryLayout).

local CMDS = Spring.Utilities.CMD

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Tooltips and icons

local imageDir = 'LuaUI/Images/commands/'
local s44Dir = imageDir .. 's44/'

local function StateTooltips(template, states)
	local result = {}
	for i = 1, #states do
		result[i] = template:gsub("_STATE_", states[i])
	end
	return result
end

local tooltips = {
	REPEAT = "Repeat (_STATE_)\n  Loop factory construction, or the command queue for units.",
	MOVE_STATE = "Move State (_STATE_)\n  Sets how far out of its way a unit will move to attack enemies.",
	FIRE_STATE = "Fire State (_STATE_)\n  Sets when a unit will automatically shoot.",
	TRAJECTORY = "Trajectory (_STATE_)\n  Set whether units fire at a high or low arc.",
	IDLEMODE = "Air Idle State (_STATE_)\n  Set whether aircraft land when idle.",
	SELECTION_RANK = "Selection Rank (_STATE_)\n  Priority for selection filtering.",
}

local commandDisplayConfig = {
	[CMD.ATTACK] = {texture = s44Dir .. 'attack.png', tooltip = "Force Fire: Shoot at a particular target or place. Units will move to find a clear shot."},
	[CMD.STOP] = {texture = s44Dir .. 'stop.png', tooltip = "Stop: Halt the unit and clear its command queue."},
	[CMD.FIGHT] = {texture = s44Dir .. 'fight.png', tooltip = "Attack Move: Move to a position engaging targets along the way."},
	[CMD.GUARD] = {texture = s44Dir .. 'guard.png', tooltip = "Guard: Protect the target and follow it around."},
	[CMD.MOVE] = {texture = s44Dir .. 'move.png', tooltip = "Move: Move to a position, ignoring enemies on the way."},
	[CMD.PATROL] = {texture = s44Dir .. 'patrol.png', tooltip = "Patrol: Attack Move back and forth between one or more waypoints."},
	[CMD.WAIT] = {texture = s44Dir .. 'wait.png', tooltip = "Wait: Pause the unit's command queue and have it hold its current position."},

	[CMD.REPAIR] = {texture = s44Dir .. 'repair.png', tooltip = "Repair: Assist construction or repair a unit. Click and drag for area repair."},
	[CMD.RECLAIM] = {texture = s44Dir .. 'salvage.png', tooltip = "Salvage: Salvage wrecks back into Command Points. Click and drag for an area."},
	[CMD.CAPTURE] = {texture = imageDir .. 'Bold/capture.png', tooltip = "Capture: Take control of abandoned units."},
	[CMD.RESTORE] = {texture = imageDir .. 'Bold/restore.png', tooltip = "Restore: Level the ground in an area back to its original shape."},
	[CMD.MANUALFIRE] = {texture = s44Dir .. 'smoke.png'},
	[CMD.SELFD] = {texture = imageDir .. 'Bold/detonate.png', tooltip = "Detonate: Blow the charge."},

	[CMD.LOAD_UNITS] = {texture = s44Dir .. 'load.png', tooltip = "Load: Pick up a unit. Click and drag to load units in an area."},
	[CMD.UNLOAD_UNITS] = {texture = s44Dir .. 'unload.png', tooltip = "Unload: Set down carried units. Click and drag to unload in an area."},

	-- states
	[CMD.REPEAT] = {
		texture = {s44Dir .. 'repeat_off.png', s44Dir .. 'repeat_on.png'},
		stateTooltip = StateTooltips(tooltips.REPEAT, {"Disabled", "Enabled"}),
	},
	[CMD.MOVE_STATE] = {
		texture = {s44Dir .. 'move_hold.png', s44Dir .. 'move_maneuver.png', s44Dir .. 'move_roam.png'},
		stateTooltip = StateTooltips(tooltips.MOVE_STATE, {"Hold Position", "Maneuver", "Roam"}),
	},
	[CMD.FIRE_STATE] = {
		texture = {s44Dir .. 'fire_hold.png', s44Dir .. 'fire_return.png', s44Dir .. 'fire_atwill.png'},
		stateTooltip = StateTooltips(tooltips.FIRE_STATE, {"Hold Fire", "Return Fire", "Fire At Will"}),
	},
	[CMD.TRAJECTORY] = {
		texture = {imageDir .. 'states/traj_low.png', imageDir .. 'states/traj_high.png'},
		stateTooltip = StateTooltips(tooltips.TRAJECTORY, {"Low", "High"}),
	},
	[CMD.IDLEMODE] = {
		texture = {imageDir .. 'states/fly_off.png', imageDir .. 'states/fly_on.png'},
		stateTooltip = StateTooltips(tooltips.IDLEMODE, {"Land", "Fly"}),
	},
}

if CMDS.SELECTION_RANK then
	commandDisplayConfig[CMDS.SELECTION_RANK] = {
		texture = {imageDir .. 'states/selection_rank_0.png', imageDir .. 'states/selection_rank_1.png', imageDir .. 'states/selection_rank_2.png', imageDir .. 'states/selection_rank_3.png'},
		stateTooltip = StateTooltips(tooltips.SELECTION_RANK, {"0", "1", "2", "3"}),
	}
end

-- S:44 commands, matched by action because their IDs are assigned at runtime.
local displayConfigByAction = {
	areaattack = {texture = imageDir .. 'Bold/areaattack.png', tooltip = "Area Attack: Bombard an area. Click and drag to set its size."},
	settarget = {texture = imageDir .. 'Bold/settarget.png'},
	canceltarget = {texture = imageDir .. 'Bold/canceltarget.png'},
	look = {texture = s44Dir .. 'look.png'},
	turn = {texture = s44Dir .. 'turn.png'},
	clearpath = {texture = s44Dir .. 'clearpath.png'},
	smokegen = {texture = s44Dir .. 'smoke.png'},
	fakefirestate = {
		texture = {s44Dir .. 'fire_hold.png', s44Dir .. 'fire_return.png', s44Dir .. 'fire_atwill.png'},
		stateTooltip = StateTooltips(tooltips.FIRE_STATE, {"Hold Fire", "Return Fire", "Fire At Will"}),
	},
}

-- Icons for state commands by the name of the state, for S:44 toggles whose
-- states come from LuaRules/Configs/toggle_defs.lua and the APC gadget.
local stateIconByName = {
	["Fire HE"] = s44Dir .. 'ammo_he.png',
	["Fire Smoke"] = s44Dir .. 'smoke.png',
	["Prefer HE"] = s44Dir .. 'ammo_he.png',
	["Prefer AP"] = s44Dir .. 'ammo_ap.png',
	["Prefer HEAT"] = s44Dir .. 'ammo_heat.png',
	["Normal"] = s44Dir .. 'swords.png',
	["Ambush"] = s44Dir .. 'eye.png',
	["No APC"] = s44Dir .. 'apc_none.png',
	["All APC"] = s44Dir .. 'apc_all.png',
	["Guns APC"] = s44Dir .. 'apc_guns.png',
	["Beach"] = s44Dir .. 'deploy.png',
	["Unbeach"] = s44Dir .. 'move.png',
	["Hold fire"] = s44Dir .. 'fire_hold.png',
	["Return fire"] = s44Dir .. 'fire_return.png',
	["Fire at will"] = s44Dir .. 'fire_atwill.png',
}
local defaultStateIcon = s44Dir .. 'check.png'

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Command positions
--
-- Commands are placed in their position, with conflicts resolved by pushing
-- those with less priority (higher number = less priority) along the
-- positions if two or more commands want the same position.
-- The command panel is propagated left to right, top to bottom.
-- The state panel is propagated top to bottom, right to left.
-- * States can use posSimple to set a different position when the panel is in
--   four-row mode.
-- * Missing commands have {pos = 1, priority = 100}

local cmdPosDef = {
	-- Movement and combat
	[CMD.STOP]          = {pos = 1, priority = 1},
	[CMD.FIGHT]         = {pos = 1, priority = 2},
	[CMD.MOVE]          = {pos = 1, priority = 3},
	[CMD.PATROL]        = {pos = 1, priority = 4},
	[CMD.ATTACK]        = {pos = 1, priority = 5},
	[CMD.GUARD]         = {pos = 1, priority = 7},

	-- Unit abilities and work
	[CMD.MANUALFIRE]    = {pos = 7, priority = 0.1},
	[CMD.SELFD]         = {pos = 7, priority = 0.2},
	[CMD.REPAIR]        = {pos = 7, priority = 2},
	[CMD.RECLAIM]       = {pos = 7, priority = 3},
	[CMD.CAPTURE]       = {pos = 7, priority = 4},
	[CMD.RESTORE]       = {pos = 7, priority = 4.5},
	[CMD.LOAD_UNITS]    = {pos = 7, priority = 7},
	[CMD.UNLOAD_UNITS]  = {pos = 7, priority = 8},
	[CMD.WAIT]          = {pos = 7, priority = 9},

	-- States
	[CMD.REPEAT]        = {pos = 1, priority = 1},
	[CMD.MOVE_STATE]    = {pos = 5, posSimple = 5, priority = 1},
	[CMD.FIRE_STATE]    = {pos = 5, posSimple = 5, priority = 2},
	[CMD.TRAJECTORY]    = {pos = 1, priority = 14},
	[CMD.IDLEMODE]      = {pos = 1, priority = 18},
}

if CMDS.SELECTION_RANK then
	cmdPosDef[CMDS.SELECTION_RANK] = {pos = 5, posSimple = 1, priority = 1.5}
end

local cmdPosByAction = {
	areaattack     = {pos = 1, priority = 6},
	settarget      = {pos = 1, priority = 8},
	smokegen       = {pos = 7, priority = 0.3},
	deploy         = {pos = 7, priority = 0.5}, -- morph and yard upgrades
	clearpath      = {pos = 7, priority = 1},
	look           = {pos = 7, priority = 5},
	turn           = {pos = 7, priority = 6},
	canceltarget   = {pos = 13, priority = 5},
	-- states
	fakefirestate  = {pos = 5, posSimple = 5, priority = 2.5},
	togglesmoke    = {pos = 1, priority = 11},
	togglepriority = {pos = 1, priority = 12},
	toggleambush   = {pos = 1, priority = 13},
	apc            = {pos = 1, priority = 14.5},
	beach          = {pos = 1, priority = 15},
}
-- Air sortie calls from radio stations (action = sortie unit name).
local sortiePosition = {pos = 13, priority = 1}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Special commands

-- Sortie calls: shown with their stockpile ("N Ready") on the button.
local sortieCommands = {}
for unitDefID, ud in pairs(UnitDefs) do
	if ud.name:find("_sortie_", 1, true) then
		local cmdID = Spring.GetGameRulesParam("CMD_PLANES_" .. unitDefID)
		if cmdID then
			sortieCommands[cmdID] = true
		end
	end
end

-- Morph pseudo units (<side>_morph_<from>_<to>) appear as build options of
-- the units that can morph; the morph itself is a "deploy" command.
local widgetSpaceHidden = {
	[60] = true, -- CMD.PAGES
}
for unitDefID, ud in pairs(UnitDefs) do
	if ud.name:find("_morph_", 1, true) then
		widgetSpaceHidden[-unitDefID] = true
	end
end

local instantCommands = {
	[CMD.SELFD] = true,
	[CMD.STOP] = true,
	[CMD.WAIT] = true,
}
if CMDS.UNIT_CANCEL_TARGET then
	instantCommands[CMDS.UNIT_CANCEL_TARGET] = true
end
if CMDS.SMOKEGEN then
	instantCommands[CMDS.SMOKEGEN] = true
end

-- Units meant to be blown up on purpose (satchel charges): their
-- self-destruct is shown as a Detonate button, but only when every selected
-- unit is one, since the order goes to the whole selection.
local canDetonateDefs = {}
for unitDefID, ud in pairs(UnitDefs) do
	if ud.customParams.candetonate then
		canDetonateDefs[unitDefID] = true
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Build categories

local FACTORY, ECONOMY, DEFENCE = 1, 2, 3
local buildCategory = {} -- [-unitDefID] = category, for structures only

for unitDefID, ud in pairs(UnitDefs) do
	local cp = ud.customParams
	local isStructure = ud.isBuilding or (ud.speed == 0) or (not ud.canMove)
	if ud.isFactory and isStructure then
		buildCategory[-unitDefID] = FACTORY
	elseif isStructure then
		if cp.ismine or cp.isobstacle or cp.candetonate or (#ud.weapons > 0) then
			buildCategory[-unitDefID] = DEFENCE
		else
			buildCategory[-unitDefID] = ECONOMY
		end
	end
end

-- Factory unit panel layout: the factory's build options in its build list
-- order, row by row. Row 2 column 1 (grid key A) is left free when there is
-- room so that A still gives the factory an attack-move rally order, as in
-- Zero-K. Factories with more than eleven options get more columns; grid
-- hotkeys only cover the first rows' keys of the keyboard layout.
local factoryLayoutCache = {}
local function GetFactoryLayout(factoryDefID)
	if factoryLayoutCache[factoryDefID] then
		return factoryLayoutCache[factoryDefID]
	end
	local ud = UnitDefs[factoryDefID]
	local options = {}
	for i = 1, #ud.buildOptions do
		local cmdID = -ud.buildOptions[i]
		if not widgetSpaceHidden[cmdID] then
			options[#options + 1] = cmdID
		end
	end
	local columns = math.max(6, math.ceil(#options / 2))
	local skipSlot = (#options <= 2*columns - 1) and (columns + 1) or nil
	local positions = {}
	local slot = 1
	for i = 1, #options do
		if slot == skipSlot then
			slot = slot + 1
		end
		positions[options[i]] = {row = math.floor((slot - 1)/columns) + 1, col = (slot - 1)%columns + 1}
		slot = slot + 1
	end
	factoryLayoutCache[factoryDefID] = {positions = positions, columns = columns, count = #options}
	return factoryLayoutCache[factoryDefID]
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Panel Configuration and Layout

local function CommandClickFunction(isInstantCommand, isStateCommand)
	local _,_, meta,_ = Spring.GetModKeyState()
	if not meta then
		return false
	end

	if isStateCommand then
		WG.crude.OpenPath("Hotkeys/Commands/State")
	elseif isInstantCommand then
		WG.crude.OpenPath("Hotkeys/Commands/Instant")
	else
		WG.crude.OpenPath("Hotkeys/Commands/Targeted")
	end
	WG.crude.ShowMenu() --make epic Chili menu appear.
	return true
end

local textConfig = {
	bottomLeft = {
		name = "bottomLeft",
		x = "10%",
		right = 0,
		bottom = "10%",
		height = 12,
		fontsize = 12,
	},
	topLeft = {
		name = "topLeft",
		x = "12%",
		y = "11%",
		fontsize = 12,
	},
	bottomRightLarge = {
		name = "bottomRightLarge",
		x = "15%",
		right = "14%",
		bottom = "16%",
		height = 14,
		fontsize = 14,
	},
	queue = {
		name = "queue",
		right = "15%",
		bottom = "15%",
		align = "right",
		fontsize = 16,
		height = 16,
	},
}

local buttonLayoutConfig = {
	command = {
		image = {
			x = "7%",
			y = "7%",
			right = "7%",
			bottom = "7%",
			keepAspect = true,
		},
		noUnitOutline = true,
		ClickFunction = CommandClickFunction,
		tooltipPrefix = "BuildUnit",
	},
	build = {
		image = {
			x = 0,
			y = 0,
			right = 1,
			bottom = 1,
			keepAspect = false,
		},
		tooltipPrefix = "Build",
		invisibleButton = true,
		showCost = true
	},
	buildunit = {
		image = {
			x = 0,
			y = 0,
			right = 1,
			bottom = 1,
			keepAspect = false,
		},
		tooltipPrefix = "BuildUnit",
		invisibleButton = true,
		showCost = true
	},
	queue = {
		image = {
			x = "5%",
			y = "5%",
			right = "5%",
			height = "90%",
			keepAspect = false,
		},
		showCost = false,
		queueButton = true,
		tooltipOverride = "\255\1\255\1Left/Right click \255\255\255\255: Add to/subtract from queue\n\255\1\255\1Hold Left mouse \255\255\255\255: Drag to a different position in queue",
		dragAndDrop = true,
	},
	queueWithDots = {
		image = {
			x = "5%",
			y = "5%",
			right = "5%",
			height = "90%",
			keepAspect = false,
		},
		caption = "...",
		showCost = false,
		queueButton = true,
		tooltipOverride = "\255\1\255\1Left/Right click \255\255\255\255: Add to/subtract from queue\n\255\1\255\1Hold Left mouse \255\255\255\255: Drag to a different position in queue",
		dragAndDrop = true,
		dotDotOnOverflow = true,
	}
}

local function IsStructureOfCategory(cmdID, category)
	return buildCategory[cmdID] == category
end

local commandPanels = {
	{
		humanName = "Orders",
		name = "orders",
		inclusionFunction = function(cmdID, factoryUnitDefID, forceOrdersCommand, unitMobilePanelSize)
			return ((cmdID >= 0 or unitMobilePanelSize == 1) and not buildCategory[cmdID])
		end,
		loiterable = true,
		buttonLayoutConfig = buttonLayoutConfig.command,
	},
	{
		humanName = "Yards",
		name = "factory",
		inclusionFunction = function(cmdID)
			return IsStructureOfCategory(cmdID, FACTORY)
		end,
		isBuild = true,
		isStructure = true,
		gridHotkeys = true,
		returnOnClick = "orders",
		optionName = "tab_factory",
		buttonLayoutConfig = buttonLayoutConfig.build,
	},
	{
		humanName = "Support",
		name = "economy",
		inclusionFunction = function(cmdID)
			return IsStructureOfCategory(cmdID, ECONOMY)
		end,
		isBuild = true,
		isStructure = true,
		gridHotkeys = true,
		returnOnClick = "orders",
		optionName = "tab_economy",
		buttonLayoutConfig = buttonLayoutConfig.build,
	},
	{
		humanName = "Defence",
		name = "defence",
		inclusionFunction = function(cmdID)
			return IsStructureOfCategory(cmdID, DEFENCE)
		end,
		isBuild = true,
		isStructure = true,
		gridHotkeys = true,
		returnOnClick = "orders",
		optionName = "tab_defence",
		buttonLayoutConfig = buttonLayoutConfig.build,
	},
	{
		humanName = "Units",
		name = "units_mobile",
		inclusionFunction = function(cmdID, factoryUnitDefID)
			-- This has to be perfect to predict the size of the units tab in integral menu.
			return (cmdID < 0 and not factoryUnitDefID and not buildCategory[cmdID])
		end,
		isBuild = true,
		gridHotkeys = true,
		returnOnClick = "orders",
		optionName = "tab_units",
		buttonLayoutConfig = buttonLayoutConfig.build,
	},
	{
		humanName = "Units",
		name = "units_factory",
		inclusionFunction = function(cmdID, factoryUnitDefID)
			if not (factoryUnitDefID and cmdID < 0) then
				return false
			end
			local position = GetFactoryLayout(factoryUnitDefID).positions[cmdID]
			return position and true or false, position
		end,
		loiterable = true,
		factoryQueue = true,
		isBuild = true,
		hotkeyReplacement = "Orders",
		gridHotkeys = true,
		disableableKeys = true,
		buttonLayoutConfig = buttonLayoutConfig.buildunit,
	},
}

local commandPanelMap = {}
for i = 1, #commandPanels do
	commandPanelMap[commandPanels[i].name] = commandPanels[i]
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local s44 = {
	displayConfigByAction = displayConfigByAction,
	stateIconByName = stateIconByName,
	defaultStateIcon = defaultStateIcon,
	cmdPosByAction = cmdPosByAction,
	sortiePosition = sortiePosition,
	sortieCommands = sortieCommands,
	canDetonateDefs = canDetonateDefs,
	GetFactoryLayout = GetFactoryLayout,
}

return commandPanels, commandPanelMap, commandDisplayConfig, widgetSpaceHidden, textConfig, buttonLayoutConfig, instantCommands, cmdPosDef, s44
