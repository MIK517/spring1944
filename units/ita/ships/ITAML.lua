local ITA_ML = InfantryLandingCraft:New{
	name					= "Moto Lance",
	acceleration			= 0.1,
	brakeRate				= 0.5,
	buildCostMetal			= 800,
	maxDamage				= 1550,
	maxReverseVelocity		= 0.685,
	maxVelocity				= 2.2,
	transportCapacity		= 22,
	transportMass			= 1300,
	turnRate				= 55,	
	script					= "LandingCraft.lua",
	weapons = {	
		[1] = {
			name				= "BredaM1931AA",
			onlyTargetCategory	= "AIR",
			mainDir				= [[0 0 1]],
			maxAngleDif			= 150,
		},
		[2] = {
			name				= "BredaM1931",
			mainDir				= [[0 0 1]],
			maxAngleDif			= 150,
		}
	},
	customparams = {
		armour = {
			base = {
				front = {
					thickness		= 6,
				},
				rear = {
					thickness		= 6,
				},
				side = {
					thickness 		= 6,
				},
				top = {
					thickness		= 0,
				},
			},
		},
		deathanim = {
			["z"] = {angle = -30, speed = 10},
		},

		normaltex			= "unittextures/ITAML_normals.png",
		turretturnspeed		= 60,
		elevationspeed		= 60,
		landingcraft = {
			loader			= "arm",
			ramp			= {piece = "ladder", angle = 30, speed = 60, slide = 6.8, slidespeed = 6},
			hideinfantry	= true,
			carry			= "base",
			pickuparm		= true,
			weapons = {
				[1] = {aim = "turret", pitch = "gun", flare = "flare", aa = true,
					ceg = "SMALL_MUZZLEFLASH", dust = "SMALL_MUZZLEDUST"},
				[2] = {aim = "turret", pitch = "gun", flare = "flare",
					ceg = "SMALL_MUZZLEFLASH", dust = "SMALL_MUZZLEDUST"},
			},
		},
	},
}


return lowerkeys({
	["ITAML"] = ITA_ML,
})
