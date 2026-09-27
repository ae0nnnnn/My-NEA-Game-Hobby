
local module = {}
local info ={
	["Time"]={
		Mode1 = "DrakeFang",
		Mode2 = "TwinSpears",
		Mode2Callout = "...",
		Text = {
			"<h>Asmondaios<h><sound:rbxassetid://98570702510642>It seems I need to drop the funny guy act huh<sound:rbxassetid://98570702510642>",
			"<h>Lunara<h><sound:rbxassetid://137940291335732> Well no, doofus<sound:rbxassetid://137940291335732>",
			"<h>Asmondaios<h><sound:rbxassetid://98570702510642><shake>Ow !</shake> my Bad, So we need to pull out all the stops then<sound:rbxassetid://98570702510642>",
			"<h>???<h><shake><colour:#FF0000>Crazy</colour:#FF0000></shake> monkey!",			
		}
	},
	
	["Astral"]={
		Mode1 = "Fractured_Kunai",
		Mode2 = "ShootingStar",
		Text = {
			"Hello"


		}
	},
	
	["Brute"]={
		Mode1 = "Hakuda",
		Mode2 = "OGA",
		Text = {
			""

		}
	},

	


}
function module.getStats(Element)
	return info[Element]
end
return module

