local JPN_Daihatsu = InfantryLandingCraft:New{
	name					= "Daihatsu Landing Craft",
	acceleration			= 0.09,
	brakeRate				= 0.5,
	buildCostMetal			= 300,
	maxDamage				= 950,
	maxReverseVelocity		= 0.685,
	maxVelocity				= 1.9,
	transportCapacity		= 40,
	transportMass			= 2000,
	turnRate				= 50,
	script					= "LandingCraft.lua",

	customparams = {
		deathanim = {
			["z"] = {angle = -30, speed = 10},
		},
		normaltex			= "unittextures/JPNDaihatsu_normals.png",
		landingcraft = {
			loader			= "arm",
			ramp			= {piece = "ramp", angle = 60, speed = 30},
			hideinfantry	= true,
			carry			= "base",
			pickuparm		= true,
		},
	},
}


return lowerkeys({
	["JPNDaihatsu"] = JPN_Daihatsu,
})
