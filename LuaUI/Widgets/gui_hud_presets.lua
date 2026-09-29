function widget:GetInfo()
	return {
		name      = "HUD Presets",
		desc      = "Sets the default UI layout and provides Zero-K's minimap left/right HUD presets.",
		author    = "Google Frog (Zero-K), adapted for Spring: 1944",
		date      = "24 August, 2014",
		license   = "GNU GPL, v2 or later",
		layer     = 51,
		enabled   = true,
		handler   = true,
	}
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- A reduced port of Zero-K's gui_hud_presets.lua. Zero-K lays out its panels
-- from the screen size (in UI-scaled coordinates) instead of each panel
-- guessing its own position. Only the two presets Zero-K offers by default
-- are kept: minimap right (default) and minimap left. 'None' keeps whatever
-- the player arranged with Ctrl+F11.

local RESOURCE_BAR_HEIGHT = 58
local CHAT_PADDING = 100

local coreName, corePath = "Chili Core Selector", "Settings/HUD Panels/Quick Selection Bar"
local integralName, integralPath = "Chili Integral Menu", "Settings/HUD Panels/Command Panel"
local minimapName, minimapPath = "Chili Minimap", "Settings/HUD Panels/Minimap"
local consoleName, consolePath = "Chili Pro Console", "Settings/HUD Panels/Chat"
local selName, selPath = "Chili Selections & CursorTip v2", "Settings/HUD Panels/Selected Units Panel"
local econName, econPath = "1944 Resource Bars", "Settings/HUD Panels/Economy Panel"
local dockName, dockPath = "Chili Docking", "Settings/HUD Panels/Extras/Docking"

local firstUpdate = true
local needToCallFunction

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Skinning and widget options

local function SetFancySkinBottomLeft()
	WG.SetWidgetOption(coreName, corePath, "fancySkinning", "panel_0110_small")
	WG.SetWidgetOption(integralName, integralPath, "fancySkinning", true)
	WG.SetWidgetOption(integralName, integralPath, "flushLeft", true)
	WG.SetWidgetOption(minimapName, minimapPath, "fancySkinning", "panel_1100_large")
	WG.SetWidgetOption(selName, selPath, "fancySkinning", "panel_2100")
	WG.crude.SetMenuSkinClass("panel_0011_small")
end

local function SetFancySkinBottomRight()
	WG.SetWidgetOption(coreName, corePath, "fancySkinning", "panel_1100_small")
	WG.SetWidgetOption(integralName, integralPath, "fancySkinning", true)
	WG.SetWidgetOption(integralName, integralPath, "flushLeft", false)
	WG.SetWidgetOption(minimapName, minimapPath, "fancySkinning", "panel_0110_large")
	WG.SetWidgetOption(selName, selPath, "fancySkinning", "panel_0120")
	WG.crude.SetMenuSkinClass("panel_0011_small")
end

local function SetNewOptions()
	WG.SetWidgetOption(coreName, corePath, "background_opacity", 1)
	WG.SetWidgetOption(coreName, corePath, "buttonSpacing", 0.75)
	WG.SetWidgetOption(coreName, corePath, "horPaddingLeft", 5)
	WG.SetWidgetOption(coreName, corePath, "horPaddingRight", 6)
	WG.SetWidgetOption(coreName, corePath, "buttonSizeLong", 50)
	WG.SetWidgetOption(coreName, corePath, "minButtonSpaces", 3)
	WG.SetWidgetOption(coreName, corePath, "showCoreSelector", "specSpace")
	WG.SetWidgetOption(coreName, corePath, "vertPadding", 6.25)
	WG.SetWidgetOption(coreName, corePath, "vertical", true)

	WG.SetWidgetOption(integralName, integralPath, "background_opacity", 1)
	WG.SetWidgetOption(integralName, integralPath, "hide_when_spectating", false)
	WG.SetWidgetOption(integralName, integralPath, "leftPadding", 8)
	WG.SetWidgetOption(integralName, integralPath, "rightPadding", 10)

	WG.SetWidgetOption(minimapName, minimapPath, "alwaysResizable", false)
	WG.SetWidgetOption(minimapName, minimapPath, "hidebuttons", true)
	WG.SetWidgetOption(minimapName, minimapPath, "minimizable", false)
	WG.SetWidgetOption(minimapName, minimapPath, "opacity", 1)
	WG.SetWidgetOption(minimapName, minimapPath, "use_map_ratio", "armap")

	WG.SetWidgetOption(consoleName, consolePath, "backlogHideNotChat", true)
	WG.SetWidgetOption(consoleName, consolePath, "backlogShowWithChatEntry", true)

	WG.SetWidgetOption(selName, selPath, "selection_opacity", 1)
	WG.SetWidgetOption(selName, selPath, "leftPadding", 7)

	WG.SetWidgetOption(econName, econPath, "opacity", 0.95)

	WG.SetWidgetOption(dockName, dockPath, "dockEnabledPanels", false)
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Sizes

