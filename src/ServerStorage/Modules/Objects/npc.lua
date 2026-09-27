--[=[
	@class NPC

	Creates and manages NPC objects, analogous to the PlayerObject Roblox creates for players.
	Each NPC wraps a Character model with combat state, stats, and a behavior-tree Brain script,
	tracked via the internal CharToNPC lookup table.
]=]
--[=[
	@interface NPCData
	.FirstName string -- The NPC's first name (populated after name generation, see npc.new)
	.LastName string -- The NPC's last name (populated after name generation)
	.Difficulty string -- e.g. "Boss", "SmallFry"; used to pick the model template and Brain script from Brain_Folder
	.MobType string -- e.g. "Humanoid", "Human"; affects model creation, element assignment, and Brain selection
	.Character Model -- The NPC's physical character model in workspace.NPC
	.Element ElementObject? -- The NPC's combat element object, or nil for non-humanoid mobs without one
	.Brain Script -- The behavior-tree script driving this NPC, parented under Character
	.talents {} -- Reserved for future talent data (currently empty table)
	.skills {} -- Reserved for future skill data (currently empty table)
	.drops {} -- Loot table entries chosen on death (currently unused, see PickDrops)
	.MovementObj ServerTypes.MovementObj -- Handles this NPC's movement mechanics (dodge, climb, wall run) via RS.Modules.Movement
	.Intent string -- Buffer holding the queued combat action ("None", "Attack", etc.); read by Brain scripts
	.AIObject {[string]: any}? -- Reference to the Brain script's Object table (holds .Threats, .Target, etc.); set after Brain initializes
	._GroupName string? -- Internal Pack Tactics group id, set by AssignGroup; nil if not in a group
	@within NPC
]=]

--[=[
	@interface NPCMethods
	.Destroy (self: NPC) -> () -- Cleans up CharToNPC, Pack Tactics group membership, Character model, and Combat_Data entries; then freezes the object
	.EquipWeapon (self: NPC) -> () -- Equips the NPC's CurrentWeapon attribute via EquipModule
	.UnequipWeapon (self: NPC) -> () -- Unequips the NPC's current weapon via EquipModule
	.Start (self: NPC) -> () -- Enables the NPC's Brain script (sets Disabled = false), making it active
	.Attack (self: NPC) -> () -- Performs an attack via CombatHelper; no-ops if IsTransforming
	.Idle (self: NPC) -> () -- Plays the idle animation for the NPC's current weapon; no-ops if already playing
	.Block (self: NPC) -> () -- Activates blocking via BlockModule; guarded by IsTransforming and CheckForAttributes
	.Unblock (self: NPC) -> () -- Deactivates blocking via BlockModule; same guards as Block
	.Dodge (self: NPC) -> () -- Performs a dodge via DodgeModule using this NPC's MovementObj; no-ops if IsTransforming
	.Parry (self: NPC) -> () -- Attempts a parry via ParryModule; guarded by IsTransforming and CheckForAttributes
	.Phase2 (self: NPC) -> () -- Triggers a phase 2 transformation via ModeModule; no-ops if already transforming
	.CancelAttack (self: NPC) -> () -- Cancels the current swing via CombatHelper if Swing attribute is true
	.CastAblity (self: NPC) -> () -- Stub, not yet implemented (reserved for ability casting)
	.Climb (self: NPC) -> () -- Stub, not yet implemented (reserved for wall-jump)
	.WallRun (self: NPC) -> () -- Stub, not yet implemented (reserved for wall-run)
	.AssignGroup (self: NPC, groupName: string, role: string?) -> () -- Adds this NPC to a Pack Tactics group (max 5 members); first member becomes Leader/Aggressor
	.GetGroupName (self: NPC) -> string? -- Returns the Pack Tactics group name for this NPC, if any
	@within NPC
]=]

local npc = {}
local SS = game:GetService("ServerStorage")
local RS = game:GetService("ReplicatedStorage")

local SSModules = SS.Modules
local Dictionaries = SSModules.Dictionaries

