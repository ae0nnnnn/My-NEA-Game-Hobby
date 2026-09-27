local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")
local ContentProvider = game:GetService("ContentProvider")

-- Gather all animations + partition for explicit combat preload
local allAnims = {}
local combatAnims = {}
local seenIds = {}

for _, anim in ipairs(RS:WaitForChild("Animations"):GetDescendants()) do
	if anim:IsA("Animation") then
		if not seenIds[anim.AnimationId] then
			seenIds[anim.AnimationId] = true
			table.insert(allAnims, anim)
			-- Classify combat anims: anything under Weapons.Combat/Blocking/Hit/Main or Skills
			local full = anim:GetFullName():lower()
			if full:find("combat") or full:find("blocking") or full:find("%.hit") or full:find("main") or full:find("skills") or full:find("dodge") -- dodge hit react reuse
			then
				table.insert(combatAnims, anim)
			end
		end
	end
end

-- Explicit combat preload first so server scripts calling Swing/Hit/Block never hitch
if #combatAnims > 0 then
	pcall(function() ContentProvider:PreloadAsync(combatAnims) end)
end
if #allAnims > 0 then
	pcall(function() ContentProvider:PreloadAsync(allAnims) end)
end

-- Function to warm up a humanoid's animator
local function WarmUpAnimations(humanoid, animList)
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	local list = animList or allAnims
	for _, anim in ipairs(list) do
		local success, track = pcall(function()
			return animator:LoadAnimation(anim)
		end)
		if success and track then
			track:Stop(0)
			track:Destroy()
		end
	end
end

-- Listen for players joining
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if humanoid then
			task.wait(0.2)
			WarmUpAnimations(humanoid, combatAnims) -- combat first
			task.wait(0.05)
			WarmUpAnimations(humanoid, allAnims)
		end
	end)
end)

-- Expose for NPC creation to call directly (avoids race where npc attacks before warmup)
-- Usage: require(SS.Modules.Other.Helpful).WarmupNPC?(humanoid) or direct call here if required
-- We listen for NPC models added via ServerStorage npc.new path: hook humanoid ready
-- Lazy hook: if an NPC model is parented to workspace.NPC later, warmup on demand
local npcFolder = workspace:FindFirstChild("NPC")
if npcFolder then
	npcFolder.ChildAdded:Connect(function(model)
		task.wait(0.2)
		local hum = model:FindFirstChildOfClass("Humanoid")
		if hum then WarmUpAnimations(hum, combatAnims) end
	end)
end

-- Also expose globally for npc.lua to call explicitly if desired
_G.WarmUpCombatAnimations = function(humanoid)
	if humanoid then WarmUpAnimations(humanoid, combatAnims) end
end
