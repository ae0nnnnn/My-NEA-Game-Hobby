task.wait(1.5)

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")

local SSModules = SS.Modules

local NPC_Class = require(SSModules.Objects.npc)
local NPC_Info = require(SSModules.Dictionaries.NPC_Info)
local ThreatTable = require(SSModules.AI.ThreatTable)
local StateMachine = require(SSModules.AI.StateMachine)
local IntentService = require(SSModules.Combat.IntentService)
local SimplePath = require(RS.SimplePath)

local char = script.Parent
local HRP: BasePart = char.HumanoidRootPart
local Humanoid: Humanoid = char.Humanoid

char:SetAttribute("Equipped", true)
char:SetAttribute("Combo", 1)
char:SetAttribute("Stunned", false)
char:SetAttribute("Swing", false)
char:SetAttribute("Attacking", false)
char:SetAttribute("Iframes", false)
char:SetAttribute("IsBlocking", false)
char:SetAttribute("Blocking", 0)
char:SetAttribute("Karma", 0)

char:SetAttribute("Mode1", false)
char:SetAttribute("Mode2", false)
char:SetAttribute("Parrying", false)

char:SetAttribute("Dodges", 0)
char:SetAttribute("Sprinting", false)
char:SetAttribute("IsCrouching", false)

local npc = NPC_Class.GetNpcFromCharacter(char)

local Object = {
	Name = char.Name,
	npc = npc,
	model = char,
	human = Humanoid,
	isPathRunning = false,
	Target = nil,
	LastPlayerActions = {},
	AggroRange = 0,
	AttackRange = 0,
	ReactionTime = 0,
	LowHealthThreshold = 0,
	RetreatDuration = 0,
	BlockChance = 0,
	ParryChance = 0,
	StaminaCost = 0,
	HyprParryChance = 0,
	DodgeChance = 0,
	lastDefenseCheck = 0,
	nextAttackTime = 0,
	retreatUntil = 0,
	timeSinceNoTarget = 0,
	feintsSeen = 0,
	lastFeintTick = 0,
	baitedUntil = 0,
}

export type OBJ = typeof(Object)

-- NEW: pull AI params (AggroRange, AttackRange, ReactionTime, etc.) from
-- NPC_Info by looking up this NPC's Difficulty tier, and init its ThreatTable
local function InitAI(Object, npcName)
	local stats = NPC_Info.getStats(npcName)
	local aiParams = NPC_Info.getAIParams(stats.Difficulty)
	print("Looking up NPC:", char.Name, "stats:", NPC_Info.getStats(char.Name))

	Object.AggroRange = aiParams.AggroRange
	Object.AttackRange = aiParams.AttackRange
	Object.ReactionTime = aiParams.ReactionTime
	Object.LowHealthThreshold = aiParams.LowHealthThreshold
	Object.RetreatDuration = aiParams.RetreatDuration
	Object.BlockChance = aiParams.BlockChance
	Object.ParryChance = aiParams.ParryChance
	Object.StaminaCost = aiParams.StaminaCost
	Object.HyprParryChance = aiParams.HyprParryChance
	Object.DodgeChance = aiParams.DodgeChance

	ThreatTable.Init(Object)
	npc.AIObject = Object
end

InitAI(Object, char.Name)

-- Long-lived pathfinder (per-NPC, not per-state) — destroyed on death to avoid leak
Object.path = SimplePath.new(char, {
	AgentRadius = 3,
	AgentHeight = 5,
	AgentCanJump = true,
	AgentCanClimb = false,
})
Object.lastPathPos = nil :: Vector3?
Object.lastPathTime = 0
Object.path.Visualize = true

local function isAlive(char: Model): boolean
	return char and char.Parent ~= nil and char:FindFirstChild("Humanoid") and (char.Humanoid :: Humanoid).Health > 0
		or false
end

local function getNearestPlayerWithin(range: number): Model?
	local nearest, best = nil, math.huge
	for _, plr in ipairs(game:GetService("Players"):GetPlayers()) do
		local c = plr.Character
		if isAlive(c) and c:FindFirstChild("HumanoidRootPart") and HRP and HRP.Parent then
			local d = (c.HumanoidRootPart.Position - HRP.Position).Magnitude
			if d < range and d < best then
				best, nearest = d, c
			end
		end
	end
	return nearest
end

