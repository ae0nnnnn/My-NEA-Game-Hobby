
-- Pack debug: flank orbit blue parts + leader path spheres (SmallFry.Visualize=true) — disabled for solo debugging
_G.DEBUG_PACK_VISUALIZE = false

local ServerStorage = game:GetService("ServerStorage")
local npc = require(ServerStorage.Modules.Objects.npc)


local pain= npc.new("TestNPC")
-- DEBUG solo: pack disabled for debugging so you don't get jumped (re-enable below when done)
-- local HRP = pain.Character.HumanoidRootPart
-- local debugSpawnCFrame = HRP.CFrame + Vector3.new(15, 0, 0)
-- local debugBanditPackMembers = npc.newGroup("BanditGroup", debugSpawnCFrame)
-- local packGroupNameForDebug = debugBanditPackMembers[1]:GetGroupName()
-- if packGroupNameForDebug then
-- 	pain:AssignGroup(packGroupNameForDebug, "Subordinate")
-- 	print("DEBUG added pain to pack", packGroupNameForDebug)
-- end
-- print("DEBUG spawned BanditGroup pack with", #debugBanditPackMembers + 1, "members (pain included) at", debugSpawnCFrame)
-- for _, packMemberNpc in ipairs(debugBanditPackMembers) do
-- 	packMemberNpc:Start()
-- end
pain:Start()
print("DEBUG solo SmallFry spawned (pack disabled)")





