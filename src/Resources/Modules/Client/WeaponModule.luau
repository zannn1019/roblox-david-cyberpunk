local WeaponHandler = {}

local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RaycastHitbox = require(ReplicatedStorage.Resources.Modules.Helper:WaitForChild("RaycastHitboxV4"))

local function LoadAnimationFromId(animator, assetId, priority, looped) 
	local animInstance = Instance.new("Animation")
	animInstance.AnimationId = assetId

	local track = animator:LoadAnimation(animInstance)
	track.Priority = priority or Enum.AnimationPriority.Action
	track.Looped = looped or false

	return track
end

function WeaponHandler:Init(tool, config, damageRemote, abilityRemote)
	local player = game.Players.LocalPlayer
	local character = player.Character or player.CharacterAdded:Wait()
	local humanoid = character:WaitForChild("Humanoid")
	local animator = humanoid:WaitForChild("Animator")

	local handle = tool:WaitForChild("Handle")
	local hitboxPart = handle:WaitForChild("Hitbox")
	local meleeHitbox = RaycastHitbox.new(hitboxPart)

	local baseConfig = config.BaseConfiguration

	local idleAnim = LoadAnimationFromId(animator, baseConfig.IdleAnimation, Enum.AnimationPriority.Action, true)

	local attackAnims = {}
	for _, animId in ipairs(baseConfig.AttackAnimations) do
		table.insert(attackAnims, LoadAnimationFromId(animator, animId, Enum.AnimationPriority.Action, false))
	end

	local comboCounter = 1
	local isEquipped = false
	local isAttacking = false 
	local lastSwingTime = 0 

	local function performAttack()
		if isAttacking or not isEquipped then return end

		local timeSinceLastSwing = os.clock() - lastSwingTime
		if timeSinceLastSwing > (baseConfig.SwingCooldown + 0.2) then
			comboCounter = 1
		end

		isAttacking = true
		idleAnim:Stop()
		meleeHitbox:HitStart()

		local currentAttack = attackAnims[comboCounter]
		currentAttack:Play()

		task.wait(currentAttack.Length)
		currentAttack:Stop()

		comboCounter = comboCounter + 1
		if comboCounter > #attackAnims then 
			comboCounter = 1 
		end

		idleAnim:Play()
		task.wait(0.1) 

		lastSwingTime = os.clock()
		isAttacking = false
		meleeHitbox:HitStop()
	end

	tool.Equipped:Connect(function()
		isEquipped = true
		idleAnim:Play()
	end)

	tool.Unequipped:Connect(function()
		isEquipped = false
		isAttacking = false
		for _, anim in ipairs(attackAnims) do
			if anim.IsPlaying then anim:Stop() end
		end
		meleeHitbox:HitStop()
		comboCounter = 1
		idleAnim:Stop()
	end)

	meleeHitbox.OnHit:Connect(function(hit, hitHumanoid)
		if not hitHumanoid or hitHumanoid == humanoid then return end
		damageRemote:FireServer(hitHumanoid, config.BaseConfiguration.Damage) 
	end)

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed or not isEquipped then return end

		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			if os.clock() - lastSwingTime >= baseConfig.SwingCooldown then
				performAttack()
			end
		elseif input.KeyCode == Enum.KeyCode.E then
			abilityRemote:FireServer()
		end
	end)
end

return WeaponHandler