local function DefensiveReact(obj: OBJ): string?
	-- event-driven: no throttle here, ReactionTime is task.delay in subscriber (A 0.2215 human delay)
	local now = os.clock()
	if obj.feintsSeen > 0 and now - (obj.lastFeintTick or 0) > 5 then
		obj.feintsSeen = 0
	end
	local effectiveParry = obj.ParryChance
	if now < (obj.baitedUntil or 0) then
		effectiveParry *= 0.5
	end
	local function tryIntent(char: Model): string?
		local intent = IntentService.GetIntent(char, nil)
		if intent == "Feint" then
			obj.feintsSeen = (obj.feintsSeen or 0) + 1
			obj.lastFeintTick = now
			obj.baitedUntil = now + 2
			return "Baited"
		end
		local blockingNpcCharacter = obj.npc and obj.npc.Character or nil
		local isCurrentlyBlocking = blockingNpcCharacter and blockingNpcCharacter:GetAttribute("IsBlocking") == true
		if intent == "Swing" then
			if math.random() < effectiveParry then
				local npcChar = obj.npc and obj.npc.Character or nil
				if npcChar and (npcChar:GetAttribute("Attacking") or npcChar:GetAttribute("Swing")) then
					pcall(function() obj.npc:CancelAttack() end)
					if npcChar:GetAttribute("Attacking") or npcChar:GetAttribute("Swing") then
						return nil
					end
				end
				if isCurrentlyBlocking then
					pcall(function()
						obj.npc:Unblock()
					end)
				end
				pcall(function()
					obj.npc:Parry()
				end)
				if blockingNpcCharacter and (blockingNpcCharacter:GetAttribute("Parrying") or blockingNpcCharacter:GetAttribute("HyprParry")) then
					return "Parry"
				end
				return nil
			elseif math.random() < obj.BlockChance then
				pcall(function() obj.npc:Block() end)
				-- auto-unblock after 0.8s so he doesn't stay frozen blocking forever (shutdown fix)
				task.delay(0.8, function()
					if obj.npc and obj.npc.Character and obj.npc.Character:GetAttribute("IsBlocking") then
						pcall(function() obj.npc:Unblock() end)
					end
				end)
				return "Block"
			elseif math.random() < obj.DodgeChance then
				if isCurrentlyBlocking then
					pcall(function()
						obj.npc:Unblock()
					end)
				end
				pcall(function()
					obj.npc:Dodge()
				end)
				return "Dodge"
			end
		elseif intent and intent ~= "None" and intent ~= "Swing" then
			local npcChar2 = obj.npc and obj.npc.Character or nil
			if npcChar2 and (npcChar2:GetAttribute("Attacking") or npcChar2:GetAttribute("Swing")) then
				pcall(function() obj.npc:CancelAttack() end)
				if npcChar2:GetAttribute("Attacking") or npcChar2:GetAttribute("Swing") then
					return nil
				end
			end
			if math.random() < (obj.HyprParryChance or 0) or math.random() < effectiveParry then
				if isCurrentlyBlocking then
					pcall(function()
						obj.npc:Unblock()
					end)
				end
				pcall(function()
					obj.npc:Parry()
				end)
				if blockingNpcCharacter and (blockingNpcCharacter:GetAttribute("Parrying") or blockingNpcCharacter:GetAttribute("HyprParry")) then
					return "Parry"
				end
				return nil
			end
		end
		return nil
	end
	-- Priority 1: current Target if valid and within 30
	local t = obj.Target
	if t and t.Parent and t:FindFirstChild("HumanoidRootPart") and HRP and HRP.Parent then
		local d = (t.HumanoidRootPart.Position - HRP.Position).Magnitude
		if d < 30 then
			local r = tryIntent(t)
			if r then
				return r
			end
		end
	end
	-- Priority 2: scan other nearby players
	for _, plr in ipairs(game:GetService("Players"):GetPlayers()) do
		local c = plr.Character
		if not c or c == t then
			continue
		end
		local hrp = c:FindFirstChild("HumanoidRootPart") :: BasePart?
		if c and hrp and HRP and HRP.Parent and (hrp.Position - HRP.Position).Magnitude < 30 then
			local r = tryIntent(c)
			if r then
				return r
			end
		end
	end
	return nil
end