local NPC_Dictionary = require(Dictionaries.NPC_Info)
local BlockModule = require(SSModules.BlockModule)
local ParryModule = require(SSModules.Parrying)
local DodgeModule = require(RS.Modules.Movement.Mechnanics.Dodge)
local ModeModule = require(SSModules.Combat.Mode_Module)
local CombatHelper = require(SSModules.Combat.CombatHelper)
local Combat_Data = require(SSModules.Combat.Data.CombatData)
local EquipModule = require(SSModules.Combat.EquipModule)
local HelpfullModule = require(SSModules.Other.Helpful)
local Movement = require(RS.Modules.Movement.Objects.Movement)
local ServerTypes = require(SSModules.ServerTypes)
local SpeedMods = require(RS.Modules.Movement.Ultils.Speed)

local Brain_Folder = SS.Brains
local NPCFolder = game.workspace.NPC
local NPCModels = RS.Models.NPC
local WeaponAnimations = RS.Animations.Weapons

npc.__index = npc
local CharToNPC = {}

--[=[
	@interface GroupData
	.Leader NPC? -- Current group leader; first member added, re-promoted to most recent hitter on leader death
	.Aggressor NPC? -- Current aggressor (most recent hitter); re-elected on NotifyHit with 2s anti-flicker tenure
	.Members {[NPC]: boolean} -- Set of live members (max 5 per group)
	.TargetPlayer Model? -- Last player character that hit a member; set by NotifyHit
	.SharedWaypoints {any}? -- Reserved shared waypoints for coordinated movement (currently unused)
	.LastHitTimes {[NPC]: number} -- os.clock() timestamp of last hit per member; drives Leader/Aggressor election
	.lastAggressorChange number -- os.clock() when Aggressor last changed; enforces 2s minimum tenure
	@within NPC
]=]

--[=[
	Pack Tactics shared group state (Addendum B) — additive, plain data read by Brain scripts.
	Backed by Combat_Data.ActiveGroups so brains and server share the same table.
	@within NPC
]=]
export type GroupData = {
	Leader: NPC?,
	Aggressor: NPC?,
	Members: {[NPC]: boolean},
	TargetPlayer: Model?,
	SharedWaypoints: {any}?,
	LastHitTimes: {[NPC]: number},
	lastAggressorChange: number,
}
local ActiveGroups: {[string]: GroupData} = Combat_Data.ActiveGroups

export type NPC = ServerTypes.NPC

--[=[
	Creates a character Model for an NPC from templates in RS.Models.NPC.

	Uses `FindFirstChild` for Boss/Humanoid/Human mobs (tolerates missing templates),
	otherwise indexes directly (errors if missing).

	@param npcName string -- Key for NPCModels lookup (same as NpcName passed to npc.new)
	@param Difficulty string -- e.g. "Boss"; controls lookup strategy
	@param MobType string -- e.g. "Humanoid"; controls lookup strategy
	@return Model -- Cloned model (not yet parented)
	@private
	@within NPC
]=]
local function CreateModel(npcName, Difficulty, MobType)
	local TargetTemplate: Model = nil
	-- Then I would randomise hair, skintone, face etc once i make a customastion module
	if Difficulty == "Boss" or MobType == "Humanoid" or MobType == "Human" then
		TargetTemplate = NPCModels:FindFirstChild(npcName)
	else
		TargetTemplate = NPCModels[npcName]
	end

	return TargetTemplate:Clone()
end

--[=[
	Stub for loot selection. Pulls the NPC's drop table via NPC_Dictionary but
	currently returns an empty array; random selection logic is pending.

	@param npcName string -- Key for NPC_Dictionary.getStats
	@return {any} -- Chosen drops (currently always empty)
	@private
	@within NPC
]=]
local function PickDrops(npcName)
	local npcInfo = NPC_Dictionary.getStats(npcName)
	local LootTable = npcInfo.Drops
	local ChosenDrops = {}
	-- Logic to randomly pick drops from the npc's drop table will go here

	return ChosenDrops
