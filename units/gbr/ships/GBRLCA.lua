local GBR_LCA = InfantryLandingCraft:New{
	name					= "Landing Craft, Assault",
	acceleration			= 0.009,
	brakeRate				= 0.5,
	buildCostMetal			= 500,
	maxDamage				= 914,
	maxReverseVelocity		= 0.685,
	maxVelocity				= 2,
	turnRate				= 40,	
	script					= "LandingCraft.lua",
	weapons = {	
		[1] = {
			name				= "bren",
			maxAngleDif			= 90,
		},
	},
	customparams = {
		armour = {
			base = {
				front = {
					thickness		= 29,-- 3/8in for doors, + 3/4in? ramp
				},
				rear = {
					thickness		= 19,
				},
				side = {
					thickness 		= 19,
				},
				top = {
					thickness		= 0, -- troop wells are 6mm armour but centreline is open
				},
			},
		},
		deathanim = {
			["z"] = {angle = -30, speed = 10},
		},

		normaltex			= "unittextures/GBRLCA_normals.png",
		turretturnspeed		= 45,
		elevationspeed		= 45,
		landingcraft = {
			loader		= "crane",
			ramp		= {piece = "ramp", angle = 90, speed = 30, closedelay = 1500},
			loadtime	= 50,
			unloadtime	= 50,
			weapons = {
				[1] = {aim = "bren_mount", pitch = "bren_gun", flare = "bren_flare", ceg = "MG_MUZZLEFLASH"},
			},
		},
	},
}


return lowerkeys({
	["GBRLCA"] = GBR_LCA,
})
