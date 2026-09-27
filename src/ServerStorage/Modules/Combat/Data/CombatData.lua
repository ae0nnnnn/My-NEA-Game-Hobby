local CombatData = {}
CombatData.Welds = {}
CombatData.EquipAnims = {}
CombatData.UnEquipAnims = {}
CombatData.IdleAnims = {}
CombatData.BlockingAnims = {}
CombatData.TransformAnims = {}
CombatData.ParryAnims = {}
CombatData.DodgeAnims = {}
CombatData.EquipDebounce = {}
CombatData.DodgeDebounce = {}
CombatData.ActiveStatusEffects = {}
CombatData.ActiveGroups = {}


CombatData.SuccessfulParry = {}
CombatData.SuccessfulHyprParry = {}
CombatData.ActiveRecoveryTracks = {}
CombatData.APFrames = {}

function CombatData.ClearForPlayer(identifier)
	for key, tbl in pairs(CombatData) do
		if type(tbl) == "table" and tbl ~= CombatData then
			tbl[identifier] = nil
		end
	end
end

return CombatData
