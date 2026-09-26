local GER_SiebelFahre = Boat:New{
	name					= "Siebel Fahre",
	description				= "Infantry Ferry",
	acceleration			= 0.15,
	brakeRate				= 0.14,
	buildCostMetal			= 1200,
	iconType				= "pontoon",
	maxDamage				= 10000,
	maxReverseVelocity		= 0.325,
	maxVelocity				= 1.7,
	movementClass			= "BOAT_LandingCraft",
	transportCapacity		= 48,
	transportMass			= 4000,
	transportSize			= 2,
	turnRate				= 30,	
	script					= "LandingCraft.lua",
	weapons = {	
		[1] = {
			name				= "flak3820mmhe",
			maxAngleDif			= 320,
			mainDir				= [[1 0 0]],
		},
		[2] = {
			name				= "flak3820mmhe",
			maxAngleDif			= 320,
			mainDir				= [[-1 0 0]],
		},
		[3] = {
			name				= "flak3820mmhe",
			maxAngleDif			= 270,
			mainDir				= [[0 0 -1]],
		},
		[4] = {
			name				= "flak3820mmaa",
			maxAngleDif			= 320,
			mainDir				= [[1 0 0]],
		},
		[5] = {
			name				= "flak3820mmaa",
			maxAngleDif			= 320,
			mainDir				= [[-1 0 0]],
		},
		[6] = {
			name				= "flak3820mmaa",
			maxAngleDif			= 270,
			mainDir				= [[0 0 -1]],
		},
	},
	customparams = {
		supplyRange				= 400,
		deathanim = { -- list, then sink
			["x"] = {angle = 15, speed = 2.5},
			["z"] = {angle = -5, speed = 2.5},
		},
		normaltex			= "unittextures/GERSiebelFahre_normals.png",
		turretturnspeed		= 40,
		elevationspeed		= 45,
		landingcraft = {
			loader			= "crane",
			slots			= {"load1", "load2", "load3"},
			loadtime		= 500,
			unloadtime		= 1000,
			shatterseverity	= 0.99,
			-- 4-6 are the A.A. modes of the guns 1-3
			weapons = {
				[1] = {aim = "mount_20_1", pitch = "sleeve_20_1", flare = "flare_20_1", barrel = "barrel_20_1",
					recoil = 0.4, recoilspeed = 10, returnspeed = 1, recoiltime = 200,
					ceg = "XSMALL_MUZZLEFLASH", dust = "XSMALL_MUZZLEDUST"},
				[2] = {aim = "mount_20_2", pitch = "sleeve_20_2", flare = "flare_20_2", barrel = "barrel_20_2",
					recoil = 0.4, recoilspeed = 10, returnspeed = 1, recoiltime = 200,
					ceg = "XSMALL_MUZZLEFLASH", dust = "XSMALL_MUZZLEDUST"},
				[3] = {aim = "mount_20_3", pitch = "sleeve_20_3", flare = "flare_20_3", barrel = "barrel_20_3", heading = 180,
					recoil = 0.4, recoilspeed = 10, returnspeed = 1, recoiltime = 200,
					ceg = "XSMALL_MUZZLEFLASH", dust = "XSMALL_MUZZLEDUST"},
				[4] = {aim = "mount_20_1", pitch = "sleeve_20_1", flare = "flare_20_1", barrel = "barrel_20_1", aa = true,
					recoil = 0.4, recoilspeed = 10, returnspeed = 1, recoiltime = 200,
					ceg = "XSMALL_MUZZLEFLASH", dust = "XSMALL_MUZZLEDUST"},
				[5] = {aim = "mount_20_2", pitch = "sleeve_20_2", flare = "flare_20_2", barrel = "barrel_20_2", aa = true,
					recoil = 0.4, recoilspeed = 10, returnspeed = 1, recoiltime = 200,
					ceg = "XSMALL_MUZZLEFLASH", dust = "XSMALL_MUZZLEDUST"},
				[6] = {aim = "mount_20_3", pitch = "sleeve_20_3", flare = "flare_20_3", barrel = "barrel_20_3", heading = 180, aa = true,
					recoil = 0.4, recoilspeed = 10, returnspeed = 1, recoiltime = 200,
					ceg = "XSMALL_MUZZLEFLASH", dust = "XSMALL_MUZZLEDUST"},
			},
		},
	},
}


return lowerkeys({
	["GERSiebelFahre"] = GER_SiebelFahre,
})
