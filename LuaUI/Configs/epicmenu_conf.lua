-- EPIC Menu configuration for Spring: 1944.
-- Adapted from Zero-K's epicmenu_conf.lua. Menu paths and option names follow
-- Zero-K's wherever the option is the same, so a Zero-K configuration imported
-- on first run (see gui_epicmenu.lua) lands on the matching options.

local confdata = {}
confdata.title = 'S:44'
confdata.title_image = nil
confdata.default_source_file = 's44_keys.lua' --the file in the ZIP archive holding the default keys; also the name of the user's copy.
confdata.description = 'Spring: 1944 is a free, open source WWII real time strategy game.'

local color = {
	white = {1,1,1,1},
	yellow = {1,1,0,1},
	amber = {1, 0.82, 0.42, 1},
	gray = {0.5,.5,.5,1},
	darkgray = {0.3,.3,.3,1},
	cyan = {0,1,1,1},
	red = {1,0,0,1},
	darkred = {0.5,0,0,1},
	blue = {0,0,1,1},
	black = {0,0,0,1},
	darkgreen = {0,0.5,0,1},
	green = {0,1,0,1},
	postit = {1,0.9,0.5,1},

	grayred = {0.5,0.4,0.4,1},
	grayblue = {0.4,0.4,0.45,1},
	transblack = {0,0,0,0.3},
	transblack2 = {0,0,0,0.7},
	transGray = {0.1,0.1,0.1,0.8},

	empty = {0,0,0,0},
	null = {nil, nil, nil, 1},
	transnull = {nil, nil, nil, 0.3},
	transnull2 = {nil, nil, nil, 0.5},
	transnull3 = {nil, nil, nil, 0.8},
}

color.tooltip_bg = color.transnull3
color.tooltip_fg = color.null
color.tooltip_info = color.amber
color.tooltip_help = color.postit

color.main_bg = color.transnull3
color.main_fg = color.null

color.menu_bg = color.null
color.menu_fg = color.null

color.game_bg = color.null
color.game_fg = color.null

color.sub_bg    = color.transnull
color.sub_fg     = color.null
color.sub_header = color.amber

color.sub_button_bg = color.null
color.sub_button_fg = color.null

color.sub_back_bg = color.null
color.sub_back_fg = color.null

color.sub_close_bg = color.null
color.sub_close_fg = color.null

color.stats_bg = color.sub_bg
color.stats_fg = color.sub_fg
color.stats_header = color.sub_header

color.context_bg = color.transnull
color.context_fg = color.null
color.context_header = color.amber

color.disabled_bg = color.transGray
color.disabled_fg = color.darkgray

confdata.color = color

local spSendCommands = Spring.SendCommands

confdata.eopt = {}

local function AddOption(path, option)
	option.path = path or "Settings/Broken Paths"
	if not option.key then
		option.key = option.name
	end
	table.insert(confdata.eopt, option)
end

--ShortHand for adding a button
local function ShButton(path, caption, action2, tooltip, advanced, icon, DisableFunc, bindMod)
	AddOption(path,
	{
		type='button',
		name=caption,
		desc = tooltip or '',
		action = (type(action2) == 'string' and action2 or nil),
		OnChange = (type(action2) ~= 'string' and action2 or nil),
		key=caption,
		bindMod = bindMod,
		advanced = advanced,
		icon = icon,
		DisableFunc = DisableFunc or nil, --function that greys out the button (does not actually disable it)
	})
end

--ShortHand for adding radiobuttons
local function ShRadio(path, caption, items,defValue, action2, advanced, nhk)
	AddOption(path,
	{
		type='radioButton',
		name=caption,
		key=caption,
		items = items or {},
		value = defValue or '',
		action = (type(action2) == 'string' and action2 or nil),
		OnChange = (type(action2) ~= 'string' and action2 or nil),
		advanced = advanced,
		noHotkey = nhk,
	})
end

--ShortHand for adding a label
local function ShLabel(path, caption)
	AddOption(path,
	{
		type='label',
		name=caption,
		value = caption,
		key=caption,
	})
end

