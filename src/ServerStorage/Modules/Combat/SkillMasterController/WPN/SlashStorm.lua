local SlashStorm = {}

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")
local ServerStorage = game:GetService("ServerStorage")
local SoundService = game:GetService("SoundService")

local SSModules = SS.Modules
local Events = RS.Events

local MuchachoHitbox = require(SSModules.Hitboxes.MuchachoHitbox)
local Helpful = require(SSModules.Other.Helpful)
local StatFormulas = require(SSModules.Other.StatFormulas)
local WeaponStats = require(SSModules.Dictionaries.WeaponStats)
local IntentService = require(SSModules.Combat.IntentService)
local NpcModule = require(SSModules.Objects.npc)
local VFX_Event = Events.VFX
local SoundsModule = require(RS.Modules.Combat.SoundsModule)
local WeaponSounds = SoundService.SFX.Weapons

local SKILL_NAME = "SlashStorm"
local COOLDOWN = 8
local TARGET_INTERVAL = 0.1
local HITBOX_SIZE = Vector3.new(5, 5, 5)
local DURATION_CAP = 4
local WINDUP_FALLBACK = 0.2

local SkillsAnimations = RS.Animations:FindFirstChild("Skills")
local WPNAnimations = SkillsAnimations and SkillsAnimations:FindFirstChild("WPN")
local SlashStormAnim = WPNAnimations and WPNAnimations:FindFirstChild("SlashStorm")

local Cooldowns = {}
local ActiveStates = {}

function SlashStorm.OnHit(char, npc, state, hit, humanoid)
	if not humanoid then
		return
	end
	local eChar = humanoid.Parent
	if not eChar or eChar == char or not eChar:IsDescendantOf(workspace) then
		return
	end
	if humanoid.Health <= 0 then
		return
	end

	if state.targetCooldowns[eChar] and tick() - state.targetCooldowns[eChar] < TARGET_INTERVAL then
		return
	end
	state.targetCooldowns[eChar] = tick()

	local HRP = char:FindFirstChild("HumanoidRootPart")
	if not HRP then
		return
	end

	local currentWeapon = char:GetAttribute("CurrentWeapon")
	local weaponData = WeaponStats.getStats(currentWeapon)
	local Enpc = NpcModule.GetNpcFromCharacter(eChar)

	local stop = Helpful.CheckForStatus(
		eChar,
		char,
		Enpc,
		weaponData.BlockDmg,
		HRP.CFrame,
		true,
		true,
		true,
		false
	)
	if stop then
		return
	end

	local WPN_Points = StatFormulas.GetStat(char, "WPN", npc and npc.WPN)
	local P_eff = StatFormulas.WeaponPoints(WPN_Points)
	local damage = math.ceil(weaponData.Damage + P_eff * ((weaponData.Damage / 1000) * weaponData.Scaling))

	Helpful.DamageDealer(eChar, damage)

	VFX_Event:FireAllClients("CombatEffects", RS.Effects.Combat.Blood, hit.CFrame, 3)
	SoundsModule.PlaySound(WeaponSounds[currentWeapon].Combat.Hit, eChar:FindFirstChild("Torso") or hit)
end

function SlashStorm.SpawnHitbox(char, npc, state)
	if not state.active or state.cleaned then
		return
	end
	if not char.Parent then
		return
	end

	local HRP = char:FindFirstChild("HumanoidRootPart")
	if not HRP then
		return
	end

	local hitbox = MuchachoHitbox.CreateHitbox()
	state.hitbox = hitbox

	hitbox.DetectionMode = "ConstantDetection"
	hitbox.CFrame = HRP
	hitbox.Size = HITBOX_SIZE
	hitbox.Visualizer = true
	hitbox.AutoDestroy = false
	hitbox.Offset = CFrame.new(0, 0, -2.3)

	local params = OverlapParams.new()
	params.FilterDescendantsInstances = { char }
	params.FilterType = Enum.RaycastFilterType.Exclude
	hitbox.OverlapParams = params

	hitbox.Touched:Connect(function(hit, humanoid)
		SlashStorm.OnHit(char, npc, state, hit, humanoid)
	end)

	hitbox:Start()
end

function SlashStorm.start(char, npc)
	if not char or not char:FindFirstChildOfClass("Humanoid") then
		return
	end

	local plr = Players:GetPlayerFromCharacter(char)
	local identifier = plr or npc
	if not identifier then
		return
	end

	if Cooldowns[identifier] and tick() - Cooldowns[identifier] < COOLDOWN then
		return
	end

	if Helpful.CheckForAttributes(char, true, true, true, true, true, true, true, nil, true) then
		return
	end

	if Helpful.ManageStamina(char, "Skill", SKILL_NAME) then
		return
	end

	local HRP = char:FindFirstChild("HumanoidRootPart")
	if not HRP then
		return
	end

	Cooldowns[identifier] = tick()

	local hum = char.Humanoid
	local state = {
		active = true,
		cleaned = false,
		hitbox = nil,
		animTrack = nil,
		targetCooldowns = {},
	}

	ActiveStates[identifier] = state

	IntentService.SetIntent(char, npc, SKILL_NAME)
	char:SetAttribute("Attacking", true)

	local function cleanup()
		if state.cleaned then
			return
		end
		state.cleaned = true
		state.active = false

		if state.hitbox then
			pcall(function()
				state.hitbox:Stop()
			end)
			state.hitbox = nil
		end

		if state.animTrack then
			pcall(function()
				state.animTrack:Stop()
			end)
			state.animTrack = nil
		end

		if char.Parent then
			IntentService.SetIntent(char, npc, "None")
			char:SetAttribute("Attacking", false)
		end

		ActiveStates[identifier] = nil
	end

	state.cleanup = cleanup

	local function play()
		if SlashStormAnim and char.Parent then
			local track = hum.Animator:LoadAnimation(SlashStormAnim)
			state.animTrack = track

			local hitStartConn = track:GetMarkerReachedSignal("HitboxStart"):Connect(function()
				SlashStorm.SpawnHitbox(char, npc, state)
			end)
			local hitEndConn = track:GetMarkerReachedSignal("HitboxEnd"):Connect(cleanup)

			track.Stopped:Connect(function()
				hitStartConn:Disconnect()
				hitEndConn:Disconnect()
				cleanup()
			end)

			track:Play()
		else
			task.delay(WINDUP_FALLBACK, function()
				if state.active then
					SlashStorm.SpawnHitbox(char, npc, state)
				end
			end)
		end

		task.delay(DURATION_CAP, function()
			cleanup()
		end)
	end

	play()

	return function()
		cleanup()
	end
end

function SlashStorm.stop(char, npc)
	if not char then
		return
	end

	local plr = Players:GetPlayerFromCharacter(char)
	local identifier = plr or npc
	local state = ActiveStates[identifier]

	if state and state.cleanup then
		state.cleanup()
	end
end

return SlashStorm
