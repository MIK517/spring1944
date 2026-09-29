function widget:GetInfo()
	return {
		name        = "1944 Aircraft Selection Bar",
		desc        = "A selection bar for aircraft, in the style of the Zero-K interface panels",
		author      = "Ray Modified by Godde, Szunti, kmar, Jose Luis Cercos Pita",
		date        = "2011-09-06",
		license     = "GNU GPL v2 or later",
		layer       = 1,
		enabled     = true,
	}
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Aircraft arrive as sorties and cannot be box selected easily, so this bar
-- lists them. It stays hidden while the player has no aircraft.

local BUTTON_SIZE = 56
local BAR_HEIGHT = 5
local MAX_ROWS = 8

local GetUnitDefID       = Spring.GetUnitDefID
local GetUnitHealth      = Spring.GetUnitHealth
local GetSelectedUnits   = Spring.GetSelectedUnits
local GetTeamUnits       = Spring.GetTeamUnits
local GetMyTeamID        = Spring.GetMyTeamID
local GetUnitRulesParam  = Spring.GetUnitRulesParam
local GetUnitPosition    = Spring.GetUnitPosition
local SelectUnitArray    = Spring.SelectUnitArray
local IsUnitSelected     = Spring.IsUnitSelected
local glUnit             = gl.Unit
local glDrawGroundCircle = gl.DrawGroundCircle

-- See LuaRules/Gadgets/game_planes.lua: fuel scales with the map size.
local REFERENCE_FUEL_AMOUNT = 24
local fuelMapScale = math.sqrt(Game.mapX^2 + Game.mapY^2) / REFERENCE_FUEL_AMOUNT

local Chili
local window, grid
local myTeamID = GetMyTeamID()
local aircraft = {} -- unitID -> button data
local aircraftOrder = {}
local updateIndex = 0
local hoveredUnitID
local UpdateLayout

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Options

options_path = 'Settings/HUD Panels/Aircraft Bar'
options_order = {'buttonSize', 'highlightHovered'}
options = {
	buttonSize = {
		name = "Button Size",
		type = "number",
		value = BUTTON_SIZE, min = 30, max = 120, step = 1,
		OnChange = function(self)
			BUTTON_SIZE = self.value
			if window then
				for _, data in pairs(aircraft) do
					data.button:SetPos(nil, nil, BUTTON_SIZE, BUTTON_SIZE)
				end
				UpdateLayout()
			end
		end,
	},
	highlightHovered = {
		name = "Highlight hovered aircraft",
		desc = "Draw range rings around the aircraft under the mouse.",
		type = "bool",
		value = true,
		noHotkey = true,
	},
}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Utilities

local function GetHealthColor(fraction)
	if fraction > 0.5 then
		return {(1 - fraction) * 2, 1, 0, 1}
	end
	return {1, fraction * 2, 0, 1}
end

local function OpenOptionsOnSpaceClick()
	local _, _, meta = Spring.GetModKeyState()
	if not meta then
		return false
	end
	WG.crude.OpenPath(options_path)
	WG.crude.ShowMenu()
	return true
end

UpdateLayout = function()
	if not window then
		return
	end
	local count = #aircraftOrder
	if count == 0 then
		window:SetVisibility(false)
		return
	end
	local rows = math.min(count, MAX_ROWS)
	local columns = math.ceil(count / MAX_ROWS)
	grid.columns = columns
	grid.rows = rows
	local width = columns * BUTTON_SIZE + 12
	local height = rows * BUTTON_SIZE + 12
	if window.width ~= width or window.height ~= height then
		window:SetPos(nil, nil, width, height)
	end
	window:SetVisibility(true)
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Buttons

