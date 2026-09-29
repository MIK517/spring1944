function widget:GetInfo()
    return {
        name = "Post-processing API",
        desc = "Post-processing effects data storage (DO NOT DISABLE)",
        author = "Jose Luis Cercos-Pita",
        date = "24-3-2018",
        license = "GPLv2",
        layer = -math.huge,
        enabled = true,
        handler = true,
        api = true,
        alwaysStart = true,
    }
end

WG.POSTPROC = {
    tonemapping = {
        texture = nil,
        shader = nil,
        gamma = 0.75,
        dGamma = 0.0,
        gammaLoc = nil,
    },
    grayscale = {
        texture = nil,
        shader = nil,
        enabled = false,
        sepia = 0.5,
        sepiaLoc = nil,
    },
    filmgrain = {
        texture = nil,
        shader = nil,
        grain = 0.02,
        widthLoc = nil,
        heightLoc = nil,
        timerLoc = nil,
        widthLoc = nil,
        grainLoc = nil,
    },
    scratches = {
        texture = nil,
        shader = nil,
        threshold = 0.0,
        thresholdLoc = nil,
        randomLoc = nil,
        timerLoc = nil,
    },
    vignette = {
        texture = nil,
        shader = nil,
        vignette = {0.3, 1.0},
        vignetteLoc = nil,
    },
    aberration = {
        texture = nil,
        shader = nil,
        aberration = 0.1,
        widthLoc = nil,
        heightLoc = nil,
        aberrationLoc = nil,
    },
}

--------------------------------------------------------------------------------
-- Settings > Graphics > Post-processing

local function SetEffect(effect, field, index)
	return function(self)
		if index then
			WG.POSTPROC[effect][field][index] = self.value
		else
			WG.POSTPROC[effect][field] = self.value
		end
	end
end

options_path = 'Settings/Graphics/Post-processing'
options_order = {'toggle', 'lbl_tone', 'gamma', 'dgamma', 'lbl_film', 'grain', 'scratches', 'vignette', 'aberration', 'lbl_colour', 'grayscale', 'sepia'}
options = {
	toggle = {
		name = 'Toggle Post-processing',
		desc = 'Turns the post-processing effects below on or off.',
		type = 'button',
		OnChange = function() Spring.SendCommands("luaui togglewidget Post-processing") end,
	},
	lbl_tone = {name = 'Tone', type = 'label'},
	gamma = {
		name = 'Gamma',
		type = 'number', min = 0.5, max = 1.0, step = 0.01, value = 0.75,
		OnChange = SetEffect("tonemapping", "gamma"),
	},
	dgamma = {
		name = 'Gamma Fluctuation',
		desc = 'Old film style flicker of the brightness.',
		type = 'number', min = 0.0, max = 1.0, step = 0.02, value = 0.0,
		OnChange = SetEffect("tonemapping", "dGamma"),
	},
	lbl_film = {name = 'Film', type = 'label'},
	grain = {
		name = 'Film Grain',
		type = 'number', min = 0.0, max = 0.1, step = 0.002, value = 0.02,
		OnChange = SetEffect("filmgrain", "grain"),
	},
	scratches = {
		name = 'Scratches',
		type = 'number', min = 0.0, max = 1.0, step = 0.02, value = 0.0,
		OnChange = SetEffect("scratches", "threshold"),
	},
	vignette = {
		name = 'Vignette',
		desc = 'Lower values darken the screen edges more.',
		type = 'number', min = 0.7, max = 2.0, step = 0.02, value = 1.0,
		OnChange = SetEffect("vignette", "vignette", 2),
	},
	aberration = {
		name = 'Colour Aberration',
		type = 'number', min = 0.0, max = 0.5, step = 0.01, value = 0.1,
		OnChange = SetEffect("aberration", "aberration"),
	},
	lbl_colour = {name = 'Colour', type = 'label'},
	grayscale = {
		name = 'Gray / Sepia Colour',
		type = 'bool', value = false,
		OnChange = SetEffect("grayscale", "enabled"),
	},
	sepia = {
		name = 'Sepia Tone',
		type = 'number', min = 0.0, max = 1.0, step = 0.02, value = 0.5,
		OnChange = SetEffect("grayscale", "sepia"),
	},
}

function widget:Initialize()
	-- The menu only calls OnChange for values that differ from the default,
	-- so apply every value once here.
	for key, option in pairs(options) do
		if option.type == 'number' or option.type == 'bool' then
			option.OnChange(option)
		end
	end
end

function widget:Shutdown()
end
