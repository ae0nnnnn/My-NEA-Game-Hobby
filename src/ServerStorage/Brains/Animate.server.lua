-- NPC Animate — Movement-driven walk/sprint + face-player flank strafe
-- Cloned per NPC by npc.new, replaces default Roblox Animate.
-- Uses MovementObj WalkCycleAnims and reuses Movement/Animations folder.

task.wait(0.5)

local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")

local SSModules = SS.Modules
local RSModules = RS.Modules

local npcModule = require(SSModules.Objects.npc)
local Movement = require(RSModules.Movement.Objects.Movement)
local SprintingModule = require(RSModules.Movement.Mechnanics.Sprinting)

local npcCharacter = script.Parent :: Model
local humanoidRootPart = npcCharacter:WaitForChild("HumanoidRootPart") :: BasePart
local humanoidInstance = npcCharacter:WaitForChild("Humanoid") :: Humanoid

-- Resolve MovementObj (created in npc.new)
local function getMovementObject(): any
	local characterNpc = npcModule.GetNpcFromCharacter(npcCharacter)
	if characterNpc and characterNpc.MovementObj then
		return characterNpc.MovementObj
	end
	local success, movementObjectResult = pcall(function()
		return Movement.GetMovementObj(npcCharacter)
	end)
	if success and movementObjectResult then
		return movementObjectResult
	end
	return nil
end

local movementObject = getMovementObject()
if not movementObject then
	warn("[NPC Animate] no MovementObj for", npcCharacter.Name)
	return
end

-- Keep walk tracks synced with weapon/IsLow/InCombat
local function refreshWalkTracks()
	local walkSuccess = pcall(function()
		movementObject:UpdateWalkTracks()
	end)
	if not walkSuccess then
		warn("[NPC Animate] UpdateWalkTracks failed for", npcCharacter.Name)
	end
end

refreshWalkTracks()

local equippedChangedConnection = npcCharacter:GetAttributeChangedSignal("Equipped"):Connect(refreshWalkTracks)
local weaponChangedConnection = npcCharacter:GetAttributeChangedSignal("CurrentWeapon"):Connect(refreshWalkTracks)
local isLowChangedConnection = npcCharacter:GetAttributeChangedSignal("IsLow"):Connect(refreshWalkTracks)
local inCombatChangedConnection = npcCharacter:GetAttributeChangedSignal("InCombat"):Connect(refreshWalkTracks)

-- Sprint helpers — range-gated: walk when within 1/4 AggroRange for precise flank, sprint otherwise
local function shouldSprintForDistance(distanceToTarget: number, aggroRange: number): boolean
	return distanceToTarget > (aggroRange * 0.25)
end

local function isFlankerForSprint(): boolean
	local characterNpcForFlankCheck = npcModule.GetNpcFromCharacter(npcCharacter)
	if not characterNpcForFlankCheck then return false end
	local groupNameForFlankCheck = characterNpcForFlankCheck:GetGroupName()
	if not groupNameForFlankCheck then return false end
	local activeGroupsForFlankCheck = npcModule.GetActiveGroups()
	local groupDataForFlankCheck = activeGroupsForFlankCheck[groupNameForFlankCheck]
	return groupDataForFlankCheck and groupDataForFlankCheck.Aggressor and groupDataForFlankCheck.Aggressor ~= characterNpcForFlankCheck or false
end

local function updateSprintStateForFlanker(distanceToTarget: number, aggroRangeValue: number)
	-- Flankers walk while orbiting — no sprint even outside 1/4 AggroRange
	if isFlankerForSprint() then
		local isCurrentlySprintingForFlank = npcCharacter:GetAttribute("Sprinting") == true or movementObject.IsActing.IsSprinting or movementObject.IsActing.IsEXSprinting
		if isCurrentlySprintingForFlank then
			pcall(function() SprintingModule.ForceStopAllSprinting(movementObject) end)
		end
		return
	end
	local wantsSprint = shouldSprintForDistance(distanceToTarget, aggroRangeValue)
	local isCurrentlySprinting = npcCharacter:GetAttribute("Sprinting") == true or movementObject.IsActing.IsSprinting
	if wantsSprint and not isCurrentlySprinting then
		pcall(function() SprintingModule.NormalToggle(movementObject) end)
	elseif not wantsSprint and isCurrentlySprinting then
		pcall(function() SprintingModule.ForceStopAllSprinting(movementObject) end)
	end
end

-- Flanker face-player lock — AlignOrientation (not CFrame jam, so MoveTo keeps velocity)
local isFacingLockedForFlank = false
local flankAlignOrientation: AlignOrientation? = nil
local flankAttachment: Attachment? = nil