local imgPath = LUAUI_DIRNAME  .. 'Images/'
confdata.subMenuIcons = {
	['Settings'] = imgPath..'epicmenu/settings.png',
	['Help'] = imgPath..'epicmenu/questionmark.png',

	['Settings/Unit Behaviour'] = imgPath..'epicmenu/robot2.png',
	['Hotkeys']         = imgPath..'epicmenu/keyboard.png',

	['Hotkeys/Misc']                = imgPath..'epicmenu/misc.png',
	['Hotkeys/Camera']              = imgPath..'epicmenu/video_camera.png',
	['Hotkeys/Selection']           = imgPath..'epicmenu/selection.png',
	['Hotkeys/Commands']            = imgPath..'epicmenu/fingertap.png',
	['Hotkeys/Grid Hotkeys']        = imgPath..'epicmenu/grid.png',

	['Hotkeys/Camera/Camera Position Hotkeys'] = imgPath..'epicmenu/marker.png',
	['Hotkeys/Camera/Camera Mode Hotkeys']     = imgPath..'epicmenu/move.png',

	['Settings/Reset Settings']     = imgPath..'epicmenu/undo.png',
	['Settings/Audio']              = imgPath..'epicmenu/vol.png',
	['Settings/Camera']             = imgPath..'epicmenu/video_camera.png',
	['Settings/Graphics']           = imgPath..'epicmenu/graphics.png',
	['Settings/HUD Panels']         = imgPath..'epicmenu/control_panel.png',
	['Settings/HUD Presets']        = imgPath..'epicmenu/speed-test-icon.png',
	['Settings/Interface']          = imgPath..'epicmenu/robotarm.png',
	['Settings/Misc']               = imgPath..'epicmenu/misc.png',
	['Settings/Spectating']         = imgPath..'epicmenu/popcorn.png',

	['Settings/Interface/Mouse Cursor']             = imgPath..'epicmenu/input_mouse.png',
	['Settings/Interface/Map']                      = imgPath..'epicmenu/map.png',
	['Settings/Interface/Healthbars']               = imgPath..'epicmenu/lightbulb.png',
	['Settings/Interface/Build ETA']                = imgPath..'epicmenu/stop_watch_icon.png',
	['Settings/Interface/Command Visibility']       = imgPath..'epicmenu/fingertap.png',
	['Settings/Interface/Line Formations']          = imgPath..'epicmenu/move.png',
	['Settings/Interface/Selection']                = imgPath..'epicmenu/selection.png',
	['Settings/Interface/Selection Filtering']      = imgPath..'epicmenu/selection_rank.png',
	['Settings/Interface/Control Groups']           = imgPath..'epicmenu/addusergroup.png',
	['Settings/Interface/Team Colors']              = imgPath..'epicmenu/people.png',
	['Settings/Interface/Ranges']                   = imgPath..'epicmenu/target.png',

	['Settings/HUD Panels/Minimap']                 = imgPath..'epicmenu/map.png',
	['Settings/HUD Panels/Economy Panel']           = imgPath..'epicmenu/control_panel.png',
	['Settings/HUD Panels/Tooltip']                 = imgPath..'epicmenu/lightbulb.png',
	['Settings/HUD Panels/Chat']                    = imgPath..'epicmenu/people.png',
	['Settings/HUD Panels/Pause Screen']            = imgPath..'epicmenu/media_playback_pause.png',
	['Settings/HUD Panels/Unit Stats Help Window']  = imgPath..'epicmenu/questionmark.png',
	['Settings/HUD Panels/Player List']             = imgPath..'epicmenu/people.png',
	['Settings/HUD Panels/Extras/Docking']          = imgPath..'epicmenu/anchor.png',
	['Settings/HUD Panels/Selected Units Panel']    = imgPath..'epicmenu/grid.png',
	['Settings/HUD Panels/Command Panel']           = imgPath..'epicmenu/control_panel.png',
	['Settings/HUD Panels/Quick Selection Bar']     = imgPath..'epicmenu/selection.png',
	['Settings/HUD Panels/Extras']                  = imgPath..'epicmenu/misc.png',

	['Settings/Graphics/Post-processing']           = imgPath..'epicmenu/stock_brightness.png',
}

