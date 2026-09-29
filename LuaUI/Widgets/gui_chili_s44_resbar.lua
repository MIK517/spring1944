--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
	return {
		name      = "1944 Resource Bars",
		desc      = "Command Points and Logistics panel for Spring: 1944, in the style of Zero-K's economy panel.",
		author    = "Evil4Zerggin, Jose Luis Cercos-Pita (Zero-K style rework)",
		date      = "2026-09-29",
		license   = "GNU GPL, v2 or later",
		layer     = 1,
		enabled   = true,
	}
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- S:44 has two resources. Metal is Command Points: income comes from flags and
-- is spent on units. Energy is Logistics: its storage is refilled every
-- resupply period and units draw ammunition from it.

local IMAGE_COMMAND = "LuaUI/Images/resources/command.png"
local IMAGE_LOGISTICS = "LuaUI/Images/resources/logistics.png"
local IMAGE_SHARE = "LuaUI/Images/ResBar/share_thumb.png"

local COMMAND_COLOR = {0.72, 0.70, 0.62, 1}
local LOGISTICS_COLOR = {0.92, 0.80, 0.18, 1}
local LOGISTICS_LOW_COLOR = {0.92, 0.35, 0.12, 1}
local LOGISTICS_LOW_FRACTION = 0.15

local positiveColourStr = "\255\96\255\96"
local negativeColourStr = "\255\255\96\96"
local neutralColourStr = "\255\210\200\170"
local greenStr = "\255\1\255\1"
local whiteStr = "\255\255\255\255"

local spGetTeamResources = Spring.GetTeamResources
local spGetMyTeamID = Spring.GetMyTeamID
local spGetModKeyState = Spring.GetModKeyState
local spSetShareLevel = Spring.SetShareLevel
local spGetSpectatingState = Spring.GetSpectatingState

local strFormat = string.format
local floor, ceil = math.floor, math.ceil

local Chili
local window
local panels = {}

local CreateWindow

local resupplyPeriod = 450 * 30
local UPDATE_PERIOD = 6 -- frames

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Options

local function RecreateWindow()
	if not window then
		return
	end
	local x, y, w, h = window.x, window.y, window.width, window.height
	window:Dispose()
	window = nil
	CreateWindow(x, y, w, h)
end

options_path = 'Settings/HUD Panels/Economy Panel'
options_order = {'opacity', 'fontSize', 'showShareMarker'}
options = {
	opacity = {
		name = "Opacity",
		type = "number",
		value = 0.8, min = 0, max = 1, step = 0.01,
		update_on_the_fly = true,
		OnChange = function(self)
			for _, panel in pairs(panels) do
				panel.holder.backgroundColor = {1, 1, 1, self.value}
				panel.holder:Invalidate()
			end
		end,
	},
	fontSize = {
		name = "Font Size",
		type = "number",
		value = 18, min = 8, max = 30, step = 1,
		OnChange = RecreateWindow,
	},
	showShareMarker = {
		name = "Show share level marker",
		desc = "Show where the share level is on each bar. Resources above the share level are given to allies.",
		type = "bool",
		value = true,
		noHotkey = true,
		OnChange = RecreateWindow,
	},
}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Utilities

local function Format(value)
	value = value or 0
	local absValue = math.abs(value)
	if absValue >= 1000000000 then
		return strFormat("%.3gG", value / 1000000000)
	elseif absValue >= 1000000 then
		return strFormat("%.3gM", value / 1000000)
	elseif absValue >= 100000 then
		return strFormat("%dk", value / 1000)
	elseif absValue >= 10000 then
		return strFormat("%.1fk", value / 1000)
	elseif absValue >= 100 or value == floor(value) then
		return strFormat("%d", value)
	end
	return strFormat("%.1f", value)
end

local function FramesToTimeString(n)
	local seconds = ceil(n / 30)
	return strFormat("%d:%02d", floor(seconds / 60), seconds % 60)
end

local function OpenOptionsOnSpaceClick()
	local _, _, meta = spGetModKeyState()
	if not meta then
		return false
	end
	WG.crude.OpenPath(options_path)
	WG.crude.ShowMenu()
	return true
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Panels

local function SetShareFromMouse(panel, bar, x)
	local width = bar.width
	if width <= 0 then
		return
	end
	local level = math.max(0, math.min(1, x / width))
	spSetShareLevel(panel.resource, level)
	panel.UpdateShareMarker(level)
