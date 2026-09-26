local JPN_TokuDaihatsu = TankLandingCraft:New{
	name					= "Toku Daihatsu Landing Craft",
	acceleration			= 0.09,
	brakeRate				= 0.5,
	buildCostMetal			= 1000,
	collisionVolumeOffsets	= [[0.0 0.0 20.0]],
	collisionVolumeScales	= [[30.0 20.0 120.0]],
	maxDamage				= 3500,
	maxReverseVelocity		= 0.685,
	maxVelocity				= 1.1,
	transportMass			= 2100,
	  transportSize=9,
	turnRate				= 50,	
	script					= "LandingCraft.lua",
	weapons = {	
		[1] = {
			name				= "Type9625mmAA",
			maxAngleDif			= 300,
			mainDir				= [[0 0 -1]],
		},
		[2] = {
			name				= "Type9625mmHE",
			maxAngleDif			= 300,
			mainDir				= [[0 0 -1]],
		},
	},
	customparams = {
		supplyrange				= 350, -- overwrite
		deathanim = {
			["z"] = {angle = -30, speed = 10},
		},
		normaltex			= "unittextures/JPNTokuDaihatsu_normals.png",
		turretturnspeed		= 60,
		elevationspeed		= 60,
		landingcraft = {
			loader			= "arm",
			ramp			= {piece = "ramp", angle = 45, speed = 30},
			carry			= "cargo",
			weapons = {
				[1] = {aim = "turret", pitch = "sleeve", flare = "flare", barrel = "barrel", heading = 180, aa = true,
					recoil = 0.3, recoilspeed = 10, returnspeed = 5, recoiltime = 100,
					ceg = "SMALL_MUZZLEFLASH", dust = "SMALL_MUZZLEDUST"},
				[2] = {aim = "turret", pitch = "sleeve", flare = "flare", barrel = "barrel", heading = 180,
					recoil = 0.3, recoilspeed = 10, returnspeed = 5, recoiltime = 100,
					ceg = "SMALL_MUZZLEFLASH", dust = "SMALL_MUZZLEDUST"},
			},
		},
	},
}


return lowerkeys({
	["JPNTokuDaihatsu"] = JPN_TokuDaihatsu,
})