confdata.simpleModeDirectory = {
	['Reset Settings'] = true,
	['Interface'] = true,
	['Commands'] = true,
	['Presets'] = true,
	['Audio'] = true,
	['Graphics'] = true,
	['Camera'] = true,
	['Unit Behaviour'] = true,
}
confdata.simpleModeFullDirectory = {
	'Reset Settings',
	'Hotkeys',
	'Unit Behaviour',
	'Help',
}

--- GENERAL SETTINGS --- settings about settings
local generalPath = 'Settings/Reset Settings'
	ShLabel(generalPath, 'Minimal Graphics - Requires restart.')
	ShButton(generalPath, 'Minimal graphic settings',function()
					spSendCommands{"water 0",
						"Shadows 0",
						"maxparticles 100",
						"advmodelshading 0",
						"grounddecals 0",
						'luaui disablewidget LupsManager',
						"luaui disablewidget Lups",
						"luaui disablewidget Screen-Space Ambient Occlusion",
						"luaui disablewidget Post-processing",
					}
				end,
				'Test minimal graphics. Use the main settings menu to make a permanent if necessary.'
			)
	ShLabel(generalPath, 'Reset settings - Requires restart.')
	ShButton(generalPath, 'Reset settings', function() WG.crude.ResetSettings() end, 'Reset all interface settings to the default. Restart the battle to apply.')
	ShLabel(generalPath, 'Reset hotkeys - Requires restart.')
	ShButton(generalPath, 'Reset hotkeys',function() WG.crude.ResetKeys() end, 'Reset all hotkeys to the default. Restart the battle to apply.')

--- Hotkeys ---
local hotkeysMiscPath = 'Hotkeys/Misc'
	ShButton(hotkeysMiscPath, 'Pause/Unpause', 'pause', nil, nil, imgPath .. 'epicmenu/media_playback_pause.png')
	ShButton(hotkeysMiscPath, 'Increase Speed', 'speedup')
	ShButton(hotkeysMiscPath, 'Decrease Speed', 'slowdown')
	ShButton(hotkeysMiscPath, 'Save Screenshot (PNG)', 'screenshot png', 'Find your screenshots under Spring/screenshots')
	ShButton(hotkeysMiscPath, 'Save Screenshot (JPG)', 'screenshot jpg', 'Find your screenshots under Spring/screenshots')
	ShButton(hotkeysMiscPath, 'Zoom In', 'movedown', 'Key to zoom the camera out.')
	ShButton(hotkeysMiscPath, 'Zoom Out', 'moveup', 'Key to zoom the camera in.')
	ShButton(hotkeysMiscPath, 'Game Info', "gameinfo", '', true)

--- CAMERA ---
local cameraPath = 'Settings/Camera'
	ShRadio( cameraPath,
		'Camera Type', {
			{name = 'Default camera', key='Default', desc='Default camera', hotkey=nil},
			{name = 'Rotatable Overhead',key='Rotatable Overhead', hotkey=nil},
			{name = 'FPS (experimental)',key='FPS', hotkey=nil},
			{name = 'Free (experimental)',key='Free', hotkey=nil},
			{name = 'Spring (experimental)',key='Spring',  hotkey=nil},
		},'Default',
		function(self)
			local key = self.value
			if key == 'FPS' then
				spSendCommands{"viewfps"}
			elseif key == 'Free' then
				spSendCommands{"viewfree"}
			elseif key == 'Rotatable Overhead' then
				spSendCommands{"viewrot"}
			elseif key == 'Spring' then
				spSendCommands{"viewspring"}
			else
				spSendCommands{"viewta"} -- also the fallback, e.g. for Zero-K's COFC
			end
		end
		)

