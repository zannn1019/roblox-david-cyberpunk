-- Connected Discord-GitHub
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local FADE_TIME = 0.4
local SPAWN_RATE = 0.05
local WALK_SPEED_THRESHOLD = 16

local ANIM_IDS = {
	Idle = "rbxassetid://119425019164994",
	Walk = "rbxassetid://125786444575345",
	Run  = "rbxassetid://122268304659965",
}

local GHOST_GRADIENT = {
	Color3.fromRGB(255, 220, 0),
	Color3.fromRGB(255, 140, 0),
	Color3.fromRGB(220, 50, 50),
	Color3.fromRGB(150, 50, 200),
	Color3.fromRGB(60, 80, 255)
}

-- Config
local Config = {
	WalkingSpeed    = 16,
	RunningSpeed    = 32,
	MaxStamina      = 100,
	DashCooldownTime = 5,
	DashVelocity    = 75,
	NormalFOV       = 70,
	WarpFOV         = 200,
	EffectCooldown  = 10
}

-- Skillset
local Skillset = {
	Sandevistan = {
		Name     = "Sandevistan",
		Cooldown = Config.EffectCooldown,
		Keybind  = Enum.KeyCode.R
	},
}

-- State
local State = {
	isSprinting      = false,
	isDashOnCooldown = false,
	isEffectOnCooldown = false,
	isEffectActive = false,
	currentStamina   = Config.MaxStamina,
	playerClones     = {},
}

-- References
local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera
local playerGui = player.PlayerGui:WaitForChild("Gui")

local sandyColorGrading = Lighting:FindFirstChild("SandevistanColor") or Instance.new("ColorCorrectionEffect")
sandyColorGrading.Name = "SandevistanColor"
sandyColorGrading.Enabled = false
sandyColorGrading.Parent = Lighting

------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------

