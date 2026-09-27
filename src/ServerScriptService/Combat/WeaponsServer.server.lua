-- [Global Varilbles]
local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")
local ServerStorage = game:GetService("ServerStorage")


local Events = RS.Events
local SSModules = SS.Modules

local WeaponsEvent = Events.WeaponsEvent
local BlockingEvent = Events.Blocking
local TransformEvent = Events.Tranform
local updateEvent = Events.UpdateMovement

local HelpfullModule = require(SSModules.Other.Helpful)
local Combat_Data = require(SSModules.Combat.Data.CombatData)
local Mode_Module = require(SSModules.Combat.Mode_Module)
local PlrObjectService = require(SSModules.Objects.plr)
local BlockModule = require(ServerStorage.Modules.BlockModule)
local ParryModule = require(ServerStorage.Modules.Parrying)
local EquipModule = require(ServerStorage.Modules.Combat.EquipModule)

-- Local Tables
local EquipDebounce = Combat_Data.EquipDebounce





WeaponsEvent.OnServerEvent:Connect(function(plr, action)
	local char = plr.Character


	if HelpfullModule.CheckForAttributes(char, true, true, true, true, nil, true, true, nil) then
		return
	end
	print(EquipDebounce[plr])

	if action == "Equip/UnEquip" and not char:GetAttribute("Equipped") and not EquipDebounce[plr] then
		print(EquipDebounce[plr])
		EquipModule.EquipWeapon(char)
	elseif action == "Equip/UnEquip" and char:GetAttribute("Equipped") and not EquipDebounce[plr] then
		EquipModule.UnequipWeapon(char)
	end
end)


BlockingEvent.OnServerEvent:Connect(function(plr, action)
	local char = plr.Character

	char:SetAttribute("HoldingBlock", action ~= "UnBlocking")

	if HelpfullModule.CheckForAttributes(char, true, false, true, nil, true, false, true, nil) then
		return
	end

	if action == "Blocking" then
		BlockModule.ActivateBlocking(char)
	elseif action == "UnBlocking" and char:GetAttribute("IsBlocking") then
		BlockModule.DeactivateBlocking(char)
	elseif
		action == "Parry"
		and not char:GetAttribute("IsBlocking")
		and not char:GetAttribute("Parrying")
	then
		ParryModule.ParryAttempt(char)
	end
end)

TransformEvent.OnServerEvent:Connect(function(plr, action)
	local char = plr.Character
	if HelpfullModule.CheckForAttributes(char, true, true, true, nil, true, true, true, nil) then
		return
	end

	if action == "Mode 1" then
		Mode_Module.Mode1(char)
	elseif action == "Mode 2" and char:GetAttribute("Mode1") then
		Mode_Module.Mode2(char)
	elseif action == "Revert" then
		Mode_Module.Revert(char)
	end
end)

updateEvent.OnServerEvent:Connect(function(player, keyName)
	local character = player.Character
	local PLROBJ = PlrObjectService.GetPLRFromPlayer(player)
	local moveflag = PLROBJ.HasMoved

	if moveflag == false then
		PLROBJ:FirstMovement()
	end


	if character then
		character:SetAttribute("CurrentMoveKey", keyName)
	end
end)
