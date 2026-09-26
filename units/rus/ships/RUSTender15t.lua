local RUS_Tender15t = InfantryLandingCraft:New{
	name					= "15-ton Tender",
	acceleration			= 0.15,
	brakeRate				= 0.14,
	buildCostMetal			= 600,
	--collisionVolumeOffsets	= [[0.0 -30.0 0.0]],
	--collisionVolumeScales	= [[60.0 50.0 220.0]],
	maxDamage				= 1360,
	maxReverseVelocity		= 1.1,
	maxVelocity				= 2.2,
	turnRate				= 50,	
	script					= "LandingCraft.lua",
	weapons = {	
		[1] = {
			name				= "dshk",
			maxAngleDif			= 270,
		},
	},
	customparams = {
		killvoicecategory		= "RUS/Boat/RUS_BOAT_KILL",
		killvoicephasecount		= 3,
		deathanim = {
			["z"] = {angle = -30, speed = 10},
		},
		normaltex			= "unittextures/RUSTender15t_normals.png",
		turretturnspeed		= 30,
		elevationspeed		= 45,
		landingcraft = {
			loader		= "crane",
			loadtime	= 500,
			unloadtime	= 1000,
			weapons = {
				[1] = {aim = "mg_turret", pitch = "gun", flare = "flare", ceg = "MG_MUZZLEFLASH"},
			},
		},
	},
}


return lowerkeys({
	["RUSTender15t"] = RUS_Tender15t,
})