end

local function GetResourcePanel(parent, resource, x, image, color, fancySkin)
	local fontSize = options.fontSize.value
	local panel = {resource = resource}
	local draggingShare = false

	local holder = Chili.Panel:New{
		classname = fancySkin,
		parent = parent,
		x = x,
		y = 0,
		width = "50%",
		bottom = 0,
		padding = {4, 3, 4, 3},
		backgroundColor = {1, 1, 1, options.opacity.value},
		noClickThrough = true,
		OnMouseDown = {OpenOptionsOnSpaceClick},
	}
	panel.holder = holder

	Chili.Image:New{
		parent = holder,
		x = "1%",
		y = "8%",
		width = "15%",
		bottom = "8%",
		keepAspect = true,
		file = image,
	}

	local bar = Chili.Progressbar:New{
		parent = holder,
		x = "17%",
		y = "6%",
		right = "3%",
		height = "46%",
		color = color,
		value = 0,
		max = 1,
		caption = "",
		-- Chili only sends mouse events to controls that take clicks.
		noClickThrough = true,
		objectOverrideFont = WG.GetSpecialFont(fontSize - 2, "s44res_bar", {
			outline = true, color = {0.9, 0.9, 0.9, 0.95}, outlineWidth = 2, outlineWeight = 2,
		}),
		OnMouseDown = {function(self, mx, my, button)
			if OpenOptionsOnSpaceClick() then
				return true
			end
			local _, ctrl = spGetModKeyState()
			if ctrl and button == 1 and not spGetSpectatingState() then
				draggingShare = true
				SetShareFromMouse(panel, self, mx)
				return true
			end
			return false
		end},
		OnMouseMove = {function(self, mx)
			if draggingShare then
				SetShareFromMouse(panel, self, mx)
			end
		end},
		OnMouseUp = {function(self, mx)
			if draggingShare then
				SetShareFromMouse(panel, self, mx)
				draggingShare = false
			end
		end},
	}
	panel.bar = bar

	local shareMarker
	if options.showShareMarker.value then
		shareMarker = Chili.Image:New{
			parent = bar,
			x = 0,
			y = 0,
			width = 10,
			bottom = 0,
			keepAspect = false,
			file = IMAGE_SHARE,
		}
	end

	function panel.UpdateShareMarker(level)
		if not shareMarker then
			return
		end
		local barWidth = bar.width
		if barWidth <= 0 then
			return
		end
		local markerX = floor(level * barWidth - shareMarker.width / 2 + 0.5)
		markerX = math.max(0, math.min(barWidth - shareMarker.width, markerX))
		if markerX ~= shareMarker.x then
			shareMarker:SetPos(markerX)
		end
	end

	local leftLabel = Chili.Label:New{
		parent = holder,
		x = "18%",
		y = "56%",
		width = "40%",
		bottom = 0,
		valign = "center",
		align = "left",
		caption = "",
		objectOverrideFont = WG.GetSpecialFont(fontSize, "s44res_text", {
			outline = true, outlineWidth = 2, outlineWeight = 2,
		}),
	}
	local rightLabel = Chili.Label:New{
		parent = holder,
		x = "58%",
		y = "56%",
		right = "3%",
		bottom = 0,
		valign = "center",
		align = "left",
		caption = "",
		objectOverrideFont = WG.GetSpecialFont(fontSize, "s44res_text", {
			outline = true, outlineWidth = 2, outlineWeight = 2,
		}),
	}

	function panel.SetValues(current, storage, barCaption, leftCaption, rightCaption, barColor, tooltip)
		bar:SetValue((storage > 0 and current / storage) or 0)
		bar:SetCaption(barCaption)
		if barColor and barColor ~= bar.color then
			bar.color = barColor
			bar:Invalidate()
		end
		leftLabel:SetCaption(leftCaption)
		rightLabel:SetCaption(rightCaption)
		holder.tooltip = tooltip
		bar.tooltip = tooltip
		leftLabel.tooltip = tooltip
		rightLabel.tooltip = tooltip
	end

	return panel
end