local function GetSelectionIconSize(height)
	local rows = math.floor((height - 25)/50)
	local size = math.floor((height - 25)/rows)
	local scale = (options.bottomPanelScale.value or 1)
	return math.floor((math.min(53, size) + 4) * scale + (scale - 1)*10 + 0.5)
end

local function GetBottomSizes(screenWidth, screenHeight, parity)
	local SIZE_FACTOR = (options.bottomPanelScale.value or 1)

	-- Command panel
	local integralWidth = math.max(350 * SIZE_FACTOR, math.min(500 * SIZE_FACTOR, screenWidth*0.45))
	local integralHeight = 7*math.floor((math.min(screenHeight/3.5, 200*integralWidth/450))/7)
	if integralWidth/integralHeight > 2.5 then
		integralWidth = integralHeight*2.5
	end
	WG.SetWidgetOption(integralName, integralPath, "buttonFontScale", SIZE_FACTOR)
	WG.SetWidgetOption(coreName, corePath, "buttonFontScale", SIZE_FACTOR)
	WG.SetWidgetOption(selName, selPath, "tooltipScale", SIZE_FACTOR)
	WG.SetWidgetOption(selName, selPath, "selectionScale", SIZE_FACTOR)
	if integralWidth < 480 then
		WG.SetWidgetOption(integralName, integralPath, "tabFontSize", math.floor(13*integralWidth/480) * SIZE_FACTOR)
	else
		WG.SetWidgetOption(integralName, integralPath, "tabFontSize", 14 * SIZE_FACTOR)
	end
	integralWidth = math.floor(integralWidth)

	-- Quick selection bar (vertical, next to the command panel)
	local coreSelectorHeight = math.floor(screenHeight/2)
	local coreSelectorWidth = math.ceil(integralHeight/3) + 3
	local hPad = math.ceil(screenWidth/300) + 2
	WG.SetWidgetOption(coreName, corePath, "horPaddingLeft", hPad - 5*parity)
	WG.SetWidgetOption(coreName, corePath, "horPaddingRight", hPad + 5*parity)
	WG.SetWidgetOption(coreName, corePath, "vertPadding", math.floor(hPad))
	WG.SetWidgetOption(coreName, corePath, "buttonSpacing", math.floor(hPad/2))
	WG.SetWidgetOption(coreName, corePath, "buttonSizeLong", coreSelectorWidth - 2*hPad - 1)
	local coreMinHeight = 3*(coreSelectorWidth - 2*hPad - 1) + 2*math.floor(hPad/2) + 2*math.floor(1.5*hPad)

	-- Minimap
	local mapRatio = Game.mapX/Game.mapY
	local minimapWidth, minimapHeight
	if mapRatio > 1 then
		minimapWidth = math.floor(screenWidth*options.minimapScreenSpace.value)
		minimapHeight = (minimapWidth/mapRatio)
	else
		minimapHeight = math.floor(screenWidth*options.minimapScreenSpace.value)
		minimapWidth = math.floor(minimapHeight*mapRatio)
	end
	minimapWidth = math.max(160, minimapWidth + 4)
	minimapHeight = math.max(coreMinHeight, minimapHeight)
	-- Keep a very tall map from covering the screen.
	if minimapHeight > screenHeight*0.45 then
		minimapHeight = math.floor(screenHeight*0.45)
		minimapWidth = math.max(160, math.floor(minimapHeight*mapRatio) + 4)
	end

	-- Selections
	local selectionsHeight = integralHeight*0.85
	local selectionsWidth = screenWidth - integralWidth - minimapWidth - coreSelectorWidth
	WG.SetWidgetOption(selName, selPath, "uniticon_size", GetSelectionIconSize(selectionsHeight))
	WG.SetWidgetOption(coreName, corePath, "specSpaceOverride", math.floor(integralHeight*6/7))

	-- Chat
	local maxWidth = screenWidth - 2*math.max(minimapWidth, coreSelectorWidth + integralWidth) - CHAT_PADDING
	local chatWidth = math.max(maxWidth, math.floor(screenWidth/5))
	local chatHeight = selectionsHeight

	-- Player list
	local playerlistWidth = 310
	local playerlistHeight = screenHeight/2
	local playerListControl = WG.Chili.Screen0:GetChildByName("Player List")
	if playerListControl then
		playerlistWidth = playerListControl.minWidth
	end

	return integralWidth, integralHeight,
		coreSelectorWidth, coreSelectorHeight,
		minimapWidth, minimapHeight,
		selectionsWidth, selectionsHeight,
		chatWidth, chatHeight,
		playerlistWidth, playerlistHeight
end

