function widget:GetInfo()
	return {
		name      = "1944 Unit Stats",
		desc      = "Space+click on a unit, wreck or build button to see its stats (Zero-K style stats window for Spring: 1944).",
		author    = "CarRepairer (Zero-K original), Spring: 1944 adaptation",
		date      = "2026-09-29",
		license   = "GNU GPL, v2 or later",
		layer     = 0,
		enabled   = true,
	}
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Zero-K's stats window reads Zero-K unit and weapon data. This is the same
-- idea for S:44: cost, health, speed, armour thickness, weapons with armour
-- penetration and damage against the main target types, ammunition and
-- logistics use, supply range and build options.

local spGetModKeyState = Spring.GetModKeyState
local spTraceScreenRay = Spring.TraceScreenRay
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitRulesParam = Spring.GetUnitRulesParam

local WINDOW_WIDTH = 480
local BUTTON_HEIGHT = 28
local PIC_SIZE = 96
local ROW_HEIGHT = 16

local COLOR_HEADER = {1.0, 0.82, 0.45, 1}
local COLOR_TEXT = {0.95, 0.93, 0.85, 1}
local COLOR_VALUE = {0.75, 1.0, 0.75, 1}
local COLOR_DIM = {0.7, 0.7, 0.65, 1}

-- Damage groups shown for every weapon (see gamedata/armordefs.lua).
local DAMAGE_TARGETS = {
	{"infantry", "Infantry"},
	{"guns", "Guns"},
	{"unarmouredvehicles", "Soft vehicles"},
	{"lightbuildings", "Buildings"},
}

local DAMAGE_TYPE_NAMES = {
	kinetic = "Armour piercing",
	explosive = "High explosive",
	shapedcharge = "Shaped charge (HEAT)",
	grenade = "Grenade",
	smoke = "Smoke",
	fire = "Incendiary",
}

-- See LuaRules/Gadgets/game_planes.lua: fuel scales with the map size.
local REFERENCE_FUEL_AMOUNT = 24
local fuelMapScale = math.sqrt(Game.mapX^2 + Game.mapY^2) / REFERENCE_FUEL_AMOUNT

local Chili
local screen0
local statsWindows = {}
local screenWidth, screenHeight = Spring.GetViewGeometry()

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Options

options_path = 'Settings/Interface/Unit Stats'
options_order = {'windowToCursor', 'windowHeight', 'showBuildOptions'}
options = {
	windowToCursor = {
		name = "Open at mouse position",
		type = 'bool',
		value = true,
		noHotkey = true,
	},
	windowHeight = {
		name = "Window height",
		type = 'number',
		value = 480, min = 300, max = 1000, step = 10,
	},
	showBuildOptions = {
		name = "Show build options",
		type = 'bool',
		value = true,
		noHotkey = true,
	},
}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Formatting

local function Num(value, decimals)
	value = tonumber(value) or 0
	if decimals and decimals > 0 and value ~= math.floor(value) then
		return string.format("%." .. decimals .. "f", value)
	end
	return tostring(math.floor(value + 0.5))
end

local function Seconds(value)
	value = tonumber(value) or 0
	if value >= 60 then
		return string.format("%d:%02d", math.floor(value / 60), math.floor(value % 60))
	end
	if value < 10 then
		return Num(value, 1) .. "s"
	end
	return Num(value) .. "s"
end

local function IsRealWeapon(wd)
	if not wd then
		return false
	end
	local cp = wd.customParams or {}
	if cp.binocs or cp.paratrooper or cp.damagetype == "none" then
		return false
	end
	if wd.type == "Shield" or cp.onlytargetcategory == "NONE" then
		return false
	end
	return true
end

-- Armour penetration: returns the penetration at 100m and 1000m (mm).
local function GetPenetration(cp)
	local pen = tonumber(cp.armor_penetration)
	local pen100 = tonumber(cp.armor_penetration_100m)
	local pen1000 = tonumber(cp.armor_penetration_1000m)
	if pen100 then
		return pen100, pen1000 or pen100
	elseif pen then
		if cp.damagetype == "shapedcharge" then
			return pen, pen
		end
		return pen, pen1000 or pen
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Content building