end





--[=[
	Constructs a new NPC. Pulls stats from NPC_Dictionary, generates or reuses a Character model,
	equips its default weapon, and starts its idle animation. If the given Character already has
	a "Brain" script (e.g. a dummy NPC set up for testing), its existing Brain and Element are
	reused instead of being regenerated.

	@param NpcName string -- Name used to look up stats via NPC_Dictionary.getStats
	@param char Model? -- Optional pre-existing model to use instead of generating one from templates
	@return NPC
	@within NPC
]=]

function npc.new(NpcName: string, char: Model?): NPC
	-- TODO: remove debug prints once out of beta
	print("➔ npc.new() called! NpcName provided:", tostring(NpcName), "| Type:", type(NpcName))

	local self = (
		setmetatable({
			FirstName = "",
			LastName = "",
			Difficulty = "",
			MobType = "",
			Character = nil :: any,
			Element = nil :: any,
			MovementObj = nil :: any,
			Brain = nil :: any,
			Talents = {},
			Skills = {},
			drops = {},
			Intent = "None",
			AIObject = nil :: any,
		}, npc) :: any
	) :: NPC
	
	local NPCinfo:NPC_Dictionary.Npc_Info = NPC_Dictionary.getStats(NpcName)
	print(NPCinfo)
	print(NPC_Dictionary)
	self.MobType = NPCinfo.MobType
	self.Difficulty = NPCinfo.Difficulty
	self.Character = char or CreateModel(NpcName, self.Difficulty, self.MobType)

	self.MovementObj = Movement.new(self)

	if self.FirstName ~= "" and self.LastName ~= "" then --- first i would need to make a name generator module that would generate a name based on the npc type and mobtype and then i would use that to set the first and last name of the npc
		self.Character.Name = self.FirstName .. self.LastName
	end

	self.Character.Humanoid.MaxHealth = NPCinfo.Health
	self.Character.Humanoid.Health = NPCinfo.Health

	-- Check if the npc model is in the NPC folder
	if self.Character.Parent ~= NPCFolder then
		self.Character.Parent = NPCFolder
	end

	-- Load the npc's brain (script) based on its type and parent it to the npc model
	-- But first we need to see if the brain already exists in the model (Just in case for dummy npcs that are only used for testing and have the brain already in the model)
	-- The Debuging brains are always going to be called "Brain" and the rest of the brains are going to be called after the npc type (ex: "Boss", "Smallfry", ect)
	-- And because if the npc isn't a debug npc it wont have a brain we can use it as a flag for other things aswell
	if not self.Character:FindFirstChild("Brain") then
		local Brain: Script = Brain_Folder[self.Difficulty]:Clone()
		Brain.Parent = self.Character
		self.Brain = Brain
		
		for i, v in pairs(NPCinfo.STAT_POINTS) do
			self[i] = v
			self.Character:SetAttribute(i, v)
		end

		self.Character:SetAttribute("CurrentWeapon", "Fractured_Kunai") -- defulat is meant to be whater the mob data is for tesing purposes i am using a hard set weapon
		self.Character:SetAttribute("Blocking", 0)
	    self.Character:SetAttribute("Karma", 0)
		local Torso = self.Character:FindFirstChild("Torso")
		HelpfullModule.ChangeWeapon(self, self.Character, Torso)
		self:EquipWeapon()

		if self.Difficulty == "Boss" or self.MobType == "Humanoid" then
			local elemName = NPCinfo.Element == "Bone" and "Time" or NPCinfo.Element
			local ElementModule = require(SSModules.Element[elemName])
			self.Element = ElementModule.new()
			self.Character:SetAttribute("Element", self.Element.Name)
		else
			self.Element = nil
			self.Character:SetAttribute("Element", "None")
		end
	else
		self.Brain = self.Character.Brain
		local attr = self.Character:GetAttribute("Element")
		if attr == "Bone" then attr = "Time" end
		if attr and attr ~= "None" and attr ~= "" then
			self.Element = require(SSModules.Element[attr]).new()
			if attr == "Time" then self.Character:SetAttribute("Element", "Time") end
		else
			self.Element = nil
		end

	end

	-- Replace default Roblox Animate with Movement-driven NPC Animate (cloned per instance)
	local defaultAnimateScript = self.Character:FindFirstChild("Animate")
	if defaultAnimateScript then
		defaultAnimateScript:Destroy()
	end
	if Brain_Folder:FindFirstChild("Animate") then
		local npcAnimateClone = Brain_Folder.Animate:Clone()
		npcAnimateClone.Parent = self.Character
	end

	if self.Element and self.Element.Innate then
		self.Element:Innate(self.Character)
	end

	-- Apply AGL-scaled mobility. STAT_POINTS are applied AFTER Movement.new, so the
	-- flow's captured base speed ignored the NPC's AGL; rebase it here.
	HelpfullModule.ResetMobility(self.Character)
	if self.MovementObj and self.MovementObj.Flow then
		local walkSpeed = SpeedMods.GetMovementSpeed(self.Character, "WalkSpeed", "Walk")
		self.MovementObj.Flow.BaseSpeed = walkSpeed
		self.MovementObj.Flow.CurrentSpeed = walkSpeed
		self.MovementObj.Flow.TargetSpeed = walkSpeed
	end

	-- Pre-warm combat/movement anims for this NPC so first Swing/Block is seamless
	task.defer(function()
		local hum = self.Character:FindFirstChildOfClass("Humanoid")
		if hum and _G.WarmUpCombatAnimations then pcall(_G.WarmUpCombatAnimations, hum) end
	end)

	CharToNPC[self.Character] = self

	-- This is where the npc's drops are loaded into the npc object so that they can be accessed later when the npc dies
	--self.drops = PickDrops(NpcName)

	-- The NPC should be ready by now
	self:Idle()

	return self
