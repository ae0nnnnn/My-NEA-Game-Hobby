local module = {}

local Debris = game:GetService("Debris")
local RS = game:GetService("ReplicatedStorage")
local TS = game:GetService("TweenService")
local PLayers = game:GetService("Players")
local RunService = game:GetService("RunService")
local uis = game:GetService("UserInputService")
local localplr = PLayers.LocalPlayer
local cam = workspace.CurrentCamera


local hiddenElements = {}
local TOP_HIDDEN = UDim2.new(-0.001, 0, -0.4, 0)
local BOTTOM_HIDDEN = UDim2.new(-0.034, 0, 1.1, 0)

local function Shiftoff(char)
	local hum = char.Humanoid
	uis.MouseBehavior = Enum.MouseBehavior.Default
	localplr.CameraMode = Enum.CameraMode.Classic
	hum.AutoRotate = false
end

function module.HideUI(char)
	local plr = PLayers:GetPlayerFromCharacter(char)

	if plr and plr == localplr then
		local playerGui = plr:FindFirstChild("PlayerGui")
		if playerGui then
			for _, gui in ipairs(playerGui:GetChildren()) do
				if gui:IsA("ScreenGui") and gui.Enabled and gui.Name ~= "MovementUI" then
					gui.Enabled = false
					table.insert(hiddenElements, gui)
				end
			end
		end
	end

	if char then
		for _, gui in ipairs(char:GetDescendants()) do
			if (gui:IsA("BillboardGui") or gui:IsA("SurfaceGui")) and gui.Enabled then
				gui.Enabled = false
				table.insert(hiddenElements, gui)
			end
		end
	end
end

function module.TweenBars(char)
	local plr = PLayers:GetPlayerFromCharacter(char)
	local Top = nil
	local Bottom = nil
	local TOP_Dest = UDim2.new(-0.001, 0, -0.187, 0)
	local BOTTOM_Dest = UDim2.new(-0.034, 0, 0.75, 0)
	local tweenSlide = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)

	if plr and plr == localplr then
		local PlayerGui = plr:FindFirstChildOfClass("PlayerGui")
		local MovementUI = PlayerGui:FindFirstChild("MovementUI")

		if MovementUI then
			Top = MovementUI:FindFirstChild("Top") :: Frame
			Bottom = MovementUI:FindFirstChild("Bottom") :: Frame

			local tweenTop = TS:Create(Top, tweenSlide, { Position = TOP_Dest })
			local tweenBottom = TS:Create(Bottom, tweenSlide, { Position = BOTTOM_Dest })

			tweenTop:Play()
			tweenBottom:Play()
		end
	end
end

function module.ResetBars(char)
	local plr = PLayers:GetPlayerFromCharacter(char)
	local Top = nil
	local Bottom = nil

	local tweenSlide = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)

	if plr and plr == localplr then
		local PlayerGui = plr:FindFirstChildOfClass("PlayerGui")
		local MovementUI = PlayerGui:FindFirstChild("MovementUI")

		if MovementUI then
			Top = MovementUI:FindFirstChild("Top")
			Bottom = MovementUI:FindFirstChild("Bottom")

			local tweenTop = TS:Create(Top, tweenSlide, { Position = TOP_HIDDEN })
			local tweenBottom = TS:Create(Bottom, tweenSlide, { Position = BOTTOM_HIDDEN })

			tweenTop:Play()
			tweenBottom:Play()
		end
	end
end

function module.ShowUI()
	for _, gui in ipairs(hiddenElements) do
		if gui and gui.Parent then
			gui.Enabled = true
		end
	end
	table.clear(hiddenElements)
end

function module.EmitEffect(Targeteffect, cframe, destroytime)
	local effect = Targeteffect:Clone()
	effect.Parent = workspace.VFX
	effect.CFrame = cframe

	for _, v in pairs(effect:GetDescendants()) do
		if v:isA("ParticleEmitter") then
			v:Emit(v:GetAttribute("EmitCount"))
		end
	end

	Debris:AddItem(effect, destroytime)
end


