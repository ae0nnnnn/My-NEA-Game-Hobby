local SS = game:GetService("ServerStorage")

local SSModules = SS.Modules
local npc = require(SSModules.Objects.npc)

task.wait()
local NPC_Folder = workspace.NPC

-- FIX: Use GetChildren() instead of GetDescendants() so it ignores weapons/armor models inside characters
for _, NPC in NPC_Folder:GetChildren() do
    -- EXTRA GUARD: Ensure it's a Model AND has a Humanoid before initializing
    if NPC:IsA("Model") and NPC:FindFirstChildOfClass("Humanoid") then
        if not npc.GetNpcFromCharacter(NPC) then
            npc.new(NPC.Name, NPC)
            print("Successfully initialized NPC:", NPC.Name)
        end
    end
end