end

--[=[
	Looks up the NPC object associated with a given Character model. Useful for retrieving
	an NPC from anywhere in the game as long as you have a reference to its Character.

	@param char Model -- The Character model to look up
	@return NPC? -- The associated NPC, or nil if the character has no NPC object
	@within NPC
]=]

function npc.GetNpcFromCharacter(char): NPC?
	if CharToNPC[char] then
		return CharToNPC[char]
	end
	return nil
end

--[=[
	Returns the live Pack Tactics group table (alias of Combat_Data.ActiveGroups).
	Brains read this to coordinate targeting and waypoints.

	@return {[string]: GroupData} -- Map from groupName to GroupData
	@within NPC
]=]
function npc.GetActiveGroups(): {[string]: GroupData}
	return Combat_Data.ActiveGroups
end

--[=[
	Records a hit on a group member and re-elects Aggressor.

	- Updates `LastHitTimes[hitNpc]` and `TargetPlayer` if attacker is a player character.
	- Enforces 2-second anti-flicker tenure before Aggressor can change.
	- Elects the most recent hitter; ties broken by Character.Name lexicographically.

	@param groupName string -- Pack Tactics group id (as assigned by AssignGroup / newGroup)
	@param hitNpc NPC -- The NPC that was hit
	@param attackerChar Model? -- Attacker's character model, if known
	@within NPC
]=]
function npc.NotifyHit(groupName: string, hitNpc: NPC, attackerChar: Model?)
	local packGroupData = ActiveGroups[groupName]
	if not packGroupData then return end
	packGroupData.LastHitTimes[hitNpc] = os.clock()
	if attackerChar and game.Players:GetPlayerFromCharacter(attackerChar) then
		packGroupData.TargetPlayer = attackerChar
	end
	-- anti-flicker: min 2s tenure before Aggressor can change
	local currentTimeForElect = os.clock()
	if packGroupData.Aggressor and currentTimeForElect - (packGroupData.lastAggressorChange or 0) < 2 then return end
	-- elect Aggressor: most recent hitter
	local bestCandidate: NPC? = nil
	local bestHitTime: number = -math.huge
	local bestCandidateName: string = ""
	for memberNpc in pairs(packGroupData.Members) do
		local hitTimeForMember = packGroupData.LastHitTimes[memberNpc] or -math.huge
		local memberCharacterName = memberNpc.Character and memberNpc.Character.Name or ""
		if hitTimeForMember > bestHitTime or (hitTimeForMember == bestHitTime and memberCharacterName < bestCandidateName) then
			bestCandidate, bestHitTime, bestCandidateName = memberNpc, hitTimeForMember, memberCharacterName
		end
	end
	if bestCandidate and bestCandidate ~= packGroupData.Aggressor then
		packGroupData.Aggressor = bestCandidate
		packGroupData.lastAggressorChange = currentTimeForElect
	end