local function getCharacterComponents(character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	return humanoid, rootPart
end

------------------------------------------------------------------------
-- Speed
------------------------------------------------------------------------

local function setSpeed(character, speed)
	if not character then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = speed
	end
end


------------------------------------------------------------------------
-- Stamina Bar
------------------------------------------------------------------------

local staminaFill = nil 

local function createStaminaBar(character)
	local rootPart = character:WaitForChild("HumanoidRootPart")

	local existing = rootPart:FindFirstChild("StaminaBarGui")
	if existing then existing:Destroy() end
	local billboard = Instance.new("BillboardGui")
	billboard.Name          = "StaminaBarGui"
	billboard.Size          = UDim2.new(0, 10, 0, 200)
	billboard.StudsOffset   = Vector3.new(3, 0, 0)
	billboard.ResetOnSpawn  = false
	billboard.Parent        = rootPart

	local background = Instance.new("Frame")
	background.Name            = "Background"
	background.Size            = UDim2.new(1, 0, 1, 0)
	background.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	background.BorderSizePixel = 0
	background.Parent          = billboard

	local fill = Instance.new("Frame")
	fill.Name              = "Fill"
	fill.AnchorPoint       = Vector2.new(0, 1)
	fill.Position          = UDim2.new(0, 0, 1, 0)
	fill.Size              = UDim2.new(1, 0, 1, 0)
	fill.BackgroundColor3  = Color3.fromRGB(0, 132, 255)
	fill.BorderSizePixel   = 0
	fill.Parent            = background

	staminaFill = fill
end

local function updateCooldownTime(skillSet)
    local SkillGui = playerGui:FindFirstChild("SkillGui")
    if not SkillGui then return end
    local SkillCooldown = SkillGui.Text:WaitForChild("SkillCooldown")
    local SkillName = SkillGui.Text:WaitForChild("SkillName")
    local SkillKeybind = SkillGui.Text:WaitForChild("SkillKeybind")
    local CooldownSlider = SkillGui:WaitForChild("Filler")

    local cooldownDuration = skillSet.Sandevistan.Cooldown
    SkillName.Text = skillSet.Sandevistan.Name
    SkillCooldown.Text = string.format("%.1f", cooldownDuration)
    SkillKeybind.Text = skillSet.Sandevistan.Keybind.Name

    local endTime = os.clock() + cooldownDuration

	task.spawn(function()
		while os.clock() < endTime do
			local remainingTime = math.max(0, endTime - os.clock())
			local fillSize = UDim2.new(remainingTime / cooldownDuration, 0, 1, 0)
			CooldownSlider.Size = fillSize
			SkillCooldown.Text = string.format("%.1f", remainingTime)
			task.wait(0.1)
		end

		CooldownSlider.Size = UDim2.new(0, 0, 1, 0)
		SkillCooldown.Text = string.format("%.1f", cooldownDuration)
	end)
end

local function updateStaminaBar(current, max)
	if not staminaFill or not staminaFill.Parent then return end

	local percent = math.clamp(current / max, 0, 1)

	TweenService:Create(
		staminaFill,
		TweenInfo.new(0.1, Enum.EasingStyle.Linear),
		{ Size = UDim2.new(1, 0, percent, 0) }
	):Play()

	local color
	if percent > 0.6 then
		color = Color3.fromRGB(30, 180, 30)
	elseif percent > 0.3 then
		color = Color3.fromRGB(220, 180, 0)  
	else
		color = Color3.fromRGB(200, 30, 30)    
	end

	staminaFill.BackgroundColor3 = color
end

------------------------------------------------------------------------
-- Shockwave
------------------------------------------------------------------------

local function spawnSonicShockwave(character)
	local _, rootPart = getCharacterComponents(character)
	if not rootPart then return end

	local ring = Instance.new("Part")
	ring.Shape      = Enum.PartType.Cylinder
	ring.Anchored   = true
	ring.CanCollide = false
	ring.CanQuery   = false
	ring.CastShadow = false
	ring.Material   = Enum.Material.Neon
	ring.Color      = Color3.fromRGB(255, 255, 255)
	ring.Size       = Vector3.new(0.2, 3, 3)
	ring.CFrame     = rootPart.CFrame * CFrame.new(0, -2.5, 0) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent     = Workspace

	TweenService:Create(
		ring,
		TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.new(0.1, 35, 35), Transparency = 1 }
	):Play()

	Debris:AddItem(ring, 0.25)
end


------------------------------------------------------------------------
-- Animations
------------------------------------------------------------------------

local function applyCustomAnimations(character)
	local animateScript = character:WaitForChild("Animate", 5)
	if not animateScript then return end

	local humanoid = character:WaitForChild("Humanoid")

	local idleValue = animateScript:FindFirstChild("idle")
	if idleValue then
		idleValue:WaitForChild("Animation1").AnimationId = ANIM_IDS.Idle
		idleValue:WaitForChild("Animation2").AnimationId = ANIM_IDS.Idle
	end

	local walkValue = animateScript:FindFirstChild("walk")
	local runValue  = animateScript:FindFirstChild("run")

	local function updateAnims()
		local isWalking = humanoid.WalkSpeed <= WALK_SPEED_THRESHOLD
		local animId = isWalking and ANIM_IDS.Walk or ANIM_IDS.Run

		if walkValue then
			walkValue:WaitForChild("WalkAnim").AnimationId = animId
		end
		if runValue then
			runValue:WaitForChild("RunAnim").AnimationId = animId
		end

		-- Force Animate script to reload
		animateScript.Disabled = true
		task.wait()
		animateScript.Disabled = false
	end

	updateAnims()
	humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(updateAnims)
end

------------------------------------------------------------------------
-- Screen Effects
------------------------------------------------------------------------

