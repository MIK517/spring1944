--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
	return {
		name         = "1944 Share dialog",
		desc         = "Give Command Points, Logistics and units to allies",
		author       = "Jose Luis Cercos-Pita",
		date         = "2020-08-28",
		license      = "GNU GPL, v2 or later",
		layer        = 50,
		experimental = false,
		enabled      = true,
	}
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

include("keysym.lua")

local IMAGE_COMMAND = "LuaUI/Images/resources/command.png"
local IMAGE_LOGISTICS = "LuaUI/Images/resources/logistics.png"
local IMAGE_SELECTED = "LuaUI/Images/epicmenu/check.png"

local WINDOW_WIDTH = 360
local ROW_HEIGHT = 30

local green = "\255\1\255\1"
local white = "\255\255\255\255"

local Chili
local window, playerStack, selectedLabel
local resourceRows = {}
local shareUnitsCheckbox
local playerButtons = {}
local selectedTeamID

local spGetTeamResources = Spring.GetTeamResources

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Options

local ToggleWindow

options_path = 'Settings/HUD Panels/Share Dialog'
options_order = {'toggleShareDialog'}
options = {
	toggleShareDialog = {
		name = "Share Dialog",
		desc = "Open the dialog to give Command Points, Logistics and the selected units to an ally.",
		type = 'button',
		hotkey = {key = 'h', mod = 'alt+'},
		path = 'Hotkeys/Misc',
		OnChange = function()
			ToggleWindow()
		end,
	},
}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Utilities

local function Format(value)
	if value >= 10000 then
		return string.format("%.1fk", value / 1000)
	end
	return string.format("%d", value)
end

local function GetTeamName(teamID)
	local _, leader, _, isAI = Spring.GetTeamInfo(teamID, false)
	if isAI then
		local _, name = Spring.GetAIInfo(teamID)
		return name or ("AI " .. teamID)
	end
	local name = leader and Spring.GetPlayerInfo(leader, false)
	return name or ("Team " .. teamID)
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Controls

local function SelectTeam(teamID)
	selectedTeamID = teamID
	for id, button in pairs(playerButtons) do
		button.tick:SetVisibility(id == teamID)
	end
	if selectedLabel then
		selectedLabel:SetCaption((teamID and ("Give to: " .. GetTeamName(teamID))) or "No allies to share with")
	end
end

local function UpdatePlayers()
	if not playerStack then
		return
	end
	playerStack:ClearChildren()
	playerButtons = {}
	local myTeamID = Spring.GetMyTeamID()
	local teams = Spring.GetTeamList(Spring.GetMyAllyTeamID()) or {}
	local firstTeam
	local keepSelection = false
	for i = 1, #teams do
		local teamID = teams[i]
		local _, _, isDead = Spring.GetTeamInfo(teamID, false)
		if teamID ~= myTeamID and not isDead then
			local r, g, b = Spring.GetTeamColor(teamID)
			local button = Chili.Button:New{
				parent = playerStack,
				x = 0,
				right = 0,
				height = ROW_HEIGHT,
				caption = GetTeamName(teamID),
				padding = {4, 2, 4, 2},
				objectOverrideFont = WG.GetSpecialFont(14, "s44share_team_" .. teamID, {
					color = {r, g, b, 1}, outline = true, outlineWidth = 2, outlineWeight = 2,
				}),
				OnClick = {function() SelectTeam(teamID) end},
			}
			button.tick = Chili.Image:New{
				parent = button,
				x = 2,
				y = 2,
				width = ROW_HEIGHT - 10,
				height = ROW_HEIGHT - 10,
				file = IMAGE_SELECTED,
			}
			button.tick:SetVisibility(false)
			playerButtons[teamID] = button
			firstTeam = firstTeam or teamID
			if teamID == selectedTeamID then
				keepSelection = true
			end
		end
	end
	SelectTeam((keepSelection and selectedTeamID) or firstTeam)
end

local function GetResourceRow(parent, y, image, resource)
	local row = {resource = resource}
	Chili.Image:New{
		parent = parent,
		x = 0,
		y = y,
		width = ROW_HEIGHT,
		height = ROW_HEIGHT,
		file = image,
	}
	row.trackbar = Chili.Trackbar:New{
		parent = parent,
		x = ROW_HEIGHT + 6,
		y = y + 4,
		right = 90,
		height = ROW_HEIGHT - 8,
		min = 0,
		max = 100,
		step = 5,
		value = 0,
		OnChange = {function()
			if row.Update then -- also called while the trackbar is created
				row.Update()
			end
		end},
	}
	row.label = Chili.Label:New{
		parent = parent,
		y = y,
		right = 0,
		width = 86,
		height = ROW_HEIGHT,
		align = "right",
		valign = "center",
		caption = "",
		objectOverrideFont = WG.GetFont(13),
	}
	function row.GetAmount()
		local current = spGetTeamResources(Spring.GetMyTeamID(), resource) or 0
		return current * row.trackbar.value / 100, current
	end
	function row.Update()
		local amount, current = row.GetAmount()
		row.label:SetCaption(Format(amount) .. " / " .. Format(current))
	end
	return row