local function SetupTop()
	local screenWidth, screenHeight = Spring.GetViewGeometry()
	local sideHeight = 38
	local flushTop = (screenWidth <= 1650)

	local resourceBarWidth = math.max(580, math.min(screenWidth - 700, 660))

	local menuWidth
	if flushTop then
		menuWidth = math.max(350, math.ceil((screenWidth - resourceBarWidth)/2))
	else
		menuWidth = math.floor((screenWidth - resourceBarWidth)/2)
		if menuWidth > 445 then
			menuWidth = 445
		elseif menuWidth > 377 then
			menuWidth = 377
		else
			menuWidth = 347
		end
	end
	local resourceBarX = math.floor(math.min(screenWidth/2 - resourceBarWidth/2, screenWidth - resourceBarWidth - menuWidth))

	WG.SetWindowPosAndSize("S44ResourcePanel", resourceBarX, 0, resourceBarWidth, RESOURCE_BAR_HEIGHT)
	WG.SetWindowPosAndSize("epicmenubar", screenWidth - menuWidth - 3, 0, menuWidth + 3, sideHeight)

	local consoleWidth = 380
	local consoleHeight = screenHeight * 0.20
	WG.SetWindowPosAndSize("ProConsole", screenWidth - consoleWidth, sideHeight, consoleWidth, consoleHeight)
end

local function SetupNewWidgets()
	widgetHandler:EnableWidget("Chili Minimap")
	widgetHandler:EnableWidget("Chili Integral Menu")
	widgetHandler:EnableWidget("Chili Pro Console")
	widgetHandler:EnableWidget("1944 Resource Bars")
	widgetHandler:EnableWidget("Chili Core Selector")
	widgetHandler:EnableWidget("Chili Selections & CursorTip v2")
	if not WG.Chili.Screen0:GetChildByName("Player List") then
		widgetHandler:EnableWidget("Chili Crude Player List")
	end
	Spring.SendCommands("resbar 0")
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Presets

local function SetupMinimapPreset(minimapRight)
	SetupNewWidgets()
	local screenWidth, screenHeight = Spring.GetViewGeometry()
	screenHeight = math.ceil(screenHeight)
	local fudge = ((WG.uiScale or 1) > 1) and 1 or 0
	local parity = (minimapRight and 1) or -1

	if minimapRight then
		SetFancySkinBottomRight()
		needToCallFunction = SetFancySkinBottomRight
	else
		SetFancySkinBottomLeft()
		needToCallFunction = SetFancySkinBottomLeft
	end
	SetNewOptions()

	local integralWidth, integralHeight,
		coreSelectorWidth, coreSelectorHeight,
		minimapWidth, minimapHeight,
		selectionsWidth, selectionsHeight,
		chatWidth, chatHeight,
		playerlistWidth, playerlistHeight = GetBottomSizes(screenWidth, screenHeight, parity)

	local chatX = math.floor((screenWidth - chatWidth)/2)
	local chatY = screenHeight - chatHeight - selectionsHeight
	if minimapRight then
		if chatX < coreSelectorWidth + integralWidth then
			chatY = screenHeight - chatHeight - integralHeight
		end
	elseif chatX + chatWidth > screenWidth - coreSelectorWidth - integralWidth then
		chatY = screenHeight - chatHeight - integralHeight
	end

	WG.SetWindowPosAndSize("Player List",
		screenWidth - playerlistWidth,
		screenHeight - playerlistHeight - minimapHeight - 5,
		playerlistWidth,
		playerlistHeight
	)
	WG.SetWindowPosAndSize("ProChat", chatX, chatY, chatWidth, chatHeight)

	if minimapRight then
		WG.SetWindowPosAndSize("Minimap Window",
			coreSelectorWidth + integralWidth + selectionsWidth,
			screenHeight - minimapHeight,
			minimapWidth,
			minimapHeight
		)
		WG.SetWindowPosAndSize("selections",
			coreSelectorWidth + integralWidth,
			screenHeight - selectionsHeight,
			selectionsWidth + 3 + fudge,
			selectionsHeight
		)
		WG.SetWindowPosAndSize("integralwindow",
			coreSelectorWidth - 3,
			screenHeight - integralHeight,
			integralWidth + 3 + fudge,
			integralHeight
		)
		WG.SetWindowPosAndSize("selector_window",
			0,
			screenHeight - coreSelectorHeight,
			coreSelectorWidth + fudge,
			coreSelectorHeight
		)
		WG.SetWidgetOption(coreName, corePath, "leftsideofscreen", true)
	else
		WG.SetWindowPosAndSize("Minimap Window",
			0,
			screenHeight - minimapHeight,
			minimapWidth + fudge,
			minimapHeight + fudge
		)
		WG.SetWindowPosAndSize("selections",
			minimapWidth - 3,
			screenHeight - selectionsHeight,
			selectionsWidth + 3 + fudge,
			selectionsHeight
		)
		WG.SetWindowPosAndSize("integralwindow",
			minimapWidth + selectionsWidth,
			screenHeight - integralHeight,
			integralWidth + 3 + fudge,
			integralHeight
		)
		WG.SetWindowPosAndSize("selector_window",
			minimapWidth + selectionsWidth + integralWidth,
			screenHeight - coreSelectorHeight,
			coreSelectorWidth,
			coreSelectorHeight
		)
		WG.SetWidgetOption(coreName, corePath, "leftsideofscreen", false)
	end

	SetupTop()
	if WG.S44Debug then
		WG.S44Debug.Log("env", "HUD preset", minimapRight and "minimapRight" or "minimapLeft", screenWidth, screenHeight)
	end
