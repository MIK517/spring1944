-- Action names of unit commands, for hotkey management in the EPIC Menu.
-- These names cannot be typed as chat commands (e.g. /fight does nothing),
-- but they can be bound to keys (e.g. "bind f fight"), and
-- Spring.GetActionHotKeys(name) returns the keys bound to them.
--
-- cmdType:
--   1: Targeted commands (eg attack)
--   2: State commands (eg fire state). The optional 'states' list creates
--      extra actions that set one particular state.
--   3: Instant commands (eg stop)
--
-- Names match Zero-K's where the command is the same, so hotkeys imported
-- from a Zero-K configuration land on the same command.

-- S:44 assigns most custom command IDs at runtime and publishes them as game
-- rules params (see LuaRules/Gadgets/0_api_customCmdHandler.lua).
local function RulesCmdID(name)
	return Spring.GetGameRulesParam(name)
end

local custom_cmd_actions = {
	-- Engine commands
	selfd = {cmdType = 3, name = "Self Destruct / Detonate"},
	attack = {cmdType = 1, name = "Force Fire"},
	stop = {cmdType = 3, name = "Stop"},
	fight = {cmdType = 1, name = "Attack Move"},
	guard = {cmdType = 1, name = "Guard"},
	move = {cmdType = 1, name = "Move"},
	patrol = {cmdType = 1, name = "Patrol"},
	wait = {cmdType = 3, name = "Wait"},
	timewait = {cmdType = 3, name = "Wait: Timer"},
	deathwait = {cmdType = 3, name = "Wait: Death"},
	squadwait = {cmdType = 3, name = "Wait: Squad"},
	gatherwait = {cmdType = 3, name = "Wait: Gather"},
	repair = {cmdType = 1, name = "Repair"},
	reclaim = {cmdType = 1, name = "Salvage"},
	capture = {cmdType = 1, name = "Capture"},
	manualfire = {cmdType = 1, name = "Smoke Grenade / Special Weapon"},
	loadunits = {cmdType = 1, name = "Load Units"},
	unloadunits = {cmdType = 1, name = "Unload Units"},

	-- Engine states
	['repeat'] = {cmdType = 2, cmdID = CMD.REPEAT, name = "Repeat", states = {'Off', 'On'}},
	movestate = {cmdType = 2, cmdID = CMD.MOVE_STATE, name = "Move State", states = {'Hold Position', 'Maneuver', 'Roam'}},
	firestate = {cmdType = 2, cmdID = CMD.FIRE_STATE, name = "Fire State", states = {'Hold Fire', 'Return Fire', 'Fire At Will'}},
	idlemode = {cmdType = 2, cmdID = CMD.IDLEMODE, name = "Air Idle State", states = {'Land', 'Fly'}},
	trajectory = {cmdType = 2, cmdID = CMD.TRAJECTORY, name = "Trajectory", states = {'Low', 'High'}},

	-- Spring: 1944 commands
	areaattack = {cmdType = 1, name = "Area Attack"},
	settarget = {cmdType = 1, name = "Set Target"},
	canceltarget = {cmdType = 3, name = "Cancel Target"},
	look = {cmdType = 1, name = "Look (Binoculars)"},
	turn = {cmdType = 1, name = "Turn"},
	clearpath = {cmdType = 1, name = "Clear Path"},
	smokegen = {cmdType = 3, name = "Smoke Screen"},
	deploy = {cmdType = 3, name = "Deploy / Morph"},

	-- Spring: 1944 states
	fakefirestate = {cmdType = 2, cmdID = RulesCmdID("CMD_FAKE_FIRE_STATE"), name = "Fire State (Gun Crew)", states = {'Hold Fire', 'Return Fire', 'Fire At Will'}},
	apc = {cmdType = 2, cmdID = RulesCmdID("CMD_APC"), name = "APC Mode"},
	beach = {cmdType = 2, cmdID = RulesCmdID("CMD_BEACH"), name = "Beach", states = {'Beach', 'Unbeach'}},
	togglesmoke = {cmdType = 2, cmdID = RulesCmdID("CMD_TOGGLE_SMOKE"), name = "HE / Smoke Rounds", states = {'Fire HE', 'Fire Smoke'}},
	toggleambush = {cmdType = 2, cmdID = RulesCmdID("CMD_TOGGLE_AMBUSH"), name = "Ambush Mode", states = {'Normal', 'Ambush'}},
	togglepriority = {cmdType = 2, name = "Ammunition Priority"},
}

-- Add toggle-to-particular-state actions, e.g. "firestate 0".
local fullCustomCmdActions = {}
for name, data in pairs(custom_cmd_actions) do
	if data.states then
		for i = 1, #data.states do
			fullCustomCmdActions[name .. " " .. (i - 1)] = {
				cmdType = data.cmdType,
				name = data.name .. ": set " .. data.states[i],
				setValue = (i - 1),
				cmdID = data.cmdID,
			}
		end
		data.name = data.name .. ": toggle"
	end
	fullCustomCmdActions[name] = data
end

return fullCustomCmdActions