local function applyScreenShake(character, duration, intensity)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local startTime = os.clock()
	local connection

	connection = RunService.RenderStepped:Connect(function()
		local elapsed = os.clock() - startTime

		if elapsed >= duration then
			humanoid.CameraOffset = Vector3.zero
			connection:Disconnect()
			return
		end

		local fade = 1 - (elapsed / duration)
		humanoid.CameraOffset = Vector3.new(
			(math.random() - 0.5) * 2 * intensity * fade,
			(math.random() - 0.5) * 2 * intensity * fade,
			(math.random() - 0.5) * 2 * intensity * fade
		)
	end)
end

local function applyScreenSandevistan(duration)
	sandyColorGrading.Contrast  = 0.45
	sandyColorGrading.Saturation = -0.2
	sandyColorGrading.TintColor  = Color3.fromRGB(210, 255, 215)
	sandyColorGrading.Enabled    = true

	local warpInfo = TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(camera, warpInfo, { FieldOfView = Config.WarpFOV }):Play()

	task.delay(duration, function()
		local recoveryInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

		TweenService:Create(camera, recoveryInfo, { FieldOfView = Config.NormalFOV }):Play()
		TweenService:Create(sandyColorGrading, recoveryInfo, {
			Contrast  = 0,
			Saturation = 0,
			TintColor  = Color3.fromRGB(255, 255, 255),
		}):Play()

		task.wait(0.3)
		sandyColorGrading.Enabled = false
	end)
end

------------------------------------------------------------------------
-- Ghost Trail
------------------------------------------------------------------------

