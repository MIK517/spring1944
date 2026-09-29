--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
	return {
		name      = "1944 UI Debug Log",
		desc      = "Toggleable diagnostic logging of interface events to infolog.txt",
		author    = "Spring: 1944",
		date      = "2026",
		license   = "GNU GPL, v2 or later",
		layer     = -100000,
		enabled   = true,
		api       = true,
		handler   = true,
		alwaysStart = true,
	}
end

--[[
Toggle with the "/luaui s44uidebug" chat command ("on", "off" or no argument to
toggle), or from Settings > Interface > Debug. The state survives restarts
(springsettings key S44UIDebugLog).

While enabled, every line goes to infolog.txt prefixed with [S44UI]; send that
file along with a bug report. Other widgets log through
	WG.S44Debug.Log(section, ...)
which costs nothing while logging is off.
--]]

local CONFIG_KEY = "S44UIDebugLog"
local PREFIX = "[S44UI]"

local spGetGameFrame = Spring.GetGameFrame
local spEcho = Spring.Echo
local strFormat = string.format
local tostring = tostring
local concat = table.concat

local enabled = (Spring.GetConfigInt(CONFIG_KEY, 0) == 1)

--------------------------------------------------------------------------------
-- Formatting

local function ToText(value, depth)
	local t = type(value)
	if t == "table" then
		depth = (depth or 0) + 1
		if depth > 3 then
			return "{...}"
		end
		local parts = {}
		local n = 0
		for k, v in pairs(value) do
			n = n + 1
			if n > 24 then
				parts[#parts + 1] = "..."
				break
			end
			parts[#parts + 1] = tostring(k) .. "=" .. ToText(v, depth)
		end
		return "{" .. concat(parts, ", ") .. "}"
	elseif t == "number" then
		if value == math.floor(value) then
			return tostring(value)
		end
		return strFormat("%.3f", value)
	end
	return tostring(value)
end

local function Log(section, ...)
	if not enabled then
		return
	end
	local args = {...}
	for i = 1, select("#", ...) do
		args[i] = ToText(args[i])
	end
	spEcho(strFormat("%s[f=%d][%s] %s", PREFIX, spGetGameFrame(), tostring(section), concat(args, " ")))
end

--------------------------------------------------------------------------------
-- Snapshot of the environment, written whenever logging is switched on

local function CommandName(cmdID)
	if not cmdID then
		return "nil"
	end
	if cmdID < 0 then
		local ud = UnitDefs[-cmdID]
		return "build:" .. (ud and ud.name or cmdID)
	end
	for name, id in pairs(CMD) do
		if id == cmdID and type(name) == "string" then
			return name
		end
	end
	local selected = Spring.GetSelectedUnits()
	if selected[1] then
		local index = Spring.FindUnitCmdDesc(selected[1], cmdID)
		local desc = index and Spring.GetUnitCmdDescs(selected[1], index, index)
		if desc and desc[1] then
			return (desc[1].action or desc[1].name or "?") .. "(" .. cmdID .. ")"
		end
	end
	return tostring(cmdID)
end

local function DumpEnvironment()
	local GetViewSizes = (Spring.Orig and Spring.Orig.GetViewSizes) or gl.GetViewSizes
	local vsx, vsy = GetViewSizes()
	Log("env", "engine", Engine.versionFull or Engine.version, "game", Game.gameName, Game.gameVersion)
	Log("env", "menu", Spring.GetMenuName and Spring.GetMenuName() or "n/a",
		"spectator", Spring.GetSpectatingState(), "replay", Spring.IsReplay())
	Log("env", "view", vsx, vsy, "uiScale", WG.uiScale, "skin",
		WG.Chili and WG.Chili.theme and WG.Chili.theme.skin.general.skinName)
	local active, inactive = {}, {}
	for name, info in pairs(widgetHandler.knownWidgets) do
		if info.active then
			active[#active + 1] = name
		else
			inactive[#inactive + 1] = name
		end
	end
	table.sort(active)
	table.sort(inactive)
	Log("env", "active widgets:", concat(active, "; "))
	Log("env", "inactive widgets:", concat(inactive, "; "))
end

local function SetEnabled(state)
	enabled = state and true or false
	Spring.SetConfigInt(CONFIG_KEY, enabled and 1 or 0)
	spEcho(PREFIX .. " interface debug logging " .. (enabled and "ON" or "OFF"))
	if enabled then
		DumpEnvironment()
	end
end

--------------------------------------------------------------------------------
-- Exported API

WG.S44Debug = {
	Log = Log,
	ToText = ToText,
	CommandName = CommandName,
	IsEnabled = function() return enabled end,
	SetEnabled = SetEnabled,
}

--------------------------------------------------------------------------------
-- Callins

local function DebugAction(_, _, words)
	local arg = words and words[1]
	if arg == "on" or arg == "1" then
		SetEnabled(true)
	elseif arg == "off" or arg == "0" then
		SetEnabled(false)
	else
		SetEnabled(not enabled)
	end
	return true
end

function widget:Initialize()
	widgetHandler.actionHandler:AddAction(widget, "s44uidebug", DebugAction, nil, "t")
	if enabled then
		spEcho(PREFIX .. " interface debug logging is ON (/luaui s44uidebug to turn off)")
	end
end

function widget:GameStart()
	if enabled then
		DumpEnvironment()
	end
end

function widget:Shutdown()
	widgetHandler.actionHandler:RemoveAction(widget, "s44uidebug")
	WG.S44Debug = nil
end

local lastSelectionText
function widget:SelectionChanged(selection)
	if not enabled then
		return
	end
	local counts = {}
	for i = 1, #selection do
		local ud = UnitDefs[Spring.GetUnitDefID(selection[i]) or -1]
		local name = ud and ud.name or "?"
		counts[name] = (counts[name] or 0) + 1
	end
	local text = ToText(counts)
	if text ~= lastSelectionText then
		lastSelectionText = text
		Log("select", #selection, text)
	end
end

function widget:CommandNotify(cmdID, params, options)
	if enabled then
		Log("command", CommandName(cmdID), params, options and options.coded)
	end
	return false
end

function widget:KeyPress(key, mods, isRepeat, label, unicode, scanCode, actions)
	if enabled and not isRepeat then
		local names = {}
		for i = 1, #(actions or {}) do
			local a = actions[i]
			names[#names + 1] = a.command .. (a.extra ~= "" and (" " .. a.extra) or "")
		end
		Log("key", label, "scan", scanCode, "mods", (mods.alt and "A" or "") .. (mods.ctrl and "C" or "") ..
			(mods.meta and "M" or "") .. (mods.shift and "S" or ""), "actions", concat(names, ", "))
	end
	return false
end

function widget:MousePress(x, y, button)
	if enabled then
		local over = WG.Chili and WG.Chili.Screen0 and WG.Chili.Screen0:IsAbove(x, y)
		Log("mouse", "press", button, x, y, "overChili", over and true or false,
			"activeCmd", CommandName(select(2, Spring.GetActiveCommand())))
	end
	return false
end

function widget:GameOver(winners)
	Log("game", "GameOver", winners)
end

function widget:ViewResize(vsx, vsy)
	Log("env", "ViewResize", vsx, vsy)
end
