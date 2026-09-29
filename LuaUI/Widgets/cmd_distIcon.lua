function widget:GetInfo()
	return {
		name = "1944 Icon Distance",
		desc = "Sets Icon Distance to a suitable level for Spring: 1944",
		author = "Craig Lawrence",
		date = "09-12-2008",
		license = "Public Domain",
		layer = 1,
		enabled = true
	}
end

-- The icon distance applies only while S:44 runs; the engine setting shared
-- with other games (e.g. Zero-K) is restored on exit.

local unitIconDist = 0

options_path = 'Settings/Graphics/Unit Visibility'
options_order = {'iconDistance'}
options = {
	iconDistance = {
		name = 'Icon Distance',
		desc = 'Zoom distance beyond which units are drawn as icons. Only affects Spring: 1944.',
		type = 'number',
		min = 1,
		max = 1000,
		step = 10,
		value = 250,
		OnChange = function(self)
			Spring.SendCommands("disticon " .. self.value)
		end,
	},
}

function widget:Initialize()
	unitIconDist = Spring.GetConfigInt('UnitIconDist')
	Spring.SendCommands("disticon " .. options.iconDistance.value)
end

function widget:Shutdown()
	Spring.SetConfigInt('UnitIconDist', unitIconDist)
end