function module.Highlight(char, duration, FillColor, OutlineColor, buggedver)
	buggedver = buggedver or false

	local Highlight = Instance.new("Highlight")
	Highlight.Parent = char
	Highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	Highlight.FillTransparency = not buggedver and 0 or -4
	Highlight.FillColor = FillColor
	Highlight.OutlineTransparency = 1
	Highlight.OutlineColor = OutlineColor
		if buggedver then
		-- proportional snap: 45% to pop out of -1 -> 0, 55% nice fade 0 -> 1 + outline
		local snapDuration = duration * 0.45
		local fadeDuration = duration - snapDuration
		local snapTween = TS:Create(Highlight, TweenInfo.new(snapDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { FillTransparency = 0 })
		snapTween:Play()
		snapTween.Completed:Connect(function()
			if Highlight.Parent then
				TS:Create(Highlight, TweenInfo.new(fadeDuration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { FillTransparency = 1, OutlineTransparency = 1 }):Play()
			end
		end)
	else
		local TweenGoal = { FillTransparency = 1, OutlineTransparency = 1 }
		TS:Create(Highlight, TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), TweenGoal):Play()
	end
	Debris:AddItem(Highlight, duration)

end

function module.triggerEffects(parentObject, char, customOffset)
	local HRP = char:FindFirstChild("HumanoidRootPart")
	if not HRP then
		warn("No HRP found!")
		return
	end

	local EffectPart = parentObject:Clone()
	EffectPart.Parent = workspace.VFX
	EffectPart:SetAttribute("OwnerCharacter", char.Name)

	local offsetCFrame = customOffset or CFrame.new(0, 0, -0.894)
	EffectPart.CFrame = HRP.CFrame * offsetCFrame * (parentObject.CFrame - parentObject.Position)

	local cleanupTime = 0

	for _, instance in ipairs(EffectPart:GetDescendants()) do
		if instance:IsA("ParticleEmitter") or instance:IsA("Beam") or instance:IsA("Sound") then
			task.spawn(function()
				if not instance.Parent then
					return
				end

				local delay = instance:GetAttribute("EmitDelay") or 0
				local duration = instance:GetAttribute("EmitDuration")

				if delay + (duration or 0) > cleanupTime then
					cleanupTime = delay + (duration or 0)
				end

				if delay > 0 then
					task.wait(delay)
				end
				if not instance.Parent then
					return
				end

				if instance:IsA("Sound") then
					instance:Play()
					if instance.TimeLength > cleanupTime then
						cleanupTime = instance.TimeLength
					end
				elseif instance:IsA("ParticleEmitter") then
					local count = instance:GetAttribute("EmitCount")

					if duration and duration > 0 then
						instance.Enabled = true
						task.wait(duration)
						if instance.Parent then
							instance.Enabled = false
						end
					elseif count and count > 0 then
						instance:Emit(count)
					else
						instance:Emit(1)
					end
				elseif instance:IsA("Beam") then
					local beamClone = instance:Clone()
					beamClone.Parent = instance.Parent
					beamClone.Enabled = true

					local beamDuration = duration and duration > 0 and duration or 0.03
					task.wait(beamDuration)

					if beamClone then
						beamClone:Destroy()
					end
				end
			end)
		end
	end

	task.delay(cleanupTime + 1, function()
		if EffectPart then
			EffectPart:Destroy()
		end
	end)
	return EffectPart
end

function module.AfterImage(char, anim, type)
	if type == nil then
		local clone = RS.Effects.AfterImage:Clone()
		clone.Parent = workspace.VFX
		clone.HumanoidRootPart.CFrame = char.HumanoidRootPart.CFrame

		task.delay(0.09, function()
			local humanoid = clone:FindFirstChildOfClass("Humanoid")
			if not humanoid or not humanoid.Animator then
				return
			end

			local animTrack = clone.Humanoid.Animator:LoadAnimation(anim)
			animTrack:Play()

			-- Fade out all parts
			local fadeInfo = TweenInfo.new(0.3, Enum.EasingStyle.Linear)
			local tweensLeft = 0

			for _, part in ipairs(clone:GetDescendants()) do
				if part:IsA("BasePart") then
					tweensLeft += 1
					local t = TS:Create(part, fadeInfo, { Transparency = 1 })
					t.Completed:Connect(function()
						tweensLeft -= 1
						if tweensLeft <= 0 then
							clone:Destroy()
						end
					end)
					t:Play()
				end
			end

			-- Fade highlight outline too
			local highlight = clone:FindFirstChildOfClass("Highlight")
			if highlight then
				TS:Create(highlight, fadeInfo, {
					FillTransparency = 1,
					OutlineTransparency = 1,
				}):Play()
			end
		end)
	else
		if type == "AstralDodge" then
			char.Archivable = true

			local function GetDodgeTrack(char)
				local letter = char:GetAttribute("CurrentMoveKey") or "W"
				if letter == "None" then letter = "W" end
				return RS.Animations.Weapons.ShootingStar.Dodging[letter] or RS.Animations.Weapons.ShootingStar.Dodging.W
			end

			local sourceTrack = GetDodgeTrack(char)

			local Colors = {
				{ Fill = Color3.fromRGB(119, 0, 255), Outline = Color3.fromRGB(113, 5, 255) },
				{ Fill = Color3.fromRGB(170, 0, 255), Outline = Color3.fromRGB(140, 0, 200) },
				{ Fill = Color3.fromRGB(80, 0, 200), Outline = Color3.fromRGB(60, 0, 180) },
				{ Fill = Color3.fromRGB(200, 50, 255), Outline = Color3.fromRGB(170, 30, 220) },
				{ Fill = Color3.fromRGB(50, 100, 255), Outline = Color3.fromRGB(30, 80, 220) },
			}

			local FillTransparency = -1 -- was
			local BlinkCycles = 3
			local BlinkStepDuration = 0.07

			local DodgeDuration = 0.25
			local CloneInterval = 0.04
			local CloneCount = math.max(1, math.floor(DodgeDuration / CloneInterval))

			coroutine.wrap(function()
				for i = 1, CloneCount do
					task.wait(CloneInterval)
					if not char then break end

					local clone = char:Clone() :: Model
					clone.Humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
					clone.Name = "AfterImage"..char.Name

					local colorIndex = (i - 1) % #Colors + 1
					local startColor = Colors[colorIndex]
					local nextColor = Colors[colorIndex % #Colors + 1]

					local Highlight = clone:FindFirstChildOfClass("Highlight") or Instance.new("Highlight")
					Highlight.Parent = clone
					Highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop  -- was occluded
					Highlight.FillTransparency = FillTransparency
					Highlight.FillColor = startColor.Fill
					Highlight.OutlineTransparency =  1  -- was 0.5
					Highlight.OutlineColor = startColor.Outline

					local PointLight = Instance.new("PointLight", clone.HumanoidRootPart)
					PointLight.Brightness = 2.5
					PointLight.Color = startColor.Fill
					PointLight.Range = 6
					PointLight.Shadows = false

					for _, part in pairs(clone:GetDescendants()) do
						if part:IsA("Script") or part:IsA("LocalScript") or part:IsA("ModuleScript") or part:IsA("BillboardGui") then
							part:Destroy()
						end
						if part:IsA("Decal") or part:IsA("Texture") then
							part:Destroy()
						end
						if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
							if part:IsA("MeshPart") then part.TextureID = "" end
							part.Transparency = 0.5
							part.CollisionGroup = "VFX_Models"
							part.CanCollide = false
							part.Anchored = true
							part.Color = startColor.Outline
						end
					end

					clone.Parent = workspace.VFX
					clone.HumanoidRootPart.Transparency = 1
					clone.HumanoidRootPart.CFrame = char.HumanoidRootPart.CFrame
					clone.HumanoidRootPart.Anchored = true

					if sourceTrack then
						local animTrack = clone.Humanoid.Animator:LoadAnimation(sourceTrack)
						animTrack:Play(0)
						animTrack:AdjustSpeed(0)
						animTrack.TimePosition = 0.12
					end

					TS:Create(Highlight, TweenInfo.new(1.2, Enum.EasingStyle.Linear), {
						FillColor = nextColor.Fill,
						OutlineColor = nextColor.Outline,
					}):Play()

				

					TS:Create(PointLight, TweenInfo.new(1.2, Enum.EasingStyle.Linear), {
						Color = nextColor.Fill,
					}):Play()

					task.delay(0.15 + (i * 0.02), function()
						if not clone then return end

						coroutine.wrap(function()
							local blinkParts = {}
							local baseCFrames = {}
							for _, part in ipairs(clone:GetDescendants()) do
								if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
									table.insert(blinkParts, part)
									baseCFrames[part] = part.CFrame
								end
							end

							local function BlinkAll(partTransparency)
								for _, part in ipairs(blinkParts) do
									TS:Create(part, TweenInfo.new(BlinkStepDuration, Enum.EasingStyle.Linear), {
										Transparency = partTransparency,
									}):Play()
								end
							end

							local vibrating = true
							task.spawn(function()
								while vibrating do
									local offset = Vector3.new(
										(math.random() - 0.8) * 0.4,
										(math.random() - 0.8) * 0.4,
										(math.random() - 0.8) * 0.4
									)
									for _, part in ipairs(blinkParts) do
										part.CFrame = baseCFrames[part] * CFrame.new(offset)
									end
									task.wait(1 / 50)
								end
								for _, part in ipairs(blinkParts) do
									part.CFrame = baseCFrames[part]
								end
							end)

							for _ = 1, BlinkCycles do
								if not clone then return end
								local blinkOut = TS:Create(Highlight, TweenInfo.new(BlinkStepDuration, Enum.EasingStyle.Linear), {
									FillTransparency = 1,
								})
								BlinkAll(1)
								blinkOut:Play()
								blinkOut.Completed:Wait()

								if not clone then return end
								local blinkIn = TS:Create(Highlight, TweenInfo.new(BlinkStepDuration, Enum.EasingStyle.Linear), {
									FillTransparency = FillTransparency,
								})
								BlinkAll(0.5)
								blinkIn:Play()
								blinkIn.Completed:Wait()
							end

							vibrating = false
							task.wait()

							if not clone then return end

							for _, part in ipairs(clone:GetDescendants()) do
								if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
									local randDir = Vector3.new(
										math.random(-100, 100) / 100,
										math.random(20, 60) / 100,
										math.random(-100, 100) / 100
									).Unit
									local targetPos = part.Position + randDir * math.random(3, 8) + Vector3.new(0, math.random(2, 5), 0)
									local targetSize = part.Size * math.random(110, 130) / 100

									TS:Create(part, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
										CFrame = CFrame.new(targetPos) * part.CFrame.Rotation,
										Size = targetSize,
									}):Play()

									TS:Create(part, TweenInfo.new(0.2, Enum.EasingStyle.Linear), {
										Transparency = 1,
									}):Play()
								end
							end

							local fadeOut = TS:Create(Highlight, TweenInfo.new(0.2, Enum.EasingStyle.Linear), {
								FillTransparency = 1,
								OutlineTransparency = 1,
							})
							fadeOut.Completed:Connect(function()
								if clone then clone:Destroy() end
							end)
							fadeOut:Play()

							if PointLight then
								TS:Create(PointLight, TweenInfo.new(0.2, Enum.EasingStyle.Linear), {
									Brightness = 0,
								}):Play()
							end
						end)()
					end)
				end
			end)()
		end
	end
end

function module.HighlightBlink(target, fillcolor, duration, blinkSpeed)
	if not target then return end
	print("Started highlight", target)
	local hl = Instance.new("Highlight")
	hl.FillColor = fillcolor
	hl.OutlineColor = fillcolor
	hl.FillTransparency = 0
	hl.OutlineTransparency = 0
	hl.Parent = target
	hl.DepthMode = Enum.HighlightDepthMode.Occluded

	-- True sync: duration-scaled tween so visual ends exactly when window ends (6f 0.10s hypr)
	-- For short durations (hypr 0.1) do single flash; for long durations (status 5s) loop with blinkSpeed
	if duration <= 0.3 then
		local half = duration / 2
		local outTween = TS:Create(hl, TweenInfo.new(half, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { FillTransparency = 0.5, OutlineTransparency = 0.5 })
		outTween:Play()
		task.wait(half)
		if hl.Parent then
			local inTween = TS:Create(hl, TweenInfo.new(half, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { FillTransparency = 0, OutlineTransparency = 0 })
			inTween:Play()
		end
		Debris:AddItem(hl, duration)
		task.delay(duration, function()
			print("Finished highlight")
		end)
		return
	end

	local elapsed = 0
	local blinkTime = blinkSpeed or 0.5
	local halfCycle = blinkTime / 2
	while elapsed < duration do
		if not hl.Parent then break end
		local blinkTween = TS:Create(hl, TweenInfo.new(halfCycle, Enum.EasingStyle.Linear), { FillTransparency = 0.5, OutlineTransparency = 0.5 })
		blinkTween:Play()
		blinkTween.Completed:Wait()
		if not hl.Parent then break end
		local resetTween = TS:Create(hl, TweenInfo.new(halfCycle, Enum.EasingStyle.Linear), { FillTransparency = 0, OutlineTransparency = 0 })
		resetTween:Play()
		resetTween.Completed:Wait()
		elapsed += blinkTime
	end
	if hl.Parent then hl:Destroy() end
	print("Finished highlight")
end

function module.HyprVfx(char, echar, isMainSource)
	if not char then
		return
	end
	local HRP: BasePart = char:FindFirstChild("HumanoidRootPart")
	if not HRP then
		return
	end

	local Middlepart
	if isMainSource then
		local VFXpart = RS.Effects.Combat.HyprParryVFX
		Middlepart = module.triggerEffects(VFXpart, char, CFrame.new(-0.861, -0.1, -1.948))
	end

	local hl = Instance.new("Highlight")
	hl.FillTransparency = 0.9
	hl.OutlineTransparency = 0.2
	hl.OutlineColor = Color3.fromRGB(216, 181, 55)
	hl.Parent = char

	Debris:AddItem(hl, 0.5)

	local plrflag = PLayers:GetPlayerFromCharacter(char)

	-- 4.7: parried person (isMainSource == false) gets highlight only — no cam/bars/UI so they can focus on hypr-parrying the revenge
	if not isMainSource then
		return
	end

	if plrflag ~= localplr then
		return
	end

	Shiftoff(char)

	local middlePosition: Vector3 = HRP.Position

	if Middlepart then
		local middleAttachment = Middlepart:FindFirstChild("Middle", true)
		if middleAttachment then
			middlePosition = middleAttachment.WorldPosition
		else
			middlePosition = Middlepart.Position
		end
	elseif echar and echar:FindFirstChild("HumanoidRootPart") then
		middlePosition = HRP.Position:Lerp(echar.HumanoidRootPart.Position, 0.5)
	end

	do
		localplr.CameraMode = Enum.CameraMode.Classic

		local PlayerScripts = localplr:FindFirstChild("PlayerScripts")
		local PlayerModule = PlayerScripts and PlayerScripts:FindFirstChild("PlayerModule")
		if PlayerModule then
			local CameraModule = require(PlayerModule):GetCameras()
			if CameraModule and CameraModule.activeMouseLockController then
				CameraModule.activeMouseLockController:EnableMouseLock(false)
			end
		end

		local baseOrientation = HRP.CFrame - HRP.CFrame.Position
		local camoffset = Vector3.new(8, -2.5, 13)
		local camworldpos = HRP.Position + baseOrientation:VectorToWorldSpace(camoffset)
		-- 4.7: +2 lift with -2.5 down cam restores low-angle "looking up at middle" (aggressive)
		local lookAtPos = middlePosition + Vector3.new(0, 2, 0)
		local TargetCframe = CFrame.lookAt(camworldpos, lookAtPos)
		module.TweenBars(char)

		cam.CameraType = Enum.CameraType.Scriptable
		-- 4.7: 0.1s tween into position rather than snap
		TS:Create(cam, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = TargetCframe }):Play()
		cam.FieldOfView = 55
		module.HideUI(char)

		task.wait(0.2)

		local trackingConnection
		local fovInfo = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local fovTween = TS:Create(cam, fovInfo, { FieldOfView = 70 })

		trackingConnection = RunService.RenderStepped:Connect(function()
			if char and char.Parent and echar and echar.Parent then
				local currentHRP = char.HumanoidRootPart
				local currentEHRP = echar.HumanoidRootPart

				local liveMiddle = currentHRP.Position:Lerp(currentEHRP.Position, 0.5) + Vector3.new(0, 2, 0)
				-- 4.7: re-derive orientation live (lost during loop update) instead of frozen baseOrientation
				local liveOrientation = currentHRP.CFrame - currentHRP.CFrame.Position
				local baseCamWorldPos = currentHRP.Position + liveOrientation:VectorToWorldSpace(camoffset)
				-- 4.7: glide back as defender slides from knockback — extra pull scales with separation
				local diff = currentEHRP.Position - currentHRP.Position
				local dist = diff.Magnitude
				local dir: Vector3 = if dist > 0 then diff.Unit else currentHRP.CFrame.LookVector
				local extraPull = math.clamp((dist - 3.5) * 0.15, 0, 6)
				local liveCamWorldPos = baseCamWorldPos - dir * extraPull

				cam.CFrame = CFrame.lookAt(liveCamWorldPos, liveMiddle)
			else
				trackingConnection:Disconnect()
			end
		end)

		fovTween:Play()
		

		fovTween.Completed:Connect(function()
			if trackingConnection then
				trackingConnection:Disconnect()
			end
			cam.CameraType = Enum.CameraType.Custom

			localplr.CameraMode = Enum.CameraMode.Classic

			local PlayerScripts = localplr:FindFirstChild("PlayerScripts")
			local PlayerModule = PlayerScripts and PlayerScripts:FindFirstChild("PlayerModule")
			if PlayerModule then
				local CameraModule = require(PlayerModule):GetCameras()
				if CameraModule and CameraModule.activeMouseLockController then
					CameraModule.activeMouseLockController:EnableMouseLock(true)
				end
			end

			char.Humanoid.AutoRotate = true
			module.ShowUI()
			module.ResetBars(char)
		end)
	end
end

function module.DestroyEffects (char, effect)
	for _, v in pairs(workspace.VFX:GetChildren()) do
		if v.Name == effect.Name and v:GetAttribute("OwnerCharacter") == char.Name then
			v:Destroy()
		end
	end
end

local ActiveTrails = setmetatable({}, { __mode = "k" })

function module.Trail(char: Model, duration: number?)
	local TrailFX = RS.Effects.Movement.Trail

	local Parts = {
		"Left Arm",
		"Right Arm",
		"Left Leg",
		"Right Leg",
	}

	local function Create(part)
		local Attachment0 = (TrailFX.Attachment1):Clone()
		local Attachment1 = (TrailFX.Attachment2):Clone()
		local TrailInstance = (TrailFX.Trail):Clone()

		Attachment0.Parent = part
		Attachment1.Parent = part

		TrailInstance.Attachment0 = Attachment0
		TrailInstance.Attachment1 = Attachment1

		TrailInstance.Parent = part

		return {
			Attachment0 = Attachment0,
			Attachment1 = Attachment1,
			Trail = TrailInstance,
		}
	end

	if not char then return end

	local HumanoidRootPart = char:FindFirstChild("HumanoidRootPart") :: BasePart
	if not HumanoidRootPart then return end

	local Created = {}

	for _, part in Parts do
		local prt = char:FindFirstChild(part)
		if prt then
			table.insert(Created, Create(prt))
		end
	end

	local stopped = false
	local function Stop()
		if stopped then return end
		stopped = true
		for _, VFX in Created do
			VFX.Trail.Enabled = false
		end
		task.delay(0.4, function()
			for _, VFX in Created do
				VFX.Attachment0:Destroy()
				VFX.Attachment1:Destroy()
				VFX.Trail:Destroy()
			end
		end)
	end

	if duration then
		task.delay(duration, Stop)
	else
		local existing = ActiveTrails[char]
		if existing then
			existing()
		end
		ActiveTrails[char] = Stop
	end
end

function module.StopTrails(char: Model)
	local stop = ActiveTrails[char]
	if stop then
		ActiveTrails[char] = nil
		stop()
	end
end

-- Run the function.

return module