end

local presetFunction = {
	minimapLeft = function() SetupMinimapPreset(false) end,
	minimapRight = function() SetupMinimapPreset(true) end,
}

local function UpdateInterfacePreset(self)
	if firstUpdate then
		-- Don't reset the UI while initializing
		return
	end
	if presetFunction[self.value] then
		presetFunction[self.value]()
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Options

options_path = 'Settings/HUD Presets'
options_order = {'updateNewDefaults', 'setToDefault', 'maintainDefaultUI', 'minimapScreenSpace', 'bottomPanelScale', 'interfacePreset'}
options = {
	updateNewDefaults = {
		name  = "Stay up to date",
		type  = "bool",
		value = true,
		desc = "Keeps one of the presets below applied. Untick to arrange the interface yourself (Ctrl+F11) with the 'None' preset.",
		noHotkey = true,
	},
	setToDefault = {
		name  = "Set To Default Once",
		type  = "bool",
		value = true,
		desc = "Resets the HUD to the default next time this widget is initialized.",
		advanced = true,
		noHotkey = true,
	},
	maintainDefaultUI = {
		name  = "Reset on screen resolution change",
		type  = "bool",
		value = true,
		desc = "Resets the UI when screen resolution changes. Disable if you plan to customise your UI.",
		noHotkey = true,
	},
	minimapScreenSpace = {
		name = "Minimap Size",
		type = "number",
		value = 0.19, min = 0.05, max = 0.4, step = 0.01,
		OnChange = function(self)
			UpdateInterfacePreset(options.interfacePreset)
		end,
	},
	bottomPanelScale = {
		name = "Bottom Panel Scale",
		type = "number",
		value = 1.04, min = 1, max = 2, step = 0.01,
		OnChange = function(self)
			UpdateInterfacePreset(options.interfacePreset)
		end,
	},
	interfacePreset = {
		name = 'UI Preset',
		type = 'radioButton',
		value = 'default',
		items = {
			{key = 'minimapLeft', name = 'Minimap Left',},
			{key = 'minimapRight', name = 'Minimap Right (default)',},
			{key = 'default', name = 'None', desc = [[This allows you to modify your UI with Ctrl+F11 and have the changes remembered on subsequent launches.
You must untick 'Stay up to date' above to select this option.]],},
		},
		noHotkey = true,
		OnChange = UpdateInterfacePreset,
	},
}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Callins

local timeSinceUpdate = 0
local UPDATE_FREQUENCY = 5
local oldWidth = 0
local oldHeight = 0
local callCount = 0

function widget:Update(dt)
	if needToCallFunction then
		needToCallFunction()
		callCount = callCount + 1
		if callCount > 4 then
			needToCallFunction = nil
			callCount = 0
		end
	end

	if options.setToDefault.value then
		options.interfacePreset.value = "minimapRight"
		options.setToDefault.value = false
	end

	if options.updateNewDefaults.value then
		if not presetFunction[options.interfacePreset.value] then
			options.interfacePreset.value = "minimapRight"
		end
	end

	if firstUpdate then
		firstUpdate = false
		local screenWidth, screenHeight = Spring.GetViewGeometry()
		oldWidth = screenWidth
		oldHeight = screenHeight
		UpdateInterfacePreset(options.interfacePreset)
	end

	if options.maintainDefaultUI.value then
		timeSinceUpdate = timeSinceUpdate + dt
		if timeSinceUpdate > UPDATE_FREQUENCY then
			local screenWidth, screenHeight = Spring.GetViewGeometry()
			if oldWidth ~= screenWidth or oldHeight ~= screenHeight then
				oldWidth = screenWidth
				oldHeight = screenHeight
				UpdateInterfacePreset(options.interfacePreset)
			end
			timeSinceUpdate = 0
		end
	end
end

function widget:ViewResize(screenWidth, screenHeight)
	if options.maintainDefaultUI.value and not firstUpdate then
		oldWidth = screenWidth
		oldHeight = screenHeight
		UpdateInterfacePreset(options.interfacePreset)
	end
end