local camerHotkeys = 'Hotkeys/Camera'
	ShButton(camerHotkeys, 'Move Forward', 'moveforward')
	ShButton(camerHotkeys, 'Move Back', 'moveback')
	ShButton(camerHotkeys, 'Move Left', 'moveleft')
	ShButton(camerHotkeys, 'Move Right', 'moveright')
	ShLabel(camerHotkeys, '')
	ShButton(camerHotkeys, 'Overview Mode', 'toggleoverview')
	ShButton(camerHotkeys, 'Track unit', 'track')
	ShButton(camerHotkeys, 'Flip the Camera', 'viewtaflip')
	ShButton(camerHotkeys, 'Panning mode','mousestate', 'Note: must be bound to a key for use', true)
	ShButton(camerHotkeys, 'Tilt Camera', 'movetilt', "Tilt the camera with mouse wheel while this key is held.", nil, nil, nil, true)
	ShButton(camerHotkeys, 'Overview Zoom', 'movereset', "Mousewheel down with this key held to zoom all the way out. Mousewheel up to return to previous zoom level.", nil, nil, nil, true)
	ShButton(camerHotkeys, 'Fast Camera Movement', 'movefast', "Increased camera speed while this key is held.", nil, nil, nil, true)
	ShButton(camerHotkeys, 'Slow Camera Movement', 'moveslow', "Decreased camera speed while this key is held.", nil, nil, nil, true)

	ShLabel(camerHotkeys, 'Saving Position and Switching Camera')

local camerTypeZoom = 'Hotkeys/Camera/Camera Position Hotkeys'
	ShButton(camerTypeZoom, 'Cycle through alerts', 'lastmsgpos')

-- Control menu order
ShLabel('Hotkeys/Commands', 'Command Categories')

--- HUD Panels --- Only settings that pertain to windows/icons at the drawscreen level should go here.
local HUDPath = 'Settings/HUD Panels/Extras'
	ShButton(HUDPath, 'Tweak Mode (Esc to exit)', 'luaui tweakgui', 'Tweak Mode. Move and resize parts of the user interface. (Hit Esc to exit)')

--- Interface --- anything that's an interface but not a HUD Panel
local pathMouse = 'Settings/Interface/Mouse Cursor'
	AddOption(pathMouse,
	{
		name = 'Hardware Cursor',
		type = 'bool',
		desc = 'Temporary toggle. For a permanent toggle change go to Settings in the non-game main menu.',
		springsetting = 'HardwareCursor',
		OnChange=function(self) spSendCommands{"hardwarecursor " .. (self.value and 1 or 0) } end,
	})

ShLabel('Settings/Interface/Selection', 'Selection Display Options')
local pathSelectionPlatters = 'Settings/Interface/Selection/Team Platters'
	ShButton(pathSelectionPlatters, 'Toggle Team Platters', function() spSendCommands{"luaui togglewidget Team Platter Expanded"} end, "Puts a team-coloured disk below units")
ShLabel('Settings/Interface/Selection', 'General Settings')

--- MISC --- Ungrouped. If some of the settings here can be grouped together, make a new subsection or its own section.
local pathMisc = 'Settings/Misc'
	AddOption(pathMisc,
	{
		name = 'Show Advanced Settings',
		desc = 'Show developer tools and settings that should essentially never be disabled, except for testing.',
		type = 'bool',
		value = false,
		OnChange = function (self)
			WG.Epic_SetShowAdvancedSettings(self.value)
		end,
	})
	AddOption(pathMisc,
	{
		name = 'Use uikeys.txt',
		desc = 'NOT RECOMMENDED! Enable this to use the engine\'s keybind file. This can break existing functionality. Requires restart.',
		type = 'bool',
		advanced = true,
		noHotkey = true,
		value = false,
	})
	AddOption(pathMisc,
	{
		name = 'Interface debug log',
		desc = 'Write interface events (selection, commands, key presses, menu and lobby actions) to infolog.txt, marked [S44UI]. '..
		       'Turn this on before reproducing a problem and send infolog.txt along with the report. Also toggled by /luaui s44uidebug.',
		type = 'bool',
		springsetting = 'S44UIDebugLog',
		noHotkey = true,
		OnChange = function (self)
			if WG.S44Debug and WG.S44Debug.IsEnabled() ~= self.value then
				WG.S44Debug.SetEnabled(self.value)
			end
		end,
	})
	ShButton(pathMisc, 'Toggle Widget Profiler', function() spSendCommands{"luaui togglewidget Widget Profiler New"} end, '', true)

