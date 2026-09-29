-- Command panel visibility settings for Spring: 1944
-- (Settings/Interface/Commands). Hidden commands still work from their
-- hotkeys.
--
-- S:44 assigns most custom command IDs at runtime; they are looked up in
-- Spring.Utilities.CMD (see LuaRules/Configs/customcmds.lua). Their menu
-- option keys use the command's name instead of its ID, so a saved choice
-- survives changes in ID assignment.

local CMDS = Spring.Utilities.CMD

local function S44(name, data)
	data.cmdID = CMDS[name]
	data.key = "cmd_s44_" .. name:lower()
	if data.cmdID then
		return data
	end
	return nil
end

local configList = {
	{label = "Basic Commands"},
	S44("AREAATTACK",                  {default = true, name = "Area Attack"}),
	{cmdID = CMD.FIGHT                 , default = true, name = "Attack Move"},
	S44("CLEARPATH",                   {default = true, name = "Clear Path"}),
	{cmdID = CMD.ATTACK                , default = true, name = "Force Fire"},
	{cmdID = CMD.GUARD                 , default = true, name = "Guard"},
	{cmdID = CMD.LOAD_UNITS            , default = true, name = "Load"},
	{cmdID = CMD.MOVE                  , default = true, name = "Move"},
	{cmdID = CMD.PATROL                , default = true, name = "Patrol"},
	{cmdID = CMD.REPAIR                , default = true, name = "Repair"},
	{cmdID = CMD.RECLAIM               , default = true, name = "Salvage"},
	{cmdID = CMD.MANUALFIRE            , default = true, name = "Smoke Grenade / Special Weapon"},
	S44("SMOKEGEN",                    {default = true, name = "Smoke Screen"}),
	{cmdID = CMD.STOP                  , default = true, name = "Stop"},
	S44("TURN",                        {default = true, name = "Turn"}),
	{cmdID = CMD.UNLOAD_UNITS          , default = true, name = "Unload"},

	{label = "Advanced Commands (hidden by default)"},
	S44("UNIT_CANCEL_TARGET",          {default = false, name = "Cancel Target"}),
	{cmdID = CMD.CAPTURE               , default = false, name = "Capture (right click does this on abandoned units)"},
	S44("LOOK",                        {default = false, name = "Look (Binoculars)"}),
	{cmdID = CMD.RESTORE               , default = false, name = "Restore Terrain"},
	S44("UNIT_SET_TARGET",             {default = false, name = "Set Target"}),
	{cmdID = CMD.WAIT                  , default = false, name = "Wait"},

	{label = "Basic States"},
	S44("APC",                         {state = true, default = true, name = "APC Mode"}),
	S44("TOGGLE_PRIORITY",             {state = true, default = true, name = "Ammunition Priority"}),
	S44("TOGGLE_AMBUSH",               {state = true, default = true, name = "Ambush Mode"}),
	S44("BEACH",                       {state = true, default = true, name = "Beach"}),
	{cmdID = CMD.FIRE_STATE            , state = true, default = true, name = "Fire State"},
	S44("FAKE_FIRE_STATE",             {state = true, default = true, name = "Fire State (Gun Crew)"}),
	S44("TOGGLE_SMOKE",                {state = true, default = true, name = "HE / Smoke Rounds"}),
	{cmdID = CMD.MOVE_STATE            , state = true, default = true, name = "Move State"},
	{cmdID = CMD.REPEAT                , state = true, default = true, name = "Repeat"},
	{cmdID = CMD.TRAJECTORY            , state = true, default = true, name = "Trajectory"},
	{cmdID = CMD.IDLEMODE              , state = true, default = true, name = "Air Idle State"},

	{label = "Advanced States (hidden by default)"},
	{cmdID = CMDS.SELECTION_RANK       , state = true, default = false, name = "Selection Rank"},
}

-- S44() returns nil for commands the game does not define; compact the list.
local compacted = {}
for i = 1, table.maxn(configList) do
	if configList[i] then
		compacted[#compacted + 1] = configList[i]
	end
end
configList = compacted

local defaultValues = {}
for i = 1, #configList do
	local data = configList[i]
	if data.cmdID and not data.default then
		defaultValues[data.cmdID] = true
	end
end

return configList, defaultValues
