--[[ System By @Liam 
-> Version 1.3.3
 ♥ Thanks for using this!! ♥ 
--]] 



--||Services||--
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")

--||Ragdoll CFrames (can be changed)||--
local attachmentCFrames = {
	["Neck"] = {CFrame.new(0, 1, 0, 0, -1, 0, 1, 0, -0, 0, 0, 1), CFrame.new(0, -0.5, 0, 0, -1, 0, 1, 0, -0, 0, 0, 1)},
	["Left Shoulder"] = {CFrame.new(-1.3, 0.75, 0, -1, 0, 0, 0, -1, 0, 0, 0, 1), CFrame.new(0.2, 0.75, 0, -1, 0, 0, 0, -1, 0, 0, 0, 1)},
	["Right Shoulder"] = {CFrame.new(1.3, 0.75, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1), CFrame.new(-0.2, 0.75, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1)},
	["Left Hip"] = {CFrame.new(-0.5, -1, 0, 0, 1, -0, -1, 0, 0, 0, 0, 1), CFrame.new(0, 1, 0, 0, 1, -0, -1, 0, 0, 0, 0, 1)},
	["Right Hip"] = {CFrame.new(0.5, -1, 0, 0, 1, -0, -1, 0, 0, 0, 0, 1), CFrame.new(0, 1, 0, 0, 1, -0, -1, 0, 0, 0, 0, 1)},
}

--||Don't change this||--
local ragdollInstanceNames = {
	["RagdollAttachment"] = true,
	["RagdollConstraint"] = true,
	["ColliderPart"] = true,
}

--||Settings||--
local RagdollSounds = false --disabled; re-enable to get body-impact sounds. ImpactSound.server.lua stays alive for that.
local fixNpcFling = true --fixes the npc flinging away when they get up
local fixVoidBug = true --fixes the bug that the player doesnt respawn when he falls into the void (may causes error)

------------------------------------------------------------------------------------------------------------------





--//
local function PlayRagdollSounds(char) --playing a sound when those body parts hit something
	if RagdollSounds then
		local impactH = script.ImpactSound:Clone()
		impactH.Parent = char:WaitForChild("Head")
		impactH.Disabled = false
		local impactLA = script.ImpactSound:Clone()
		impactLA.Parent = char:WaitForChild("Left Arm")
		impactLA.Disabled = false
		local impactRA = script.ImpactSound:Clone()
		impactRA.Parent = char:WaitForChild("Right Arm")
		impactRA.Disabled = false
	end			
end

--//
local function createColliderPart(part) --creating the parts that are gonna be colliding with the world
	if not part then return end
	local rp = Instance.new("Part")
	rp.Name = "ColliderPart"
	rp.Size = part.Size / 1.7
	rp.Massless = true
	rp.CFrame = part.CFrame
	rp.Transparency = 1

	local wc = Instance.new("WeldConstraint")
	wc.Part0 = rp
	wc.Part1 = part
	wc.Parent = rp
	rp.Parent = part
end

--//
local function replaceJoints(char, hum) --replacing the joints and other stuff
	hum.PlatformStand = true
	hum.AutoRotate = false
	if not char:FindFirstChild("HumanoidRootPart") then return end
	char.HumanoidRootPart.Massless = true
	char.HumanoidRootPart.CanCollide = false

	PlayRagdollSounds(char)

	for _, motor in char:GetDescendants() do
		if motor:IsA("Motor6D") and attachmentCFrames[motor.Name] then
			motor.Enabled = false
			
			local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
			a0.CFrame = attachmentCFrames[motor.Name][1]
			a1.CFrame = attachmentCFrames[motor.Name][2]

			a0.Name = "RagdollAttachment"
			a1.Name = "RagdollAttachment"

			createColliderPart(motor.Part1)

			local b = Instance.new("BallSocketConstraint")
			b.Attachment0 = a0
			b.Attachment1 = a1
			b.Name = "RagdollConstraint"

			b.Radius = 0.15
			b.LimitsEnabled = true
			b.TwistLimitsEnabled = motor.Name == "Neck"
			b.MaxFrictionTorque = 0
			b.Restitution = 0
			b.UpperAngle = motor.Name == "Neck" and 45 or 90
			b.TwistLowerAngle = motor.Name == "Neck" and -70 or -45
			b.TwistUpperAngle = motor.Name == "Neck" and 70 or 45

			a0.Parent = motor.Part0
			a1.Parent = motor.Part1
			b.Parent = motor.Parent
		end
	end
end

