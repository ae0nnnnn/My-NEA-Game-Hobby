local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Events = RS.Events
local MovementEvent: RemoteEvent = Events.Movement

MovementEvent.OnClientEvent:Connect(function(action)
    local localPlayer = Players.LocalPlayer
    local char = localPlayer.Character
    if not char then return end

    if action == "HyprParry" then
        local HRP: BasePart = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not HRP or not hum then return end

        hum.AutoRotate = false

        local att = HRP:FindFirstChild("HyprAtt") or Instance.new("Attachment")
        att.Name = "HyprAtt"
        att.Parent = HRP

        local ao = Instance.new("AlignOrientation")
        ao.Name = "HyprAlign"
        ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
        ao.Attachment0 = att
        ao.CFrame = HRP.CFrame
        ao.MaxTorque = math.huge
        ao.Responsiveness = 200 
        ao.Parent = HRP

        local backwardDirection = -HRP.CFrame.LookVector

        local popUpwardForce = 24
        local popBackwardForce = 40
        local impulseVector = (backwardDirection * popBackwardForce) + Vector3.new(0, popUpwardForce, 0)
        HRP:ApplyImpulse(impulseVector * HRP:GetMass())

        local slideSpeed = 75
        local lv = Instance.new("LinearVelocity")
        lv.Name = "HyprForce"
        lv.Attachment0 = att
        lv.MaxForce = math.huge
        lv.VectorVelocity = backwardDirection * slideSpeed
        lv.Parent = HRP

        game:GetService("Debris"):AddItem(lv, 0.25)
        game:GetService("Debris"):AddItem(ao, 0.25)
        game:GetService("Debris"):AddItem(att, 0.25)

        task.delay(0.25, function()
            if hum and hum.Parent then
                hum.AutoRotate = true
            end
        end)
    end
end)
