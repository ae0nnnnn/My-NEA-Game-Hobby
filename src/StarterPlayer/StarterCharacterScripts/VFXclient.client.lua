

local RS = game:GetService("ReplicatedStorage")


local cam = workspace.CurrentCamera

local CameraShakerModule  = require(RS.Modules.CameraShaker)
local camShake = CameraShakerModule.new(Enum.RenderPriority.Camera.Value, function(shakecf)
	cam.CFrame = cam.CFrame * shakecf
end)

camShake:Start()



RS.Events.VFX.OnClientEvent:Connect(function(action,...)
	if action  == "CustomShake" then
		local magnitude, roughness, fadeInTime, fadeOutTime = ...
		
		camShake:ShakeOnce(magnitude, roughness, fadeInTime, fadeOutTime)
	end
end)