end

--[=[
	Adds this NPC to a Pack Tactics group, creating the group if needed.
	Enforces max 5 members; first member becomes Leader and Aggressor automatically.
	Stores the group id on the NPC as `_GroupName` for Brain consumption until Destroy.

	@param groupName string -- Group instance id (e.g. from newGroup GUID)
	@param _role string? -- Requested role ("Leader"/"Subordinate"); only affects initial Leader if group empty
	@within NPC
]=]
function npc.AssignGroup(self: NPC, groupName: string, _role: string?)
	if not groupName or groupName == "" then return end
	local packGroupData = ActiveGroups[groupName]
	if not packGroupData then
		packGroupData = {
			Leader = nil,
			Aggressor = nil,
			Members = {},
			TargetPlayer = nil,
			SharedWaypoints = nil,
			LastHitTimes = {},
			lastAggressorChange = 0,
		}
		ActiveGroups[groupName] = packGroupData
	end
	-- enforce max 5
	local memberCount = 0
	for _ in pairs(packGroupData.Members) do memberCount += 1 end
	if memberCount >= 5 and not packGroupData.Members[self] then return end
	packGroupData.Members[self] = true
	packGroupData.LastHitTimes[self] = packGroupData.LastHitTimes[self] or 0
	-- first member auto-Leader regardless of requested role
	if not packGroupData.Leader then
		packGroupData.Leader = self
	end
	if not packGroupData.Aggressor then
		packGroupData.Aggressor = self
	end
	-- store on NPC for brain to read (no freeze issues until Destroy)
	(self :: any)._GroupName = groupName
end

--[=[
	Returns the Pack Tactics group name for this NPC, if assigned.

	@return string? -- Group id or nil if not in a group
	@within NPC
]=]
function npc.GetGroupName(self: NPC): string?
	return (self :: any)._GroupName
end