local function MakeStatsGrid()
	local rows = {}
	local grid = {}

	function grid.Header(text)
		rows[#rows + 1] = {text, "", header = true}
	end
	function grid.Row(name, value, valueColor)
		rows[#rows + 1] = {name, value, color = valueColor}
	end
	function grid.Blank()
		rows[#rows + 1] = {"", ""}
	end
	function grid.Build(parent, y)
		local children = {}
		for i = 1, #rows do
			local row = rows[i]
			children[#children + 1] = Chili.Label:New{
				caption = row[1],
				height = ROW_HEIGHT,
				objectOverrideFont = WG.GetSpecialFont(13, row.header and "s44stats_header" or "s44stats_text", {
					color = row.header and COLOR_HEADER or COLOR_TEXT, outline = row.header, outlineWidth = 2, outlineWeight = 2,
				}),
			}
			children[#children + 1] = Chili.Label:New{
				caption = row[2],
				height = ROW_HEIGHT,
				objectOverrideFont = WG.GetSpecialFont(13, "s44stats_value", {color = COLOR_VALUE}),
			}
		end
		local height = math.ceil(#rows) * (ROW_HEIGHT + 2)
		Chili.Grid:New{
			parent = parent,
			x = 0,
			y = y,
			right = 0,
			height = height,
			columns = 2,
			rows = #rows,
			padding = {0, 0, 0, 0},
			itemPadding = {1, 1, 1, 1},
			itemMargin = {0, 0, 0, 0},
			children = children,
		}
		return y + height
	end
	return grid
end

local function AddGeneralStats(grid, ud, unitID)
	local cp = ud.customParams
	grid.Header("General")
	grid.Row("Cost:", Num(ud.metalCost) .. " Command")
	local maxHealth = ud.health
	if unitID then
		local health, unitMaxHealth = Spring.GetUnitHealth(unitID)
		if health then
			grid.Row("Health:", Num(health) .. " / " .. Num(unitMaxHealth))
		end
	else
		grid.Row("Health:", Num(maxHealth))
	end
	if cp.damagegroup then
		grid.Row("Target type:", cp.damagegroup)
	end
	if (ud.speed or 0) > 0 then
		-- S:44 converts km/h to game speed by dividing by 13.5 (unitdefs_post).
		grid.Row("Speed:", Num(ud.speed / 30 * 13.5) .. " km/h")
	end
	if (ud.losRadius or 0) > 0 then
		grid.Row("Sight range:", Num(ud.losRadius))
	end
	if (ud.radarRadius or 0) > 0 then
		grid.Row("Spotting range:", Num(ud.radarRadius))
	end
	if (ud.transportCapacity or 0) > 0 then
		grid.Row("Transport capacity:", Num(ud.transportCapacity))
	end
	if (ud.buildSpeed or 0) > 0 and not ud.isFactory then
		grid.Row("Build power:", Num(ud.buildSpeed, 1))
	end
	if cp.supplyrange then
		grid.Row("Supply range:", Num(cp.supplyrange))
	end
	if cp.maxammo then
		local ammoText = Num(cp.maxammo)
		if unitID then
			local ammo = spGetUnitRulesParam(unitID, "ammo")
			if ammo then
				ammoText = Num(ammo) .. " / " .. ammoText
			end
		end
		grid.Row("Ammunition:", ammoText)
		if cp.weaponcost then
			grid.Row("Logistics per shot:", Num(cp.weaponcost, 1))
		end
	end
	if cp.maxfuel then
		grid.Row("Fuel:", Num(tonumber(cp.maxfuel) * fuelMapScale))
	end
	if cp.fearlimit or cp.feartarget then
		grid.Row("Suppression limit:", Num(tonumber(cp.fearlimit) or 25))
		if unitID then
			local fear = spGetUnitRulesParam(unitID, "fear") or 0
			if fear > 0 then
				grid.Row("Suppression:", Num(fear, 1))
			end
		end
	end
	if unitID then
		local xp = Spring.GetUnitExperience(unitID)
		if xp and xp > 0 then
			grid.Row("Experience:", Num(xp, 2))
		end
	end
end

local ARMOUR_SIDES = {"front", "side", "rear", "top"}

local function AddArmourStats(grid, ud)
	local armourString = ud.customParams.armour
	if not armourString then
		return
	end
	local ok, armour = pcall(table.unserialize, armourString)
	if not (ok and type(armour) == "table") then
		return
	end
	local pieces = {}
	for piece in pairs(armour) do
		pieces[#pieces + 1] = piece
	end
	table.sort(pieces, function(a, b)
		if a == "base" then return true end
		if b == "base" then return false end
		return a < b
	end)
	grid.Blank()
	grid.Header("Armour (mm, effective)")
	for _, piece in ipairs(pieces) do
		local values = {}
		for _, side in ipairs(ARMOUR_SIDES) do
			local plate = armour[piece][side]
			if plate and plate.thickness then
				local effective = plate.thickness / math.cos(math.rad(plate.slope or 0))
				values[#values + 1] = side:sub(1, 1):upper() .. side:sub(2) .. " " .. Num(effective)
			end
		end
		grid.Row(piece:sub(1, 1):upper() .. piece:sub(2) .. ":", table.concat(values, "  "))
	end
end

local function AddWeaponStats(grid, ud)
	local weapons = ud.weapons
	local weaponsWithAmmo = (ud.customParams.maxammo and tonumber(ud.customParams.weaponswithammo or 2)) or 0
	local seen = {}
	local order = {}
	for i = 1, #weapons do
		local weaponDefID = weapons[i].weaponDef
		local wd = WeaponDefs[weaponDefID]
		if IsRealWeapon(wd) then
			if seen[weaponDefID] then
				seen[weaponDefID].count = seen[weaponDefID].count + 1
			else
				seen[weaponDefID] = {count = 1, index = i}
				order[#order + 1] = weaponDefID
			end
		end
	end
	for _, weaponDefID in ipairs(order) do
		local wd = WeaponDefs[weaponDefID]
		local cp = wd.customParams or {}
		local data = seen[weaponDefID]
		local name = wd.description ~= "" and wd.description or wd.name
		if data.count > 1 then
			name = name .. " x" .. data.count
		end
		grid.Blank()
		grid.Header(name)
		if cp.damagetype and DAMAGE_TYPE_NAMES[cp.damagetype] then
			grid.Row("Type:", DAMAGE_TYPE_NAMES[cp.damagetype])
		end
		local shots = (wd.salvoSize or 1) * (wd.projectiles or 1)
		local damages = wd.damages
		local shotsText = (shots > 1 and (" x" .. shots)) or ""
		for _, target in ipairs(DAMAGE_TARGETS) do
			local armorType = Game.armorTypes[target[1]]
			local damage = armorType and damages[armorType]
			if damage and damage > 0 then
				grid.Row("Damage vs " .. target[2]:lower() .. ":", Num(damage) .. shotsText)
			end
		end
		local pen100, pen1000 = GetPenetration(cp)
		if pen100 and pen100 > 0 then
			if pen1000 and pen1000 ~= pen100 then
				grid.Row("Penetration:", Num(pen100) .. "mm at 100m, " .. Num(pen1000) .. "mm at 1000m")
			else
				grid.Row("Penetration:", Num(pen100) .. "mm")
			end
		end
		grid.Row("Range:", Num(wd.range))
		grid.Row("Reload:", Seconds(wd.reload))
		if (wd.damageAreaOfEffect or 0) > 8 then
			grid.Row("Blast radius:", Num(wd.damageAreaOfEffect / 2))
		end
		if wd.manualFire then
			grid.Row("Fire:", "Manual (special weapon)")
		end
		if data.index <= weaponsWithAmmo then
			grid.Row("Uses ammunition:", "yes")
		end
	end
end

local function AddBuildOptions(parent, y, ud, width)
	local buildOptions = ud.buildOptions
	if not (options.showBuildOptions.value and buildOptions and #buildOptions > 0) then
		return y
	end
	local shown = {}
	for i = 1, #buildOptions do
		local bud = UnitDefs[buildOptions[i]]
		-- Morph pseudo units are an implementation detail.
		if bud and not bud.name:find("_morph_", 1, true) then
			shown[#shown + 1] = bud
		end
	end
	if #shown == 0 then
		return y
	end
	Chili.Label:New{
		parent = parent,
		x = 0,
		y = y + 6,
		caption = "Builds",
		objectOverrideFont = WG.GetSpecialFont(13, "s44stats_header", {
			color = COLOR_HEADER, outline = true, outlineWidth = 2, outlineWeight = 2,
		}),
	}
	y = y + 6 + ROW_HEIGHT + 4
	local iconSize = 48
	local columns = math.max(1, math.floor((width - 30) / iconSize))
	for i = 1, #shown do
		local bud = shown[i]
		local col = (i - 1) % columns
		local row = math.floor((i - 1) / columns)
		Chili.Image:New{
			parent = parent,
			x = col * iconSize,
			y = y + row * iconSize,
			width = iconSize - 2,
			height = iconSize - 2,
			file = "#" .. bud.id,
			tooltip = Spring.Utilities.GetHumanName(bud) .. " - " .. Spring.Utilities.GetDescription(bud) ..
				"\n" .. Num(bud.metalCost) .. " Command" ..
				"\n\255\1\255\1Click\255\255\255\255: show stats",
			OnClick = {function()
				local mx, my = Spring.GetMouseState()
				WG.MakeStatsWindow(bud, mx, my)
			end},
		}
	end
	return y + math.ceil(#shown / columns) * iconSize
end

local function BuildContent(parent, ud, unitID, width)
	Chili.Image:New{
		parent = parent,
		right = 0,
		y = 0,
		width = PIC_SIZE,
		height = PIC_SIZE,
		file = "#" .. ud.id,
	}
	local helptext = Chili.TextBox:New{
		parent = parent,
		x = 0,
		y = 0,
		right = PIC_SIZE + 8,
		text = Spring.Utilities.GetHelptext(ud, unitID),
		objectOverrideFont = WG.GetSpecialFont(13, "s44stats_help", {color = COLOR_DIM}),
	}
	-- TextBox height is only known after layout; estimate from the text.
	local charsPerLine = math.max(20, math.floor((width - PIC_SIZE - 40) / 7))
	local text = helptext.text or ""
	local lines = 0
	for paragraph in (text .. "\n"):gmatch("([^\n]*)\n") do
		lines = lines + math.max(1, math.ceil(#paragraph / charsPerLine))
	end
	local y = math.max(PIC_SIZE, lines * 15) + 8

	local grid = MakeStatsGrid()
	AddGeneralStats(grid, ud, unitID)
	AddArmourStats(grid, ud)
	AddWeaponStats(grid, ud)
	y = grid.Build(parent, y)
	y = AddBuildOptions(parent, y, ud, width)
	return y
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Windows

local function CloseWindow(window)
	for i = #statsWindows, 1, -1 do
		if statsWindows[i] == window then
			table.remove(statsWindows, i)
		end
	end
	window:Dispose()
end

local function MakeStatsWindow(ud, x, y, unitID)
	if not ud then
		return
	end
	local height = options.windowHeight.value
	if x and options.windowToCursor.value then
		y = screenHeight - y
	else
		x = (screenWidth - WINDOW_WIDTH) / 2
		y = (screenHeight - height) / 3
	end
	x = math.max(0, math.min(screenWidth - WINDOW_WIDTH, x))
	y = math.max(0, math.min(screenHeight - height, y))

	local window = Chili.Window:New{
		parent = screen0,
		x = x,
		y = y,
		width = WINDOW_WIDTH,
		height = height,
		minWidth = 300,
		minHeight = 250,
		resizable = true,
		draggable = true,
		caption = Spring.Utilities.GetHumanName(ud, unitID) .. " - " .. Spring.Utilities.GetDescription(ud, unitID),
		padding = {8, 24, 8, 8},
	}
	local scroll = Chili.ScrollPanel:New{
		parent = window,
		x = 0,
		y = 0,
		right = 0,
		bottom = BUTTON_HEIGHT + 6,
		horizontalScrollbar = false,
		padding = {4, 4, 4, 4},
	}
	local content = Chili.Control:New{
		parent = scroll,
		x = 0,
		y = 0,
		right = 0,
		height = 10,
		padding = {0, 0, 0, 0},
	}
	local contentHeight = BuildContent(content, ud, unitID, WINDOW_WIDTH)
	content:SetPos(nil, nil, nil, contentHeight + 10)

	Chili.Button:New{
		parent = window,
		x = 0,
		right = 0,
		bottom = 0,
		height = BUTTON_HEIGHT,
		caption = "Close",
		OnClick = {function() CloseWindow(window) end},
	}
	statsWindows[#statsWindows + 1] = window
	window:BringToFront()
	if WG.S44Debug then
		WG.S44Debug.Log("stats", ud.name, unitID)
	end
	return window
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Opening with Space+click

-- Build buttons of the command panel use "BuildUnit<name>" or "Build<name>"
-- tooltips (see gui_chili_integral_menu.lua).
local function GetTooltipUnitDef(tooltip)
	if not tooltip then
		return
	end
	if tooltip:find("BuildUnit", 1, true) == 1 then
		return UnitDefNames[tooltip:sub(10)]
	elseif tooltip:find("Build", 1, true) == 1 then
		return UnitDefNames[tooltip:sub(6)]
	elseif tooltip:find("Morph", 1, true) == 1 then
		local unitDefID = tonumber(tooltip:match("(%d+)"))
		return unitDefID and UnitDefs[unitDefID]
	end
end

local function GetFeatureUnitDef(featureID)
	local fd = FeatureDefs[Spring.GetFeatureDefID(featureID)]
	if not fd then
		return
	end
	local unitName = (fd.customParams and fd.customParams.unit) or fd.name:gsub("_.*", "")
	return UnitDefNames[unitName]
end

function widget:MousePress(x, y, button)
	if button ~= 1 then
		return false
	end
	local _, _, meta = spGetModKeyState()
	if not meta then
		return false
	end
	local _, cmdID = Spring.GetActiveCommand()
	if cmdID then
		return false
	end
	local ud = GetTooltipUnitDef(screen0.currentTooltip)
	if ud then
		MakeStatsWindow(ud, x, y)
		return true
	end
	if screen0.hoveredControl then
		return false
	end
	local thingType, thingID = spTraceScreenRay(x, y, false, false, false, true)
	if thingType == "unit" then
		local unitDefID = spGetUnitDefID(thingID)
		if unitDefID then
			MakeStatsWindow(UnitDefs[unitDefID], x, y, thingID)
			return true
		end
	elseif thingType == "feature" then
		ud = GetFeatureUnitDef(thingID)
		if ud then
			MakeStatsWindow(ud, x, y)
			return true
		end
	end
	return false
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:ViewResize(vsx, vsy)
	screenWidth = vsx / (WG.uiScale or 1)
	screenHeight = vsy / (WG.uiScale or 1)
end

function widget:Initialize()
	Chili = WG.Chili
	if not Chili then
		widgetHandler:RemoveWidget()
		return
	end
	screen0 = Chili.Screen0
	widget:ViewResize(Spring.GetViewGeometry())
	WG.MakeStatsWindow = MakeStatsWindow
end

function widget:Shutdown()
	for i = #statsWindows, 1, -1 do
		statsWindows[i]:Dispose()
	end
	statsWindows = {}
	if WG.MakeStatsWindow == MakeStatsWindow then
		WG.MakeStatsWindow = nil
	end
end
