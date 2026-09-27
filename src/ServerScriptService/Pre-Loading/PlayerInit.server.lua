



local Players = game:GetService("Players")
local SS = game:GetService("ServerStorage")
local SSModules = SS.Modules
local PLRModule = require(SSModules.Objects.plr)
local InventoryManager = require(SS.Modules.Other.InventoryManager)

Players.PlayerAdded:Connect(function(plr)
	plr.CharacterAdded:Connect(function(char)
		char:SetAttribute("Iframes", true)
		task.wait(0.01)
		local oldPLR = PLRModule.GetPLRFromPlayer(plr)
		if oldPLR then
			oldPLR:Cleanup()
		end
		local obj = PLRModule.new(plr, "SLOT_1")
		task.wait(0.1)
		InventoryManager.LoadInventory(plr)
		print(`{plr.UserId} has created their plr --> {obj}`)
	end)
end)


Players.PlayerRemoving:Connect(function(plr)
	local PLR = PLRModule.GetPLRFromPlayer(plr)
	if PLR then
		PLR:Destroy()
	end
end)