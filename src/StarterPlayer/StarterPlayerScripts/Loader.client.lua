local ContentProvider = game:GetService("ContentProvider")
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local humanoid = char:WaitForChild("Humanoid", 10) or char:FindFirstChildOfClass("Humanoid")

local allAnims = {}
local seenIds = {}

local function addAnimArray(arr)
	for _, anim in ipairs(arr) do
		if anim:IsA("Animation") and anim.AnimationId ~= "" then
			if not seenIds[anim.AnimationId] then
				seenIds[anim.AnimationId] = true
				table.insert(allAnims, anim)
			end
		end
	end
end

-- 1. Legacy: char descendants (model-embedded anims)
addAnimArray(char:GetDescendants())

-- 2. Movement anims from RS.Animations (weapon-agnostic + weapon-specific movement)
local okAnims, animsRoot = pcall(function() return RS:WaitForChild("Animations", 5) end)
if okAnims and animsRoot then
	local weaponsFolder = animsRoot:FindFirstChild("Weapons")
	if weaponsFolder then
		-- Collect movement-relevant anims: anything under Movement, Dodging, or Sprint-named
		for _, desc in ipairs(weaponsFolder:GetDescendants()) do
			if desc:IsA("Animation") then
				local full = desc:GetFullName():lower()
				if full:find("movement") or full:find("dodging") or full:find("sprint") or full:find("walk") or full:find("crouch") or full:find("slide") or full:find("wallrun") or full:find("wallclimb") or full:find("vault") or full:find("ledgegrab") then
					if not seenIds[desc.AnimationId] then
						seenIds[desc.AnimationId] = true
						table.insert(allAnims, desc)
					end
				end
			end
		end
	end
	-- Also check generic movement anims stored outside Weapons if any
	for _, desc in ipairs(animsRoot:GetDescendants()) do
		if desc:IsA("Animation") then
			local full = desc:GetFullName():lower()
			if full:find("movement") and not seenIds[desc.AnimationId] then
				seenIds[desc.AnimationId] = true
				table.insert(allAnims, desc)
			end
		end
	end
end

-- 3. Replicated Movement Objects folder (Movement.init Anims)
local okMoveAnims, moveAnimsFolder = pcall(function()
	return RS.Modules.Movement.Objects.Movement:FindFirstChild("Animations")
end)
if okMoveAnims and moveAnimsFolder then
	for _, desc in ipairs(moveAnimsFolder:GetDescendants()) do
		if desc:IsA("Animation") and not seenIds[desc.AnimationId] then
			seenIds[desc.AnimationId] = true
			table.insert(allAnims, desc)
		end
	end
end

-- Warmup animator
local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
if not animator and humanoid then
	animator = Instance.new("Animator")
	animator.Parent = humanoid
end

if animator then
	for _, anim in ipairs(allAnims) do
		local success, track = pcall(function()
			return animator:LoadAnimation(anim)
		end)
		if success and track then
			track:Stop(0)
			track:Destroy()
		end
	end
end

-- ContentProvider preload (best-effort, no yield on failure)
if #allAnims > 0 then
	pcall(function() ContentProvider:PreloadAsync(allAnims) end)
end

-- Re-warmup on respawn (movement owner re-created per character)
player.CharacterAdded:Connect(function(newChar)
	local hum = newChar:WaitForChild("Humanoid", 10)
	if not hum then return end
	task.wait(0.2)
	local newAnimator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
	for _, anim in ipairs(allAnims) do
		local s, t = pcall(function() return newAnimator:LoadAnimation(anim) end)
		if s and t then t:Stop(0); t:Destroy() end
	end
end)