--- GRAPHICS --- anything graphical that has a significant impact on performance and isn't necessary for gameplay
local pathGraphicsPreset = 'Settings/Graphics'
	ShLabel(pathGraphicsPreset, 'Quality Presets - Require restart.')
	local QUALITY_PRESETS = {
		{key = 'very low', name = 'Very Low', config = {DepthBufferBits = 16, ReflectiveWater = 0, Shadows = 0, ["3DTrees"] = 0, AdvSky = 0, DynamicSky = 0,
			SmoothPoints = 0, SmoothLines = 0, FSAA = 0, FSAALevel = 0, AdvUnitShading = 0, AllowDeferredMapRendering = 0},
			widgets = {"disablewidget Screen-Space Ambient Occlusion", "disablewidget Post-processing"}},
		{key = 'low', name = 'Low', config = {DepthBufferBits = 16, ReflectiveWater = 0, Shadows = 0, ["3DTrees"] = 1, AdvSky = 0, DynamicSky = 0,
			SmoothPoints = 0, SmoothLines = 0, FSAA = 0, FSAALevel = 0, AdvUnitShading = 0, AllowDeferredMapRendering = 0},
			widgets = {"disablewidget Screen-Space Ambient Occlusion", "disablewidget Post-processing"}},
		{key = 'medium', name = 'Medium', config = {DepthBufferBits = 16, ReflectiveWater = 1, Shadows = 0, ["3DTrees"] = 1, AdvSky = 0, DynamicSky = 0,
			SmoothPoints = 0, SmoothLines = 1, FSAA = 0, FSAALevel = 0, AdvUnitShading = 0, AllowDeferredMapRendering = 0},
			widgets = {"disablewidget Screen-Space Ambient Occlusion", "disablewidget Post-processing"}},
		{key = 'high', name = 'High', config = {DepthBufferBits = 24, ReflectiveWater = 2, Shadows = 1, ["3DTrees"] = 1, AdvSky = 0, DynamicSky = 0,
			SmoothPoints = 0, SmoothLines = 1, FSAA = 0, FSAALevel = 0, AdvUnitShading = 1, AllowDeferredMapRendering = 0},
			widgets = {"disablewidget Screen-Space Ambient Occlusion", "enablewidget Post-processing"}},
		{key = 'very high', name = 'Very High', config = {DepthBufferBits = 24, ReflectiveWater = 3, Shadows = 1, ["3DTrees"] = 1, AdvSky = 1, DynamicSky = 1,
			SmoothPoints = 1, SmoothLines = 1, FSAA = 1, FSAALevel = 1, AdvUnitShading = 1, AllowDeferredMapRendering = 1},
			widgets = {"enablewidget Screen-Space Ambient Occlusion", "enablewidget Post-processing"}},
	}
	for i = 1, #QUALITY_PRESETS do
		local preset = QUALITY_PRESETS[i]
		ShButton(pathGraphicsPreset, 'Apply ' .. preset.name .. ' Quality', function()
			for k, v in pairs(preset.config) do
				Spring.SetConfigInt(k, v)
			end
			for j = 1, #preset.widgets do
				spSendCommands{"luaui " .. preset.widgets[j]}
			end
			Spring.Echo("game_message: " .. preset.name .. " graphics quality applied. Restart the game for all changes to take effect.")
		end, 'Sets engine graphics options (water, shadows, trees, sky, anti-aliasing) and the S:44 shader effects. Most changes need a restart.')
	end

local pathGraphicsMap = 'Settings/Graphics/Map Detail'
	AddOption(pathGraphicsMap,
	{
		name = 'Ground Decals',
		desc = 'Whether explosions leave scars on the ground.',
		type = 'bool',
		springsetting = 'GroundDecals',
		OnChange=function(self) spSendCommands{"grounddecals " .. (self.value and 1 or 0) } end,
		noHotkey = true,
	} )

local pathGraphicsExtras = 'Settings/Graphics/Effects'
	AddOption(pathGraphicsExtras,
	{
		name = 'Particle density',
		desc = 'Temporary toggle. For a permanent toggle change go to Settings in the non-game main menu.',
		advanced = true,
		type = 'number',
		min = 250,
		max = 20000,
		step = 250,
		value = 10000,
		springsetting = 'MaxParticles',
		OnChange=function(self) spSendCommands{"maxparticles " .. self.value } end,
	} )
	ShButton(pathGraphicsExtras, 'Toggle Lups (Lua Particle System)', function() spSendCommands{'luaui togglewidget LupsManager','luaui togglewidget Lups'} end )
	ShButton(pathGraphicsExtras, 'Toggle Propeller Effects', function() spSendCommands{'luaui togglewidget 1944 Propeller FX'} end )

