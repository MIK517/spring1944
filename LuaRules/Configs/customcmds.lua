-- Custom command IDs, keyed by name without the CMD_ prefix, for code that
-- expects Zero-K's Spring.Utilities.CMD table.
--
-- S:44 hands out most custom command IDs at runtime (see
-- LuaRules/Gadgets/0_api_customCmdHandler.lua) and publishes each one as a
-- game rules param named after the command, e.g. "CMD_MORPH". Unknown names
-- resolve to nil, so Zero-K code that tests for its own commands simply finds
-- nothing.

local commands = {
	-- Fixed IDs used by LuaUI (10000 - 19999 is the LuaUI range)
	SELECTION_RANK = 13987,
	MISC_BUILD = 25612, -- integral menu pseudo command
}

local dynamicNames = {
	"SET_WANTED_MAX_SPEED",
	"APC",
	"AREAATTACK",
	"BEACH",
	"CLEARPATH",
	"FAKE_FIRE_STATE",
	"LOOK",
	"MORPH",
	"MORPH_STOP",
	"PLANES",
	"SMOKEGEN",
	"TOGGLE_AMBUSH",
	"TOGGLE_PRIORITY",
	"TOGGLE_SMOKE",
	"TURN",
	"UNIT_CANCEL_TARGET",
	"UNIT_SET_TARGET",
}

local GetGameRulesParam = Spring.GetGameRulesParam
if GetGameRulesParam then
	for i = 1, #dynamicNames do
		local name = dynamicNames[i]
		local cmdID = GetGameRulesParam("CMD_" .. name)
		if cmdID then
			commands[name] = cmdID
		end
	end
end

return commands
