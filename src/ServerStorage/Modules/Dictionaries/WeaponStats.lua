local module = {}

--> this might be turned into an object so i can also sscript their weapon arts
--> also it would allow me to add the different types (Resonator/ Elemental)  though this could aleady be done via thier respective element objs






local info = {
	["Fists"] = {
		Damage = 10,
		Scaling = 10,
		BlockDmg = 6.6,
		Knockback = 4,
		SwingReset = 0.14,
		SwingFade = 0.15,
		StunTime = 0.25, -- light
		BlockingWalkSpeed = 6,
		ChipDamage = 0,
		HitboxSize = Vector3.new(4, 5, 6),
		HitboxOffset = CFrame.new(0, 0, -2.3),
	},

	["Fractured_Kunai"] = {
		Damage = 8,
		Scaling = 10,
		BlockDmg = 6.6,
		Knockback = 5,
		SwingReset = 0.16,
		SwingFade = 0.15,
		StunTime = 0.25, -- light
		BlockingWalkSpeed = 6,
		ChipDamage = 5,
		HitboxSize = Vector3.new(6, 6, 6),
		HitboxOffset = CFrame.new(0, 0, -2.3),
	},

	["Katana"] = {
		Damage = 10,
		Scaling = 10,
		BlockDmg = 10,
		Knockback = 5,
		SwingReset = 0.225,
		SwingFade = 0.2,
		StunTime = 0.3, -- medium
		BlockingWalkSpeed = 6,
		ChipDamage = 0,
		HitboxSize = Vector3.new(6, 6, 6),
		HitboxOffset = CFrame.new(0, 0, -2.3),
	},

	["DrakeFang"] = {
		Damage = 18,
		Scaling = 10,
		BlockDmg = 12,
		Knockback = 5,
		SwingReset = 0.23,
		SwingFade = 0.2,
		StunTime = 0.3, 
		BlockingWalkSpeed = 6,
		ChipDamage = 0,
		HitboxSize = Vector3.new(6, 6, 6),
		HitboxOffset = CFrame.new(0, 0, -2.3),
	},

	["TwinSpears"] = {
		Damage = 18,
		Scaling = 9,
		BlockDmg = 12,
		Knockback = 5,
		SwingReset = 0.2,
		SwingFade = 0.2,
		StunTime = 0.3, -- medium
		BlockingWalkSpeed = 6,
		ChipDamage = 0,
		HitboxSize = Vector3.new(6, 5, 9),
		HitboxOffset = CFrame.new(0, 0, -2.3),
	},

	["ShootingStar"] = {
		Damage = 21,
		Scaling = 10,
		BlockDmg = 25,
		Knockback = 6,
		SwingReset = 0.28,
		SwingFade = 0.25,
		StunTime = 0.4, -- heavy
		BlockingWalkSpeed = 6,
		ChipDamage = 10,
		HitboxSize = Vector3.new(6, 6, 6),
		HitboxOffset = CFrame.new(0, 0, -2.3),
	},
}

export type WeaponData = typeof(info.Fists)

function module.getStats(weapon): WeaponData
	return info[weapon]
end




return module
