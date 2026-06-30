local KatanaConfig = {
	BaseConfiguration = {
		Damage = 10,
		IdleAnimation = "rbxassetid://106883289765011",
		AttackAnimations = {
			"rbxassetid://130399600779051",
			"rbxassetid://90388456395861",
			"rbxassetid://140021509408002"
		},
		SwingCooldown = 0.2
	},
	SkillConfiguration = {
		Skill1 = {
			SkillName = "UpfrontSlash",
			SkillType = "Dash",
			SkillDamage = 15,
			SkillCooldown = 10,
			Animation = "rbxassetid://140021509408002"
		}
	}
}

return KatanaConfig 