end

local function HideWindow()
	if window then
		window:SetVisibility(false)
	end
end

local function Share()
	local teamID = selectedTeamID
	if not teamID then
		return
	end
	for _, row in ipairs(resourceRows) do
		local amount = row.GetAmount()
		if amount > 0 then
			Spring.ShareResources(teamID, row.resource, amount)
		end
	end
	if shareUnitsCheckbox.checked and Spring.GetSelectedUnitsCount() > 0 then
		Spring.ShareResources(teamID, "units")
	end
	if WG.S44Debug then
		WG.S44Debug.Log("share", "to team " .. teamID)
	end
	HideWindow()
end

local function CreateWindow()
	local screenWidth, screenHeight = Spring.GetViewGeometry()
	local height = 330
	window = Chili.Window:New{
		parent = Chili.Screen0,
		name = "S44ShareDialog",
		caption = "Share with allies",
		x = math.floor((screenWidth - WINDOW_WIDTH) / 2),
		y = math.floor((screenHeight - height) / 3),
		width = WINDOW_WIDTH,
		height = height,
		resizable = false,
		draggable = true,
		padding = {10, 26, 10, 10},
	}

	local playerScroll = Chili.ScrollPanel:New{
		parent = window,
		x = 0,
		y = 0,
		right = 0,
		height = 120,
		horizontalScrollbar = false,
	}
	playerStack = Chili.StackPanel:New{
		parent = playerScroll,
		x = 0,
		y = 0,
		right = 0,
		resizeItems = false,
		autosize = true,
		itemPadding = {0, 0, 0, 0},
		itemMargin = {0, 0, 0, 2},
		padding = {0, 0, 0, 0},
		preserveChildrenOrder = true,
	}

	selectedLabel = Chili.Label:New{
		parent = window,
		x = 0,
		y = 124,
		right = 0,
		height = 18,
		caption = "",
		objectOverrideFont = WG.GetFont(13),
	}

	resourceRows = {
		GetResourceRow(window, 146, IMAGE_COMMAND, "metal"),
		GetResourceRow(window, 146 + ROW_HEIGHT + 4, IMAGE_LOGISTICS, "energy"),
	}

	shareUnitsCheckbox = Chili.Checkbox:New{
		parent = window,
		x = 0,
		y = 146 + 2 * (ROW_HEIGHT + 4),
		right = 0,
		height = 20,
		caption = "Give the selected units",
		checked = false,
		boxalign = "left",
		objectOverrideFont = WG.GetFont(13),
	}

	Chili.Button:New{
		parent = window,
		x = 0,
		bottom = 0,
		width = "48%",
		height = 30,
		caption = "Share",
		tooltip = "Give the chosen amounts (and the selected units) to the ally.",
		OnClick = {Share},
	}
	Chili.Button:New{
		parent = window,
		right = 0,
		bottom = 0,
		width = "48%",
		height = 30,
		caption = "Close",
		OnClick = {HideWindow},
	}
	window:SetVisibility(false)
end

ToggleWindow = function(teamID)
	if not window then
		return
	end
	if window.visible and not teamID then
		HideWindow()
		return
	end
	UpdatePlayers()
	if teamID and playerButtons[teamID] then
		SelectTeam(teamID)
	end
	for _, row in ipairs(resourceRows) do
		row.Update()
	end
	shareUnitsCheckbox.checked = Spring.GetSelectedUnitsCount() > 0 and (teamID ~= nil)
	shareUnitsCheckbox:Invalidate()
	window:SetVisibility(true)
	window:BringToFront()
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Callins

function widget:Initialize()
	Chili = WG.Chili
	if not Chili then
		widgetHandler:RemoveWidget()
		return
	end
	CreateWindow()
	WG.S44ShareDialog = {
		Open = function(teamID)
			ToggleWindow(teamID)
		end,
	}
end

function widget:KeyPress(key)
	if key == KEYSYMS.ESCAPE and window and window.visible then
		HideWindow()
		return true
	end
end

function widget:GameFrame(n)
	if n % 15 ~= 0 or not (window and window.visible) then
		return
	end
	for _, row in ipairs(resourceRows) do
		row.Update()
	end
end

function widget:PlayerChanged()
	if window and window.visible then
		UpdatePlayers()
	end
end

function widget:TeamDied()
	widget:PlayerChanged()
end

function widget:Shutdown()
	WG.S44ShareDialog = nil
	if window then
		window:Dispose()
	end
end