--[=[
	Spawns a full Pack Tactics group from an NPC_Dictionary group template.

	Creates a unique instance id (`groupTemplateName_GUID`), spawns the Leader at
	spawnCFrame (or SpawnLocation part if available, else 0,5,0), then places Goons
	in a radial offset (4 + 1.5*index studs, 90° increments) via PivotTo.

	@param groupTemplateName string -- Key for NPC_Dictionary.getGroup (must contain .Leader and .Goons)
	@param spawnCFrame CFrame? -- Desired spawn cframe; falls back to workspace.NPC.SpawnLocation.CFrame
	@return {NPC} -- Array of created members (Leader first)
	@within NPC
]=]
function npc.newGroup(groupTemplateName: string, spawnCFrame: CFrame?): {NPC}
	local groupTemplate = NPC_Dictionary.getGroup(groupTemplateName)
	assert(groupTemplate, "[npc.newGroup] unknown group template '" .. tostring(groupTemplateName) .. "'")
	local httpService = game:GetService("HttpService")
	local groupInstanceName = groupTemplateName .. "_" .. httpService:GenerateGUID(false)
	local createdGroupMembers: {NPC} = {}
	local spawnPosition = spawnCFrame or CFrame.new(0, 5, 0)
	if NPCFolder and NPCFolder:FindFirstChild("SpawnLocation") then
		local spawnLocationPart = NPCFolder:FindFirstChild("SpawnLocation")
		if spawnLocationPart:IsA("BasePart") then
			spawnPosition = spawnLocationPart.CFrame
		end
	end
	local function createAndPlaceMember(templateName: string, memberIndex: number): NPC
		local createdMember = npc.new(templateName)
		if createdMember and createdMember.Character and createdMember.Character.PrimaryPart then
			local angleOffset = (memberIndex * 90) % 360
			local distanceFromLeader = 4 + (memberIndex * 1.5)
			local offsetVector = Vector3.new(math.cos(math.rad(angleOffset)) * distanceFromLeader, 0, math.sin(math.rad(angleOffset)) * distanceFromLeader)
			local memberCFrame = spawnPosition + offsetVector
			pcall(function()
				createdMember.Character:PivotTo(CFrame.new(memberCFrame.Position))
			end)
		end
		return createdMember
	end
	local leaderNpc = createAndPlaceMember(groupTemplate.Leader, 0)
	leaderNpc:AssignGroup(groupInstanceName, "Leader")
	table.insert(createdGroupMembers, leaderNpc)
	for goonIndex = 1, groupTemplate.NumberOfGoons do
		local goonNpc = createAndPlaceMember(groupTemplate.Goons, goonIndex)
		goonNpc:AssignGroup(groupInstanceName, "Subordinate")
		table.insert(createdGroupMembers, goonNpc)
	end
	return createdGroupMembers
end

--[=[
	Destroys the NPC: removes it from Pack Tactics group (re-promoting Leader to most
	recent hitter if needed, clearing Aggressor, deleting empty groups), removes it from
	CharToNPC, destroys its Character model, then clears and freezes the NPC object itself
	so it can no longer be mutated or reused. Also scrubs any remaining references to this
	NPC out of every table in Combat_Data.

	@within NPC
]=]

function npc:Destroy()
	-- remove from Pack Tactics group + re-promote
	local myGroupName: string? = (self :: any)._GroupName
	if myGroupName and ActiveGroups[myGroupName] then
		local packGroupData = ActiveGroups[myGroupName]
		packGroupData.Members[self] = nil
		packGroupData.LastHitTimes[self] = nil
		if packGroupData.Leader == self then
			-- promote most recent hitter as new Leader
			local bestLeaderCandidate: NPC? = nil
			local bestLeaderHitTime: number = -math.huge
			for memberNpc in pairs(packGroupData.Members) do
				local hitTimeForMember = packGroupData.LastHitTimes[memberNpc] or 0
				if hitTimeForMember > bestLeaderHitTime then bestLeaderCandidate, bestLeaderHitTime = memberNpc, hitTimeForMember end
			end
			packGroupData.Leader = bestLeaderCandidate
		end
		if packGroupData.Aggressor == self then
			packGroupData.Aggressor = nil
		end
		local isGroupEmpty = true
		for _ in pairs(packGroupData.Members) do isGroupEmpty = false break end
		if isGroupEmpty then ActiveGroups[myGroupName] = nil end
	end
	CharToNPC[self.Character] = nil
	self.Character:Destroy()
	table.clear(self)
	table.freeze(self)
	for _, v in pairs(Combat_Data) do
		if type(v) == "table" then
			table.remove(v, table.find(v, self))
		end
	end
end



--[=[
	Cancels the current attack if the NPC is swinging. No-ops if Swing attribute is false.

	@within NPC
]=]
function npc:CancelAttack()
	if self.Character:GetAttribute("Swing") == false then return end
	CombatHelper.CancelAttack(self.Character, self)
end




--[=[
	Equips the NPC's current weapon (per its CurrentWeapon attribute) via EquipModule.
	@within NPC
]=]
function npc:EquipWeapon()
	EquipModule.EquipWeapon(self.Character, self)
end

--[=[
	Unequips the NPC's current weapon via EquipModule.
	@within NPC
]=]
function npc:UnequipWeapon()
	EquipModule.UnequipWeapon(self.Character, self)