CreateWindow = function(oldX, oldY, oldW, oldH)
	local screenWidth = Spring.GetViewGeometry()
	local width = math.min(660, screenWidth - 10)

	window = Chili.Window:New{
		parent = Chili.Screen0,
		name = "S44ResourcePanel",
		dockable = true,
		x = oldX or floor(screenWidth / 2 - width / 2),
		y = oldY or 0,
		clientWidth = oldW or width,
		clientHeight = oldH or 58,
		minHeight = 40,
		padding = {0, -1, 0, 0},
		color = {0, 0, 0, 0},
		noFont = true,
		draggable = false,
		resizable = false,
		tweakDraggable = true,
		tweakResizable = true,
		minimizable = false,
		OnMouseDown = {OpenOptionsOnSpaceClick},
	}

	panels.metal = GetResourcePanel(window, "metal", 0, IMAGE_COMMAND, COMMAND_COLOR)
	panels.energy = GetResourcePanel(window, "energy", "50%", IMAGE_LOGISTICS, LOGISTICS_COLOR)
	widget:GameFrame(Spring.GetGameFrame(), true)
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Updates

local function UpdateCommand(teamID)
	local current, storage, pull, income, expense, share = spGetTeamResources(teamID, "metal")
	if not current then
		return
	end
	local net = income - pull
	local netStr = ((net >= 0) and positiveColourStr .. "+" or negativeColourStr) .. Format(net)
	local tooltip = "Command Points" .. "\n" ..
		"Earned from captured flags; spent to build and call in units." .. "\n\n" ..
		"Stored: " .. Format(current) .. " / " .. Format(storage) .. "\n" ..
		"Income: " .. positiveColourStr .. "+" .. Format(income) .. whiteStr .. "\n" ..
		"Spending: " .. negativeColourStr .. "-" .. Format(pull) .. whiteStr .. "\n" ..
		"Share level: " .. floor(100 * share + 0.5) .. "%" .. "\n\n" ..
		greenStr .. "Ctrl+click" .. whiteStr .. " the bar to set the share level."
	panels.metal.SetValues(current, storage,
		Format(current) .. " / " .. Format(storage),
		positiveColourStr .. "+" .. Format(income),
		negativeColourStr .. "-" .. Format(pull) .. neutralColourStr .. "  (" .. netStr .. neutralColourStr .. ")",
		nil, tooltip)
	panels.metal.UpdateShareMarker(share)
end

local function UpdateLogistics(teamID, frame)
	local current, storage, pull, income, expense, share = spGetTeamResources(teamID, "energy")
	if not current then
		return
	end
	local remaining = resupplyPeriod - (frame % resupplyPeriod)
	local low = storage > 0 and (current / storage) < LOGISTICS_LOW_FRACTION
	local tooltip = "Logistics" .. "\n" ..
		"Supplies ammunition to your units. Storage is refilled every " .. FramesToTimeString(resupplyPeriod) .. "." .. "\n\n" ..
		"Stored: " .. Format(current) .. " / " .. Format(storage) .. "\n" ..
		"Next resupply in: " .. FramesToTimeString(remaining) .. "\n" ..
		"Share level: " .. floor(100 * share + 0.5) .. "%" .. "\n\n" ..
		greenStr .. "Ctrl+click" .. whiteStr .. " the bar to set the share level."
	panels.energy.SetValues(current, storage,
		Format(current) .. " / " .. Format(storage),
		neutralColourStr .. "Resupply " .. whiteStr .. FramesToTimeString(remaining),
		(pull > 0 and (negativeColourStr .. "-" .. Format(pull))) or "",
		(low and LOGISTICS_LOW_COLOR) or LOGISTICS_COLOR, tooltip)
	panels.energy.UpdateShareMarker(share)
end

function widget:GameFrame(n, force)
	if not (window and (force or n % UPDATE_PERIOD == 0)) then
		return
	end
	local teamID = spGetMyTeamID()
	UpdateCommand(teamID)
	UpdateLogistics(teamID, n)
end

function widget:PlayerChanged()
	widget:GameFrame(Spring.GetGameFrame(), true)
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Widget interface

function widget:Initialize()
	Chili = WG.Chili
	if not Chili then
		widgetHandler:RemoveWidget()
		return
	end
	Spring.SendCommands("resbar 0")
	resupplyPeriod = Spring.GetGameRulesParam("resupplyPeriod") or resupplyPeriod
	CreateWindow()
end

function widget:Shutdown()
	if window then
		window:Dispose()
	end
	Spring.SendCommands("resbar 1")
end