local function ensureFlankConstraint()
	if flankAlignOrientation and flankAlignOrientation.Parent then return end
	local attachmentForFlank = Instance.new("Attachment")
	attachmentForFlank.Name = "FlankAttachment"
	attachmentForFlank.Parent = humanoidRootPart
	local alignForFlank = Instance.new("AlignOrientation")
	alignForFlank.Name = "FlankAlign"
	alignForFlank.Attachment0 = attachmentForFlank
	alignForFlank.Mode = Enum.OrientationAlignmentMode.OneAttachment
	alignForFlank.RigidityEnabled = false
	alignForFlank.Responsiveness = 200
	alignForFlank.MaxTorque = 500000
	alignForFlank.MaxAngularVelocity = math.huge
	alignForFlank.Parent = humanoidRootPart
	flankAttachment = attachmentForFlank
	flankAlignOrientation = alignForFlank
end

local function destroyFlankConstraint()
	if flankAlignOrientation then
		pcall(function() flankAlignOrientation:Destroy() end)
		flankAlignOrientation = nil
	end
	if flankAttachment then
		pcall(function() flankAttachment:Destroy() end)
		flankAttachment = nil
	end
end

local function updateFacingForFlanker(currentTarget: Model?)
	if not currentTarget or not currentTarget.Parent then
		if isFacingLockedForFlank then
			isFacingLockedForFlank = false
			pcall(function() humanoidInstance.AutoRotate = true end)
			destroyFlankConstraint()
		end
		return
	end
	local targetRootPart = currentTarget:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not targetRootPart then return end
	local characterNpcObject = npcModule.GetNpcFromCharacter(npcCharacter)
	if not characterNpcObject then return end
	local groupNameForNpc = characterNpcObject:GetGroupName()
	if not groupNameForNpc then
		if isFacingLockedForFlank then
			isFacingLockedForFlank = false
			pcall(function() humanoidInstance.AutoRotate = true end)
			destroyFlankConstraint()
		end
		return
	end
	local activeGroupsTable = npcModule.GetActiveGroups()
	local groupDataForNpc = activeGroupsTable[groupNameForNpc]
	if groupDataForNpc and groupDataForNpc.Aggressor and groupDataForNpc.Aggressor ~= characterNpcObject then
		if not isFacingLockedForFlank then
			isFacingLockedForFlank = true
			pcall(function() humanoidInstance.AutoRotate = false end)
			ensureFlankConstraint()
		end
		-- Yaw-only look at player via AlignOrientation (no position teleport)
		local npcPositionForLook = humanoidRootPart.Position
		local targetPositionForLook = targetRootPart.Position
		local flatLookPosition = Vector3.new(targetPositionForLook.X, npcPositionForLook.Y, targetPositionForLook.Z)
		if (flatLookPosition - npcPositionForLook).Magnitude > 0.5 and flankAlignOrientation then
			local lookCFrame = CFrame.lookAt(npcPositionForLook, flatLookPosition)
			pcall(function()
				flankAlignOrientation.CFrame = lookCFrame.Rotation
			end)
		end
	else
		if isFacingLockedForFlank then
			isFacingLockedForFlank = false
			pcall(function() humanoidInstance.AutoRotate = true end)
			destroyFlankConstraint()
		end
	end
end

-- Main heartbeat — WalkCycle + sprint gate + strafe facing
local heartbeatConnection: RBXScriptConnection? = nil
heartbeatConnection = RunService.Heartbeat:Connect(function()
	if not npcCharacter.Parent or humanoidInstance.Health <= 0 then
		if heartbeatConnection then heartbeatConnection:Disconnect() end
		return
	end

	-- Drive walk blend weights from MovementObj
	pcall(function() movementObject:WalkCycle() end)

	-- Range-gated sprint + face-player update
	local characterNpcObjectForSprint = npcModule.GetNpcFromCharacter(npcCharacter)
	local aiObjectForSprint = characterNpcObjectForSprint and characterNpcObjectForSprint.AIObject or nil
	local currentTargetForSprint: Model? = aiObjectForSprint and aiObjectForSprint.Target or nil
	if currentTargetForSprint and currentTargetForSprint.Parent and currentTargetForSprint:FindFirstChild("HumanoidRootPart") then
		local targetRootPartForDistance = currentTargetForSprint.HumanoidRootPart :: BasePart
		local distanceToTargetForSprint = (targetRootPartForDistance.Position - humanoidRootPart.Position).Magnitude
		local aggroRangeForSprint = aiObjectForSprint and aiObjectForSprint.AggroRange or 30
		updateSprintStateForFlanker(distanceToTargetForSprint, aggroRangeForSprint)
		updateFacingForFlanker(currentTargetForSprint)
	else
		updateFacingForFlanker(nil)
	end
end)

humanoidInstance.Died:Connect(function()
	if heartbeatConnection then heartbeatConnection:Disconnect() end
	if equippedChangedConnection then equippedChangedConnection:Disconnect() end
	if weaponChangedConnection then weaponChangedConnection:Disconnect() end
	if isLowChangedConnection then isLowChangedConnection:Disconnect() end
	if inCombatChangedConnection then inCombatChangedConnection:Disconnect() end
	if isFacingLockedForFlank then
		pcall(function() humanoidInstance.AutoRotate = true end)
	end
	destroyFlankConstraint()
	pcall(function() movementObject:ClearWalkAnims() end)
end)