local pathUnitVisiblity = 'Settings/Graphics/Unit Visibility'
	ShLabel(pathUnitVisiblity, 'Unit Visibility Options')
	AddOption(pathUnitVisiblity,
	{
		name = 'Draw Distance',
		type = 'number',
		min = 1,
		max = 10000,
		springsetting = 'UnitLodDist',
		OnChange = function(self) spSendCommands{"distdraw " .. self.value} end,
		advanced = true,
	} )
	AddOption(pathUnitVisiblity,
	{
		name = 'Shiny Units',
		type = 'bool',
		advanced = true,
		springsetting = 'AdvUnitShading',
		OnChange=function(self) spSendCommands{"advmodelshading " .. (self.value and 1 or 0) } end, --needed as setconfigint doesn't apply change right away
	} )

local pathSSAO = 'Settings/Graphics/Ambient Occlusion'
	ShButton(pathSSAO, 'Toggle SSAO', function() spSendCommands{"luaui togglewidget Screen-Space Ambient Occlusion"} end,
		"Toggle Screen Space Ambient Occlusion. It essentially adds a bit of shading to everything.")

local pathAudio = 'Settings/Audio'
	AddOption(pathAudio,{
		name = 'Master Volume',
		desc = 'Overall volume level, acts on top of the specific levels below.',
		type = 'number',
		min = 0,
		max = 100,
		springsetting = 'snd_volmaster',
		OnChange = function(self)
			if WG.crude and WG.crude.SetMasterVolume then
				WG.crude.SetMasterVolume(self.value)
			end
		end,
		simpleMode = true,
		everyMode = true,
	})
	AddOption(pathAudio,{
		name = 'Battle Volume',
		desc = 'Combat effects such as weapon fire and explosions.',
		type = 'number',
		min = 0,
		max = 100,
		springsetting = 'snd_volbattle',
		OnChange = function(self) spSendCommands{"set snd_volbattle " .. self.value} end,
		simpleMode = true,
		everyMode = true,
	})
	AddOption(pathAudio,{
		name = 'UI Volume',
		desc = 'Interface notifications such as chat. Also applies to unit replies.',
		type = 'number',
		min = 0,
		max = 100,
		springsetting = 'snd_volui',
		OnChange = function(self) spSendCommands{"set snd_volui " .. self.value} end,
		simpleMode = true,
		everyMode = true,
	})
	AddOption(pathAudio,{
		name = 'Ambient Volume',
		desc = 'Miscellaneous sounds such as the environment or a busy base.',
		type = 'number',
		min = 0,
		max = 100,
		springsetting = 'snd_volgeneral',
		OnChange = function(self) spSendCommands{"set snd_volgeneral " .. self.value} end,
		simpleMode = true,
		everyMode = true,
	})

--- HUD ETC ---
AddOption("Settings/HUD Panels/Pause Screen",
	{
		name = 'Menu pauses in SP',
		desc = 'Does opening the menu pause the game in single player?',
		type = 'bool',
		value = true,
		noHotkey = true,
	})
AddOption("Settings/HUD Panels/Pause Screen",
	{
		name = 'Menu unpauses in SP',
		desc = 'Does closing the menu unpause the game in single player?',
		type = 'bool',
		value = true,
		noHotkey = true,
	})

--- HELP ---
local pathHelp = 'Help'
	AddOption(pathHelp,
	{
		type='text',
		name='Space + Click Tips',
		value = [[Hold Space and click on a unit or wreck to display detailed information.
        You can also space-click on commands and other interface elements to open their hotkey settings. ]]
	})
	AddOption(pathHelp,
	{
		type='text',
		name='Command Panel',
		value = [[The command panel at the bottom left has a tab for orders and one for each build category. Hotkeys for every button are shown on the button and can be changed under Hotkeys, or by space-clicking the button.]]
	})
	AddOption(pathHelp,
	{
		type='text',
		name='Selection',
		value = [[Drag-selecting picks combat units first: engineers, supply trucks, buildings and unarmed transports are skipped when the box also holds combat units. Hold Ctrl while drag-selecting to include everything. See Settings/Interface/Selection Filtering.]]
	})

return confdata
