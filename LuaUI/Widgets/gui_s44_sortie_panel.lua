function widget:GetInfo()
	return {
		name      = "1944 Air Support Panel",
		desc      = "Lists your team's ready air sorties; click one, then a target, to call it in.",
		author    = "Spring: 1944",
		date      = "2026-09-29",
		license   = "GNU GPL, v2 or later",
		layer     = -10, -- before other widgets take the target click
		enabled   = true,
	}
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Air sorties are built at radio stations, airfields and HQs into a stockpile
-- shared by the whole team (see LuaRules/Gadgets/game_planes.lua). Any of
-- those buildings can call a ready sortie in. This panel lists every ready
-- sortie, whichever building would call it, so the player does not have to
-- find and select the right building. The 'sortie_interface' mod option
-- switches between this panel and the Air tab of the buildings' command card.

if (Spring.GetModOptions().sortie_interface or "global") ~= "global" then
	return
end

include("keysym.lua")

local spGetTeamRulesParam = Spring.GetTeamRulesParam
local spGetMyTeamID = Spring.GetMyTeamID
local spGetTeamUnits = Spring.GetTeamUnits
local spGetUnitDefID = Spring.GetUnitDefID
local spFindUnitCmdDesc = Spring.FindUnitCmdDesc
local spGetUnitIsStunned = Spring.GetUnitIsStunned
local spTraceScreenRay = Spring.TraceScreenRay
local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spGetSpectatingState = Spring.GetSpectatingState

local BUTTON_SIZE = 50
local TITLE_HEIGHT = 16
local MIN_WIDTH = 96 -- room for the title
local MAX_COLUMNS = 8
local UPDATE_PERIOD = 0.25

local Chili
local window, grid, titleLabel
local buttons = {} -- sortie unitDefID -> button

local sorties = {} -- ordered list of {unitDefID, cmdID, def}
local sortieByCmdID = {}
local radioDefs = {} -- unitDefID -> true for units that can call sorties

local targeting -- sortie being aimed, or nil
local updateTimer = 0
local UpdatePanel

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Sortie data