--//
local function resetJoints(hum) --resetting the joints and all the other properties
	local char = hum.Parent
	local hrp = char.HumanoidRootPart

	char:SetAttribute("IsRagdoll", false)
	hum.PlatformStand = false
	hum.AutoRotate = true
	char.HumanoidRootPart.Massless = false
	char.HumanoidRootPart.CanCollide = true 
	
	if RagdollSounds then
		for i,v in char:GetDescendants() do
			if v:IsA("Script") and v.Name == "ImpactSound" and v.Enabled == true then
				v:Destroy()
			end
		end
	end	

	if hum.Health <= 0 then return end --we don't want the player to stand up again if he is dead	

	for _, instance in char:GetDescendants() do
		if ragdollInstanceNames[instance.Name] then
			instance:Destroy()
		end
		if instance:IsA("Motor6D") then
			instance.Enabled = true
		end
	end

	hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
	hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
	hum:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)

	local isPlayer = Players:GetPlayerFromCharacter(hum.Parent)
	if not isPlayer and fixNpcFling then --the body position and body gyro thing was something I found on the devforum so not my idea
		local FloatThing = Instance.new("BodyPosition") do
			FloatThing.Position = hrp.Position + Vector3.new(0, 2, 0)
			FloatThing.Parent = hrp
			game.Debris:AddItem(FloatThing, 0.25)
		end

		local Stabilizer = Instance.new("BodyGyro") do
			Stabilizer.P = 1000000
			Stabilizer.D = 500
			Stabilizer.MaxTorque = Vector3.new(10000, 0, 10000)
			Stabilizer.Parent = hrp
			game.Debris:AddItem(Stabilizer, .25)
		end
	end

end


--//
local function applyRagdollToCharacter(char) --applying the ragdoll
	local hum = char:FindFirstChild("Humanoid")
	if hum then
		local torso = char:FindFirstChild("Torso")
		if torso then
			hum.BreakJointsOnDeath = false
			hum.RequiresNeck = false
			
			char:SetAttribute("IsRagdoll", false) --setting ragdoll to false from the beginning on

			char:GetAttributeChangedSignal("IsRagdoll"):Connect(function()
				if char:GetAttribute("IsRagdoll") then
					replaceJoints(char, hum)
					-- Ragdoll gate: force-cancel any active wallrun movers (both PLR and NPC)
					pcall(function()
						local Movement = require(RS.Modules.Movement.Objects.Movement)
						local mov = nil
						local plr = Players:GetPlayerFromCharacter(char)
						if plr then
							mov = Movement.GetMovementObj(plr)
						else
							-- NPC path: identifier is npc object table
							local ok, npcMod = pcall(require, SS.Modules.Objects.npc)
							if ok and npcMod and npcMod.GetNpcFromCharacter then
								local npcObj = npcMod.GetNpcFromCharacter(char)
								if npcObj then
									mov = Movement.GetMovementObj(npcObj)
								end
							end
						end
						if mov then
							mov:CancelConflictingActions("Ragdoll")
							mov:CleanupOrphanPhysics()
						else
							-- Fallback: direct HRP sweep if no MovementObj found (e.g. race)
							local hrp = char:FindFirstChild("HumanoidRootPart")
							if hrp then
								for _, inst in ipairs(hrp:GetChildren()) do
									if inst.Name == "WallRunAttachment" or inst:IsA("LinearVelocity") or inst:IsA("AlignOrientation") then
										pcall(function() inst:Destroy() end)
									end
								end
							end
						end
					end)
				else
					resetJoints(hum)
				end
			end)

			hum.Died:Once(function()
				char:SetAttribute("IsRagdoll", true)
				char:SetAttribute("Stunned", true)
				torso:ApplyImpulse(torso.CFrame.LookVector * 100)
			end)
		end
	end
end


--//
local function applyRagdollToCharacters()
	for _, char in workspace:GetDescendants() do
		applyRagdollToCharacter(char)
	end
end

--if you have an npc folder in workspace you can do something like this
--[[

workspace.Map.ChildAdded:Connect(function(child)
	if child:IsA("Model") and child:FindFirstChild("Humanoid") then
		applyRagdollToCharacter(child)
	end
end)

]]


--//
applyRagdollToCharacters()

Players.PlayerAdded:Connect(function(plr)
	plr.CharacterAdded:Connect(function(char)
		applyRagdollToCharacter(char)
		
		if fixVoidBug then
			char.ChildRemoved:Connect(function() --this fixes the void bug
				if char.WorldPivot.Position.Y <= workspace.FallenPartsDestroyHeight then
					--print("void")			
					char.Humanoid.Health = 0 --so that the player just dies normaly when they fall into the void
				end
			end)
		end
		
	end)
end)