local function createGhost(character, ghostColor)
	character.Archivable = true
	local clone = character:Clone()
	character.Archivable = false

	if not clone then return end

	for _, descendant in ipairs(clone:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored     = true
			descendant.CanCollide   = false
			descendant.CastShadow   = false
			descendant.Material     = Enum.Material.Neon
			descendant.Color        = ghostColor
			descendant.Transparency = 0.6

			if descendant:IsA("MeshPart") then
				descendant.TextureID = ""
			end
		elseif
			descendant:IsA("LuaSourceContainer") or
			descendant:IsA("Humanoid") or
			descendant:IsA("Sound") or
			descendant:IsA("Decal") or
			descendant:IsA("Clothing")
		then
			descendant:Destroy()
		elseif not descendant:IsA("SpecialMesh") and not descendant:IsA("Model") then
			descendant:Destroy()
		end
	end

	clone.Parent = Workspace
	table.insert(State.playerClones, clone)
end

local function clearGhostTrail()
	for _, clone in ipairs(State.playerClones) do
		if clone and clone.Parent then
			for _, part in ipairs(clone:GetDescendants()) do
				if part:IsA("BasePart") then
					local tween = TweenService:Create(
						part,
						TweenInfo.new(FADE_TIME, Enum.EasingStyle.Linear),
						{ Transparency = 1 }
					)
					tween:Play()
				end
			end
			Debris:AddItem(clone, FADE_TIME)
		end
	end

	State.playerClones = {}
	setSpeed(player.Character, Config.WalkingSpeed)
end

local function getGradientColor(t)
	local scaledT = t * (#GHOST_GRADIENT - 1)
	local index = math.floor(scaledT) + 1
	local alpha = scaledT - math.floor(scaledT)

	local colorA = GHOST_GRADIENT[math.clamp(index, 1, #GHOST_GRADIENT)]
	local colorB = GHOST_GRADIENT[math.clamp(index + 1, 1, #GHOST_GRADIENT)]

	return colorA:Lerp(colorB, alpha)
end

local function startGhostTrail(duration)
	local character = player.Character
	if not character then return end

	local startTime = os.clock()

	spawnSonicShockwave(character)
	applyScreenSandevistan(duration)
	applyScreenShake(character, 0.4, 1.8)

	task.spawn(function()
		while os.clock() - startTime < duration do
			local elapsed = os.clock() - startTime
			local t = 1 - (elapsed / duration)

			local color = getGradientColor(t)
			createGhost(character, color)
			task.wait(SPAWN_RATE)
		end
		State.isEffectActive = false
		clearGhostTrail()
	end)
end

------------------------------------------------------------------------
-- Dash
------------------------------------------------------------------------

local function dash(humanoid, rootPart)
	startGhostTrail(0.2)

	local moveDir = humanoid.MoveDirection
	local dashDir = moveDir.Magnitude > 0
		and Vector3.new(moveDir.X, 0, moveDir.Z).Unit
		or  Vector3.new(rootPart.CFrame.LookVector.X, 0, rootPart.CFrame.LookVector.Z).Unit

	local attachment = Instance.new("Attachment")
	attachment.Parent = rootPart

	local linearVelocity = Instance.new("LinearVelocity")
	linearVelocity.Attachment0    = attachment
	linearVelocity.MaxForce       = 500000
	linearVelocity.VectorVelocity = dashDir * Config.DashVelocity
	linearVelocity.RelativeTo     = Enum.ActuatorRelativeTo.World
	linearVelocity.Parent         = rootPart

	applyScreenShake(humanoid.Parent,1, 1)
	Debris:AddItem(linearVelocity, 0.2)
	Debris:AddItem(attachment, 0.2)
end

------------------------------------------------------------------------
-- Input
------------------------------------------------------------------------

local function handleInputBegan(input, gameProcessed)
	if gameProcessed then return end

	if input.KeyCode == Enum.KeyCode.LeftShift then
		State.isSprinting = true
		if State.currentStamina > 0 then
			setSpeed(player.Character, Config.RunningSpeed)
			return
		end

	elseif input.KeyCode == Enum.KeyCode.Q then
		if State.isDashOnCooldown then return end

		local character = player.Character
		local humanoid, rootPart = getCharacterComponents(character)
		if not humanoid or not rootPart then return end

		State.isDashOnCooldown = true
		task.delay(Config.DashCooldownTime, function()
			State.isDashOnCooldown = false
		end)
		dash(humanoid, rootPart)

	elseif input.KeyCode == Enum.KeyCode.R then
		if State.isEffectOnCooldown then return end
		if State.isEffectActive then return end
		State.isEffectOnCooldown = true
		State.isEffectActive = true
		startGhostTrail(6)
		updateCooldownTime(Skillset)
		task.delay(Config.EffectCooldown, function()
			State.isEffectOnCooldown = false
		end)
	end
end

local function handleInputEnded(input, gameProcessed)
	if gameProcessed then return end

	if input.KeyCode == Enum.KeyCode.LeftShift then
		State.isSprinting = false
		setSpeed(player.Character, Config.WalkingSpeed)
	end
end

------------------------------------------------------------------------
-- Module
------------------------------------------------------------------------

local MovementModule = {}

function MovementModule:Init()
	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid")
		humanoid.WalkSpeed = Config.WalkingSpeed
		createStaminaBar(character)
		task.wait(0.1)
		applyCustomAnimations(character)
	end)

	if player.Character then
		createStaminaBar(player.Character)
		setSpeed(player.Character, Config.WalkingSpeed)
		applyCustomAnimations(player.Character)
	end

	UserInputService.InputBegan:Connect(handleInputBegan)
	UserInputService.InputEnded:Connect(handleInputEnded)
end

local lastVisualStamina = -1

RunService.Heartbeat:Connect(function(deltaTime)
	local character = player.Character
	if not character then return end

	if State.isSprinting then
		State.currentStamina = math.clamp(
			State.currentStamina - (20 * deltaTime),
			0,
			Config.MaxStamina
		)

		if State.currentStamina <= 0 then
			State.isSprinting = false
			setSpeed(character, Config.WalkingSpeed)
		end
	else
		if State.currentStamina < Config.MaxStamina then
			State.currentStamina = math.clamp(
				State.currentStamina + (20 * deltaTime),
				0,
				Config.MaxStamina
			)
		end
	end

	if State.currentStamina ~= lastVisualStamina then
		updateStaminaBar(State.currentStamina, Config.MaxStamina)
		lastVisualStamina = State.currentStamina 
	end
end)

return MovementModule