local function LoadSorties()
	local ok, sortieDefs = pcall(VFS.Include, "LuaRules/Configs/sortie_defs.lua")
	if not (ok and sortieDefs) then
		return
	end
	for name, def in pairs(sortieDefs) do
		local ud = UnitDefNames[name]
		local cmdID = ud and Spring.GetGameRulesParam("CMD_PLANES_" .. ud.id)
		if cmdID then
			local entry = {unitDefID = ud.id, cmdID = cmdID, def = def, name = ud.humanName, sortName = name}
			sorties[#sorties + 1] = entry
			sortieByCmdID[cmdID] = entry
		end
	end
	table.sort(sorties, function(a, b) return a.sortName < b.sortName end)
	for unitDefID, ud in pairs(UnitDefs) do
		for i = 1, #ud.buildOptions do
			if UnitDefs[ud.buildOptions[i]].name:find("_sortie_", 1, true) then
				radioDefs[unitDefID] = true
				break
			end
		end
	end
end

local function GetStockpile(entry)
	return spGetTeamRulesParam(spGetMyTeamID(), "game_planes.stockpile" .. entry.cmdID) or 0
end

-- A finished unit of ours that has this sortie's call command.
local function FindRadio(cmdID)
	local units = spGetTeamUnits(spGetMyTeamID()) or {}
	for i = 1, #units do
		local unitID = units[i]
		local unitDefID = spGetUnitDefID(unitID)
		if unitDefID and radioDefs[unitDefID] and spFindUnitCmdDesc(unitID, cmdID) then
			local _, _, inBuild = spGetUnitIsStunned(unitID)
			if not inBuild then
				return unitID
			end
		end
	end
end

local function GetTooltip(entry, count)
	local def = entry.def
	local text = entry.name
	if def.description then
		text = text .. " - " .. def.description
	end
	text = text .. "\nReady: " .. count
	if def.delay then
		text = text .. "\nArrives " .. def.delay .. "s after the call"
	end
	return text .. "\n\255\1\255\1Click\255\255\255\255, then click a target to call it in." ..
		"\n\255\1\255\1Right click\255\255\255\255 or \255\1\255\1Esc\255\255\255\255 cancels."
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Targeting

local function StopTargeting()
	targeting = nil
	for _, button in pairs(buttons) do
		button.backgroundColor = button.defaultColor
		button:Invalidate()
	end
end

local function StartTargeting(entry)
	if spGetSpectatingState() then
		return
	end
	StopTargeting()
	targeting = entry
	local button = buttons[entry.unitDefID]
	if button then
		button.backgroundColor = {1, 0.85, 0.3, 1}
		button:Invalidate()
	end
end

local function CallSortie(entry, params)
	local radioID = FindRadio(entry.cmdID)
	if not radioID then
		Spring.Echo("No radio station, airfield or HQ can call in " .. entry.name .. " right now.")
		return
	end
	spGiveOrderToUnit(radioID, entry.cmdID, params, 0)
	if WG.S44Debug then
		WG.S44Debug.Log("command", "sortie", entry.name, "via", radioID)
	end
end

function widget:MousePress(x, y, button)
	if not targeting then
		return false
	end
	if button ~= 1 then
		StopTargeting()
		return true
	end
	local entry = targeting
	local groundOnly = entry.def.groundOnly
	local targetType, target = spTraceScreenRay(x, y, false, false, false, groundOnly)
	local params
	if targetType == "unit" and not groundOnly then
		params = {target}
	else
		if targetType ~= "ground" then
			targetType, target = spTraceScreenRay(x, y, true)
		end
		if targetType == "ground" and target then
			params = {target[1], target[2], target[3]}
		end
	end
	if params then
		CallSortie(entry, params)
	end
	local _, _, _, shift = Spring.GetModKeyState()
	if not (shift and GetStockpile(entry) > 1) then
		StopTargeting()
	end
	return true
end

function widget:KeyPress(key)
	if targeting and key == KEYSYMS.ESCAPE then
		StopTargeting()
		return true
	end
end

function widget:IsAbove(x, y)
	-- Keeps the sortie cursor while aiming.
	return targeting ~= nil and not (WG.Chili and WG.Chili.Screen0:IsAbove(x, y))
end

function widget:GetTooltip()
	return targeting and ("Call in " .. targeting.name) or nil
end

function widget:Update(dt)
	if targeting then
		Spring.SetMouseCursor(targeting.def.cursor or "Attack")
	end
	updateTimer = updateTimer + dt
	if updateTimer < UPDATE_PERIOD then
		return
	end
	updateTimer = 0
	UpdatePanel()
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Panel

local function GetButton(entry)
	if buttons[entry.unitDefID] then
		return buttons[entry.unitDefID]
	end
	local button = Chili.Button:New{
		width = BUTTON_SIZE,
		height = BUTTON_SIZE,
		caption = "",
		padding = {2, 2, 2, 2},
		margin = {0, 0, 0, 0},
		noFont = true,
		OnClick = {function(self, _, _, mouse)
			if mouse == 3 then
				StopTargeting()
			elseif targeting == entry then
				StopTargeting()
			else
				StartTargeting(entry)
			end
		end},
	}
	button.defaultColor = button.backgroundColor
	-- Chili draws the first child on top: the count goes over the picture.
	button.countLabel = Chili.Label:New{
		parent = button,
		right = 2,
		bottom = 0,
		width = BUTTON_SIZE,
		height = 18,
		align = "right",
		caption = "",
		objectOverrideFont = WG.GetSpecialFont(16, "s44sortie_count", {outline = true, outlineWidth = 3, outlineWeight = 3}),
	}
	Chili.Image:New{
		parent = button,
		x = 0, y = 0, right = 0, bottom = 0,
		keepAspect = true,
		file = "#" .. entry.unitDefID,
	}
	buttons[entry.unitDefID] = button
	return button
end

UpdatePanel = function()
	if not window then
		return
	end
	local shown = {}
	for i = 1, #sorties do
		local entry = sorties[i]
		local count = GetStockpile(entry)
		if count > 0 then
			shown[#shown + 1] = {entry = entry, count = count}
		end
	end

	if targeting and GetStockpile(targeting) <= 0 then
		StopTargeting()
	end

	if #shown == 0 or spGetSpectatingState() then
		window:SetVisibility(false)
		return
	end

	-- Rebuild the grid only when the set of ready sorties changed.
	local key = ""
	for i = 1, #shown do
		key = key .. shown[i].entry.unitDefID .. ","
	end
	if key ~= grid.sortieKey then
		grid.sortieKey = key
		grid:ClearChildren()
		for i = 1, #shown do
			grid:AddChild(GetButton(shown[i].entry))
		end
		local columns = math.min(#shown, MAX_COLUMNS)
		local rows = math.ceil(#shown / MAX_COLUMNS)
		grid.columns = columns
		grid.rows = rows
		window:SetPos(nil, nil, math.max(MIN_WIDTH, columns * BUTTON_SIZE + 12), rows * BUTTON_SIZE + TITLE_HEIGHT + 12)
	end
	for i = 1, #shown do
		local button = buttons[shown[i].entry.unitDefID]
		local caption = tostring(shown[i].count)
		if button.countLabel.caption ~= caption then
			button.countLabel:SetCaption(caption)
		end
		button.tooltip = GetTooltip(shown[i].entry, shown[i].count)
	end
	window:SetVisibility(true)
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:Initialize()
	Chili = WG.Chili
	if not Chili then
		widgetHandler:RemoveWidget()
		return
	end
	LoadSorties()
	if #sorties == 0 then
		widgetHandler:RemoveWidget()
		return
	end
	window = Chili.Window:New{
		parent = Chili.Screen0,
		name = "S44SortiePanel",
		dockable = false,
		x = 0,
		y = 0,
		width = BUTTON_SIZE + 12,
		height = BUTTON_SIZE + TITLE_HEIGHT + 12,
		padding = {6, 6, 6, 6},
		draggable = false,
		resizable = false,
		tweakDraggable = true,
		minimizable = false,
	}
	titleLabel = Chili.Label:New{
		parent = window,
		x = 0,
		y = 0,
		height = TITLE_HEIGHT,
		caption = "Air support",
		objectOverrideFont = WG.GetSpecialFont(12, "s44sortie_title", {color = {1, 0.82, 0.45, 1}, outline = true}),
	}
	grid = Chili.Grid:New{
		parent = window,
		x = 0, y = TITLE_HEIGHT, right = 0, bottom = 0,
		padding = {0, 0, 0, 0},
		itemPadding = {0, 0, 0, 0},
		itemMargin = {0, 0, 0, 0},
		columns = 1,
		rows = 1,
	}
	window:SetVisibility(false)
	WG.S44SortiePanel = {
		-- Bottom edge of the panel, for widgets placed below it.
		GetBottom = function()
			if window and window.visible then
				return window.y + window.height
			end
			return 0
		end,
	}
	UpdatePanel()
end

function widget:Shutdown()
	WG.S44SortiePanel = nil
	if window then
		window:Dispose()
	end
end