local States = {
	Idle = {
		Enter = function(obj)
			obj.timeSinceNoTarget = 0
			if obj.npc then
				obj.npc:Idle()
			end
		end,
		Update = function(obj, delaT)
			-- threat first, fallback to proximity
			local t = ThreatTable.GetTopThreat(obj)
			if not t or not isAlive(t) then
				t = getNearestPlayerWithin(obj.AggroRange)
				if t then
					obj.Target = t
				end
			end
			if t and isAlive(t) and HRP and t:FindFirstChild("HumanoidRootPart") then
				local d = (t.HumanoidRootPart.Position - HRP.Position).Magnitude
				if d <= obj.AggroRange then
					return "Chase"
				end
			end
			return nil
		end,
		Exit = function(obj) end,
	},
	Chase = {
		Enter = function(obj)
			obj.timeSinceNoTarget = 0
		end,
		Update = function(obj, delaT)
			-- event-driven: don't poll here, subscription handles it with 0.2215 delay
			local target = obj.Target
			if not target or not isAlive(target) then
				target = ThreatTable.GetTopThreat(obj) or getNearestPlayerWithin(obj.AggroRange)
				obj.Target = target
			end
			if not target or not isAlive(target) then
				obj.timeSinceNoTarget += delaT
				if obj.timeSinceNoTarget > 3 then
					return "Idle"
				end
				return nil
			end
			obj.timeSinceNoTarget = 0
			if not HRP or not target:FindFirstChild("HumanoidRootPart") then
				return nil
			end
			local dist = (target.HumanoidRootPart.Position - HRP.Position).Magnitude
			if dist <= obj.AttackRange then
				return "Combat"
			end
			-- Pack Tactics: role-based movement (Addendum B)
			local myNpcObject = obj.npc
			local groupNameForMember = myNpcObject and myNpcObject:GetGroupName() or nil
			local packGroupData: any = nil
			if groupNameForMember and NPC_Class.GetActiveGroups then
				local activeGroupsTable = NPC_Class.GetActiveGroups()
				packGroupData = activeGroupsTable[groupNameForMember]
				if packGroupData and packGroupData.TargetPlayer and isAlive(packGroupData.TargetPlayer) then
					-- leader's shared target overrides personal threat if fresher
					target = packGroupData.TargetPlayer
					obj.Target = target
				end
				-- Flanker: if Aggressor exists and I'm not it, continuous orbit (face-player via AlignOrientation)
				if
					packGroupData
					and packGroupData.Aggressor
					and packGroupData.Aggressor ~= myNpcObject
					and target
					and target:FindFirstChild("HumanoidRootPart")
				then
					local sortedFlankMembers: { any } = {}
					for memberNpc in pairs(packGroupData.Members) do
						table.insert(sortedFlankMembers, memberNpc)
					end
					table.sort(sortedFlankMembers, function(a, b)
						return (a.Character and a.Character.Name or "") < (b.Character and b.Character.Name or "")
					end)
					local memberIndexForFlank = table.find(sortedFlankMembers, myNpcObject) or (#sortedFlankMembers + 1)
					local totalMemberCount = #sortedFlankMembers
					local angleStepDegrees = 360 / math.max(totalMemberCount, 1)
					local orbitSpeedDegreesPerSecond = 30
					local flankDirectionMultiplier = (memberIndexForFlank % 2 == 0 and 1 or -1)
					local orbitOffsetDegrees = flankDirectionMultiplier * os.clock() * orbitSpeedDegreesPerSecond
					local flankAngleRadians =
						math.rad(angleStepDegrees * (memberIndexForFlank - 1) + orbitOffsetDegrees)
					local flankRadiusStuds = 14
					local targetPositionForFlank = target.HumanoidRootPart.Position
					local flankPosition = targetPositionForFlank
						+ Vector3.new(
							math.cos(flankAngleRadians) * flankRadiusStuds,
							0,
							math.sin(flankAngleRadians) * flankRadiusStuds
						)
					-- throttle flank MoveTo to avoid spam
					local lastFlankPosition: Vector3? = obj.lastFlankPos
					local lastFlankTime: number = obj.lastFlankTime or 0
					local currentTimeForFlank = os.clock()
					if
						not lastFlankPosition
						or (flankPosition - lastFlankPosition).Magnitude > 2
						or currentTimeForFlank - lastFlankTime > 0.2
					then
						obj.lastFlankPos = flankPosition
						obj.lastFlankTime = currentTimeForFlank
						pcall(function()
							obj.human:MoveTo(flankPosition)
						end)
						if _G.DEBUG_PACK_VISUALIZE then
							pcall(function()
								local debugPartForFlank = Instance.new("Part")
								debugPartForFlank.Size = Vector3.new(0.5, 0.5, 0.5)
								debugPartForFlank.Anchored = true
								debugPartForFlank.CanCollide = false
								debugPartForFlank.Color = Color3.fromRGB(0, 170, 255)
								debugPartForFlank.Position = flankPosition
								debugPartForFlank.Parent = workspace
								game.Debris:AddItem(debugPartForFlank, 0.3)
							end)
						end
					end
					return nil
				end
				-- Subordinate follower: use Leader/Aggressor's SharedWaypoints or lastPathPos (stable sorted)
				if
					packGroupData
					and packGroupData.Members[myNpcObject]
					and packGroupData.Leader ~= myNpcObject
					and not (packGroupData.Aggressor and packGroupData.Aggressor == myNpcObject)
				then
					-- if group has a shared target pos, follow with offset
					local sharedWaypointPosition = packGroupData.SharedWaypoints
							and packGroupData.SharedWaypoints[#packGroupData.SharedWaypoints]
							and packGroupData.SharedWaypoints[#packGroupData.SharedWaypoints].Position
						or packGroupData.TargetPlayer
							and packGroupData.TargetPlayer:FindFirstChild("HumanoidRootPart")
							and packGroupData.TargetPlayer.HumanoidRootPart.Position
					if sharedWaypointPosition then
						local sortedFollowerMembers: { any } = {}
						for memberNpc in pairs(packGroupData.Members) do
							table.insert(sortedFollowerMembers, memberNpc)
						end
						table.sort(sortedFollowerMembers, function(a, b)
							return (a.Character and a.Character.Name or "") < (b.Character and b.Character.Name or "")
						end)
						local followerIndex = table.find(sortedFollowerMembers, myNpcObject) or 1
						local followerOffset =
							Vector3.new((followerIndex % 2 == 0 and 4 or -4), 0, (followerIndex * 2) % 6)
						pcall(function()
							obj.human:MoveTo(sharedWaypointPosition + followerOffset)
						end)
						return nil
					end
				end
			end
			-- SimplePath throttled recompute: only when target moved >4 studs or >0.5s (Leader/Aggressor does compute)
			if obj.path and target:FindFirstChild("HumanoidRootPart") then
				local currentTimeForPath = os.clock()
				local targetPositionForPath = target.HumanoidRootPart.Position
				local lastPathPosition = obj.lastPathPos
				local needsRecompute = not lastPathPosition
					or (targetPositionForPath - lastPathPosition).Magnitude > 4
					or currentTimeForPath - (obj.lastPathTime or 0) > 0.5
				-- only Leader/Aggressor does expensive ComputeAsync; followers already returned above
				local isComputeOwnerForPath = not packGroupData
					or packGroupData.Leader == myNpcObject
					or packGroupData.Aggressor == myNpcObject
				if needsRecompute and isComputeOwnerForPath then
					pcall(function()
						obj.path:Run(targetPositionForPath)
					end)
					obj.lastPathPos = targetPositionForPath
					obj.lastPathTime = currentTimeForPath
					if packGroupData then
						packGroupData.SharedWaypoints = obj.path._waypoints
						packGroupData.TargetPlayer = target
					end
				elseif not isComputeOwnerForPath then
					-- follower fallback: direct MoveTo already handled, but ensure we still move if shared missing
					pcall(function()
						obj.human:MoveTo(targetPositionForPath)
					end)
				end
			else
				pcall(function()
					obj.human:MoveTo(target.HumanoidRootPart.Position)
				end)
			end
			return nil
		end,
		Exit = function(obj) end,
	},
	Combat = {
		Enter = function(obj)
			obj.nextAttackTime = 0
		end,
		Update = function(obj, delaT)
			-- event-driven: subscription handles defensive reacts with 0.2215 human delay
			local target = obj.Target
			if not target or not isAlive(target) then
				return "Chase"
			end
			if not HRP or not target:FindFirstChild("HumanoidRootPart") then
				return "Chase"
			end
			-- Pack flankers keep orbiting even in Combat (don't hug)
			do
				local combatNpcObject = obj.npc
				local combatGroupName = combatNpcObject and combatNpcObject:GetGroupName() or nil
				if combatGroupName and NPC_Class.GetActiveGroups then
					local combatActiveGroups = NPC_Class.GetActiveGroups()
					local combatPackData = combatActiveGroups[combatGroupName]
					if combatPackData and combatPackData.Aggressor and combatPackData.Aggressor ~= combatNpcObject then
						local sortedCombatMembers: { any } = {}
						for memberNpc in pairs(combatPackData.Members) do
							table.insert(sortedCombatMembers, memberNpc)
						end
						table.sort(sortedCombatMembers, function(a, b)
							return (a.Character and a.Character.Name or "") < (b.Character and b.Character.Name or "")
						end)
						local memberIndexForCombatFlank = table.find(sortedCombatMembers, combatNpcObject)
							or (#sortedCombatMembers + 1)
						local combatAngleStep = 360 / math.max(#sortedCombatMembers, 1)
						local combatDirectionMult = (memberIndexForCombatFlank % 2 == 0 and 1 or -1)
						local combatFlankAngle = math.rad(
							combatAngleStep * (memberIndexForCombatFlank - 1) + combatDirectionMult * os.clock() * 30
						)
						local combatFlankRadius = 14
						local combatTargetPosition = target.HumanoidRootPart.Position
						local combatFlankPos = combatTargetPosition
							+ Vector3.new(
								math.cos(combatFlankAngle) * combatFlankRadius,
								0,
								math.sin(combatFlankAngle) * combatFlankRadius
							)
						pcall(function()
							obj.human:MoveTo(combatFlankPos)
						end)
						return nil
					end
				end
			end

			-- hotfix A: only suppress while waiting 0.2215 to decide
			if Object._pendingReact or (Object._sm and (Object._sm.Current == "Baited" or Object._sm.Current == "Parrying")) then return nil end
			do
				local c = obj.npc and obj.npc.Character or nil
				if c and (c:GetAttribute("Swing") or c:GetAttribute("Attacking") or c:GetAttribute("Parrying") or c:GetAttribute("HyprParry")) then
					return nil
				end
			end
			-- low health -> retreat (Boss would skip, SmallFry doesn't)
			if obj.human and obj.human.Health / obj.human.MaxHealth < obj.LowHealthThreshold then
				return "Retreat"
			end
			local dist = (target.HumanoidRootPart.Position - HRP.Position).Magnitude
			if dist > obj.AttackRange * 1.2 then
				return "Chase"
			end
			-- attack cadence
			local now = os.clock()
			if now >= (obj.nextAttackTime or 0) then
				if obj.npc then
					pcall(function()
						obj.npc:Attack()
					end)
				end
				obj.nextAttackTime = now + obj.ReactionTime
			end
			return nil
		end,
		Exit = function(obj) end,
	},
	Retreat = {
		Enter = function(obj)
			obj.retreatUntil = os.clock() + obj.RetreatDuration
			if HRP and obj.Target and obj.Target:FindFirstChild("HumanoidRootPart") then
				local away = (HRP.Position - obj.Target.HumanoidRootPart.Position).Unit * 16
				local dest = HRP.Position + Vector3.new(away.X, 0, away.Z)
				pcall(function()
					obj.human:MoveTo(dest)
				end)
			end
		end,
		Update = function(obj, delaT)
			if os.clock() >= (obj.retreatUntil or 0) then
				return "Chase"
			end
			return nil
		end,
		Exit = function(obj) end,
	},
	Baited = {
		Enter = function(obj)
			obj.baitedEnter = os.clock()
			-- brief hesitation: stop movement
			pcall(function()
				obj.human:MoveTo(HRP.Position)
			end)
		end,
		Update = function(obj, delaT)
			if os.clock() - (obj.baitedEnter or 0) > 0.6 then
				return "Chase"
			end
			return nil
		end,
		Exit = function(obj) end,
	},
	Parrying = {
		Enter = function(obj) end,
		Update = function(obj, delaT)
			local c = obj.npc and obj.npc.Character or nil
			if not c then
				return "Chase"
			end
			-- hold while Parrying or HyprParry attribute is true or Stunned from parry
			if c:GetAttribute("Parrying") or c:GetAttribute("HyprParry") then
				return nil
			end
			return "Combat"
		end,
		Exit = function(obj) end,
	},
}
local sm = StateMachine.new(States, "Idle", Object)
Object._sm = sm -- expose for event-driven transitions

-- Event-driven defensive reactions (A with 0.2215 human delay, baited debounce 0.8s)
-- Detection is instant on IntentChanged, execution is delayed by ReactionTime so SmallFry sees everything but acts late
local intentConn: RBXScriptConnection? = nil
Object._pendingReact = false
local lastBaitedAt = 0
intentConn = IntentService.IntentChanged.Event:Connect(function(changedChar: Model, intent: string)
	if changedChar == char then return end -- don't react to own Swing/Parry/Block
	if not Players:GetPlayerFromCharacter(changedChar) then return end -- only react to players for now
	if not char.Parent or Humanoid.Health <= 0 then
		return
	end
	if sm.Current == "Parrying" or sm.Current == "Baited" then
		return
	end -- don't stack while reacting
	if Object._pendingReact then
		return
	end
	-- target-aware filter: only react to intents from relevant attackers within 30
	local isRelevant = false
	local t = Object.Target
	if t and changedChar == t then
		local thrp = t:FindFirstChild("HumanoidRootPart") :: BasePart?
		if thrp and HRP and HRP.Parent and (thrp.Position - HRP.Position).Magnitude < 30 then
			isRelevant = true
		end
	else
		-- check if changedChar is any nearby player within 30 (covers aggro acquire before Target set)
		local hrp = changedChar:FindFirstChild("HumanoidRootPart") :: BasePart?
		if hrp and HRP and HRP.Parent and (hrp.Position - HRP.Position).Magnitude < 30 then
			isRelevant = true
		end
	end
	if not isRelevant then
		return
	end
	if intent ~= "Swing" and intent ~= "Feint" and intent ~= "Block" and intent ~= "Parry" then
		-- also allow skill names: check SkillInfo
		local ok, skillInfoMod = pcall(require, SS.Modules.Dictionaries.SkillInfo)
		if ok and skillInfoMod and skillInfoMod.getSkill then
			local s = skillInfoMod.getSkill(intent)
			if not s then
				return
			end
		else
			return
		end
	end
	-- debounce baited spam: don't re-bait within 0.8s
	if intent == "Feint" and os.clock() - lastBaitedAt < 0.8 then
		return
	end
	Object._pendingReact = true
	task.delay(Object.ReactionTime, function()
		Object._pendingReact = false
		if not char.Parent or Humanoid.Health <= 0 then
			return
		end
		if sm.Current == "Parrying" or sm.Current == "Baited" then
			return
		end
		-- re-read current intent at execution time (feint may have become None)
		local cur = IntentService.GetIntent(changedChar, nil)
		if not cur or cur == "None" then
			return
		end
		-- if it was Swing but now Feint (you feinted during the 0.2215 delay), treat as Feint
		local react: string? = nil
		-- use DefensiveReact helper for consistent baited/roll logic but bypass its old throttle
		-- call tryIntent path by faking a check: temporarily set a helper to evaluate cur
		-- simplest: inline the same baited check
		if cur == "Feint" then
			Object.feintsSeen = (Object.feintsSeen or 0) + 1
			Object.lastFeintTick = os.clock()
			Object.baitedUntil = os.clock() + 2
			lastBaitedAt = os.clock()
			react = "Baited"
		else
			react = DefensiveReact(Object)
		end
		if react == "Baited" then
			lastBaitedAt = os.clock()
			pcall(function() sm:TransitionTo("Baited") end)
		elseif react == "Parry" then
			pcall(function() sm:TransitionTo("Parrying") end)
		elseif react == "Block" or react == "Dodge" then
			-- Block/Dodge don't need a dedicated state; they already set IsBlocking/Dodging via DefensiveReact
			-- keep in current state, just don't transition (avoids shutdown from permanent IsBlocking)
		end
	end)
end)
Object._intentConn = intentConn

local conn: RBXScriptConnection

conn = RunService.Heartbeat:Connect(function(delaT)
	if not char.Parent or Humanoid.Health <= 0 then
		if conn then
			conn:Disconnect()
		end
		if Object._intentConn then
			pcall(function()
				Object._intentConn:Disconnect()
			end)
		end
		if Object.path then
			pcall(function()
				Object.path:Destroy()
			end)
		end
		return
	end
	sm:Update(delaT)
end)

Humanoid.Died:Connect(function()
	if conn then
		conn:Disconnect()
	end
	if Object._intentConn then
		pcall(function()
			Object._intentConn:Disconnect()
		end)
	end
	if Object.path then
		pcall(function()
			Object.path:Destroy()
		end)
	end
end)
