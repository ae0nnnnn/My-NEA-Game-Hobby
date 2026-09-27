--[[ System By @Liam 
-> Version 1.3.3
 ♥ Thanks for using this!! ♥ 
--]] 



--||Services||--
local UIS = game:GetService("UserInputService")

--||Character||--
local char = script.Parent
local hum = char:WaitForChild("Humanoid")
local torso = nil
local capturedBehavior = nil

if char:FindFirstChild("Torso") then
	torso = char:FindFirstChild("Torso") 
elseif char:FindFirstChild("UpperTorso") then
	torso = char:FindFirstChild("UpperTorso")
end

------------------------------------------------------------------------------------------------------------------




--//When the player gets ragdolled / unRagdolled
char:GetAttributeChangedSignal("IsRagdoll"):Connect(function()
	local isRagdoll = char:GetAttribute("IsRagdoll")
	if isRagdoll and torso then
		capturedBehavior = UIS.MouseBehavior
		UIS.MouseBehavior = Enum.MouseBehavior.Default
		hum:ChangeState(Enum.HumanoidStateType.Ragdoll)
		hum:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
		torso:ApplyImpulse(torso.CFrame.LookVector * 75)
		-- Ragdoll gate: force-cancel wallrun on client (instant, no server round-trip)
		pcall(function()
			local RS = game:GetService("ReplicatedStorage")
			local Players = game:GetService("Players")
			local Movement = require(RS.Modules.Movement.Objects.Movement)
			local plr = Players.LocalPlayer
			local mov = plr and Movement.GetMovementObj(plr) or nil
			if mov then
				mov:CancelConflictingActions("Ragdoll")
				mov:CleanupOrphanPhysics()
				-- Also stop UI bars
				pcall(function() mov:BarTweenStop({ Action = "Wallrun" }) end)
			else
				-- Fallback: direct HRP sweep
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
		if capturedBehavior then
			UIS.MouseBehavior = capturedBehavior
			capturedBehavior = nil
		end
		hum:ChangeState(Enum.HumanoidStateType.GettingUp)
	end
end)

--//this happens when the player dies
hum.Died:Connect(function()
	if capturedBehavior then
		UIS.MouseBehavior = capturedBehavior
		capturedBehavior = nil
	end
	if not torso then return end
	torso:ApplyImpulse(torso.CFrame.LookVector * 100)
end)