local function OnAircraftClick(self, x, y, button)
	if OpenOptionsOnSpaceClick() then
		return true
	end
	local unitID = self.unitID
	local _, _, _, shift = Spring.GetModKeyState()
	if button == 1 then
		if shift then
			local units = GetSelectedUnits()
			units[#units + 1] = unitID
			SelectUnitArray(units)
		else
			SelectUnitArray({unitID})
		end
	elseif button == 2 then
		local ux, uy, uz = GetUnitPosition(unitID)
		if ux then
			Spring.SetCameraTarget(ux, uy, uz)
		end
	elseif button == 3 then
		local units = GetSelectedUnits()
		if IsUnitSelected(unitID) then
			for i = #units, 1, -1 do
				if units[i] == unitID then
					table.remove(units, i)
				end
			end
		else
			units[#units + 1] = unitID
		end
		SelectUnitArray(units)
	end
	return true
end

local function AddAircraft(unitID, unitDefID)
	if aircraft[unitID] then
		return
	end
	local ud = UnitDefs[unitDefID]
	local button = Chili.Button:New{
		parent = grid,
		width = BUTTON_SIZE,
		height = BUTTON_SIZE,
		padding = {2, 2, 2, 2},
		margin = {0, 0, 0, 0},
		caption = "",
		noFont = true,
		tooltip = Spring.Utilities.GetHumanName(ud) .. "\n" ..
			"\255\1\255\1Left click\255\255\255\255: select\n" ..
			"\255\1\255\1Shift+left click\255\255\255\255: add to selection\n" ..
			"\255\1\255\1Right click\255\255\255\255: add to or remove from selection\n" ..
			"\255\1\255\1Middle click\255\255\255\255: go to",
		OnClick = {OnAircraftClick},
		OnMouseOver = {function(self) hoveredUnitID = self.unitID end},
		OnMouseOut = {function(self)
			if hoveredUnitID == self.unitID then
				hoveredUnitID = nil
			end
		end},
	}
	button.unitID = unitID
	local image = Chili.Image:New{
		parent = button,
		x = 0,
		y = 0,
		right = 0,
		bottom = 2 * BAR_HEIGHT,
		keepAspect = true,
		file = "#" .. unitDefID,
	}
	local healthBar = Chili.Progressbar:New{
		parent = button,
		x = 0,
		right = 0,
		bottom = BAR_HEIGHT,
		height = BAR_HEIGHT,
		max = 1,
		value = 1,
		caption = false,
		noFont = true,
		color = {0, 1, 0, 1},
	}
	local fuelBar = Chili.Progressbar:New{
		parent = button,
		x = 0,
		right = 0,
		bottom = 0,
		height = BAR_HEIGHT,
		max = 1,
		value = 1,
		caption = false,
		noFont = true,
		color = {0.9, 0.58, 0.21, 1},
	}
	local maxFuel = tonumber(ud.customParams.maxfuel)
	aircraft[unitID] = {
		button = button,
		healthBar = healthBar,
		fuelBar = fuelBar,
		maxFuel = maxFuel and (maxFuel * fuelMapScale),
	}
	aircraftOrder[#aircraftOrder + 1] = unitID
	UpdateLayout()
end

local function RemoveAircraft(unitID)
	local data = aircraft[unitID]
	if not data then
		return
	end
	data.button:Dispose()
	aircraft[unitID] = nil
	for i = 1, #aircraftOrder do
		if aircraftOrder[i] == unitID then
			table.remove(aircraftOrder, i)
			break
		end
	end
	if hoveredUnitID == unitID then
		hoveredUnitID = nil
	end
	UpdateLayout()
end

local function UpdateAircraft(unitID)
	local data = aircraft[unitID]
	local health, maxHealth = GetUnitHealth(unitID)
	if health and maxHealth and maxHealth > 0 then
		local fraction = health / maxHealth
		data.healthBar.color = GetHealthColor(fraction)
		data.healthBar:SetValue(fraction)
	end
	if data.maxFuel then
		local fuel = GetUnitRulesParam(unitID, "fuel") or data.maxFuel
		data.fuelBar:SetValue(math.max(0, math.min(1, fuel / data.maxFuel)))
	end
end

local function GenerateAircraft()
	for unitID in pairs(aircraft) do
		RemoveAircraft(unitID)
	end
	for _, unitID in ipairs(GetTeamUnits(myTeamID) or {}) do
		local unitDefID = GetUnitDefID(unitID)
		if unitDefID and UnitDefs[unitDefID].canFly then
			AddAircraft(unitID, unitDefID)
		end
	end
	UpdateLayout()
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
	local screenWidth, screenHeight = Spring.GetViewGeometry()
	window = Chili.Window:New{
		parent = Chili.Screen0,
		name = "S44AircraftBar",
		dockable = true,
		right = 0,
		y = math.floor(screenHeight * 0.3),
		width = BUTTON_SIZE + 12,
		height = BUTTON_SIZE + 12,
		padding = {6, 6, 6, 6},
		draggable = false,
		resizable = false,
		tweakDraggable = true,
		tweakResizable = false,
		minimizable = false,
		OnMouseDown = {OpenOptionsOnSpaceClick},
	}
	grid = Chili.Grid:New{
		parent = window,
		x = 0,
		y = 0,
		right = 0,
		bottom = 0,
		padding = {0, 0, 0, 0},
		itemPadding = {0, 0, 0, 0},
		itemMargin = {0, 0, 0, 0},
		columns = 1,
		rows = 1,
		orientation = "vertical",
	}
	GenerateAircraft()
end

function widget:UnitCreated(unitID, unitDefID, unitTeam)
	if unitTeam == myTeamID and UnitDefs[unitDefID].canFly then
		AddAircraft(unitID, unitDefID)
	end
end

function widget:UnitGiven(unitID, unitDefID, unitTeam, oldTeam)
	widget:UnitCreated(unitID, unitDefID, unitTeam)
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam)
	RemoveAircraft(unitID)
end

function widget:UnitTaken(unitID, unitDefID, unitTeam, newTeam)
	RemoveAircraft(unitID)
end

function widget:Update()
	if myTeamID ~= GetMyTeamID() then
		myTeamID = GetMyTeamID()
		GenerateAircraft()
		return
	end
	local count = #aircraftOrder
	if count == 0 then
		return
	end
	-- One aircraft per frame is enough to keep the bars current.
	updateIndex = (updateIndex % count) + 1
	UpdateAircraft(aircraftOrder[updateIndex])
end

function widget:DrawWorld()
	local unitID = hoveredUnitID
	if not (unitID and options.highlightHovered.value) then
		return
	end
	glUnit(unitID, true)
	local ux, uy, uz = GetUnitPosition(unitID)
	if ux then
		glDrawGroundCircle(ux, uy, uz, 1600, 20)
		glDrawGroundCircle(ux, uy, uz, 800, 16)
		glDrawGroundCircle(ux, uy, uz, 400, 12)
		glDrawGroundCircle(ux, uy, uz, 200, 8)
	end
end

function widget:Shutdown()
	if window then
		window:Dispose()
		window = nil
	end
end