end

--[=[
	Enables the NPC's Brain script, activating its behavior tree.
	@within NPC
]=]
function npc:Start()
	if self.Brain and self.Brain:IsA("Script") then
		self.Brain.Disabled = false
	end
end

--[=[
	Loads and plays the idle animation matching the NPC's current weapon. If an idle
	animation is already playing for this NPC, does nothing (prevents restarting the
	animation on repeated calls).
	@within NPC
]=]
function npc:Idle()
	if Combat_Data.IdleAnims[self] and Combat_Data.IdleAnims[self].IsPlaying then
		return
	end
	local hum = self.Character.Humanoid
	local CurrentWeapon = self.Character:GetAttribute("CurrentWeapon")
	Combat_Data.IdleAnims[self] = hum.Animator:LoadAnimation(WeaponAnimations[CurrentWeapon].Main.Idle)
	Combat_Data.IdleAnims[self]:Play()
end

--[=[
	Performs an attack via CombatHelper. No-ops if the NPC is currently transforming.
	@within NPC
]=]
function npc:Attack()
	if self.Character:GetAttribute("IsTransforming") then
		return
	end
	CombatHelper.Attack(self.Character, self)
end

--[=[
	Activates blocking via BlockModule. No-ops if the NPC is transforming or if
	HelpfullModule.CheckForAttributes reports a blocking-incompatible state.
	@within NPC
]=]
function npc:Block()
	if self.Character:GetAttribute("IsTransforming") then
		return
	end
	if HelpfullModule.CheckForAttributes(self.Character, true, true, true, nil, true, false, true, nil) then
		return
	end
	BlockModule.ActivateBlocking(self.Character, self)
end

--[=[
	Deactivates blocking via BlockModule. Same guard conditions as Block.
	@within NPC
]=]
function npc:Unblock()
	if self.Character:GetAttribute("IsTransforming") then
		return
	end
	if HelpfullModule.CheckForAttributes(self.Character, true, true, true, nil, true, false, true, nil) then
		return
	end
	BlockModule.DeactivateBlocking(self.Character, self)
end

--[=[
	Performs a dodge via DodgeModule using this NPC's MovementObj. No-ops if IsTransforming is set.

	@within NPC
]=]
function npc:Dodge()
	if self.Character:GetAttribute("IsTransforming") then
		return
	end
	DodgeModule.Dodge(self.MovementObj)
end

--[=[
	Attempts a parry via ParryModule. No-ops if transforming or if
	HelpfullModule.CheckForAttributes reports a parry-incompatible state.
	@within NPC
]=]
function npc:Parry()
	if self.Character:GetAttribute("IsTransforming") then
		return
	end
	if HelpfullModule.CheckForAttributes(self.Character, true, true, true, true, true, true, true, true) then
		return
	end
	ParryModule.ParryAttempt(self.Character, self)
end

--[=[
	Triggers a phase 2 transformation via ModeModule. No-ops if already transforming.
	@within NPC
]=]
function npc:Phase2()
	if self.Character:GetAttribute("IsTransforming") then
		return
	end
	ModeModule.Mode2(self.Character, self)
end

--[=[
	:::caution Not implemented
	Reserved wrapper for a future cast-ability module. Currently a no-op.
	:::
	@within NPC
]=]
function npc:CastAblity()
	-- My wrap round to use the already made cast ability module but i dont want to require it each time so i put it here
end

--[=[
	:::caution Not implemented
	Reserved wrapper for wall-jump movement. Currently a no-op.
	:::
	@within NPC
]=]
function npc:Climb()
	-- My wrap round to use the already made wall jump module but i dont want to require it each time so i put it here
end

--[=[
	:::caution Not implemented
	Reserved wrapper for wall-run movement. Currently just logs to console.
	:::
	@within NPC
]=]
function npc:WallRun()
	-- My wrap round to use the already made wall run module but i dont want to require it each time so i put it here
end

return npc
