local RestingModule = {}
local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")
local RSModules = RS.Modules
local SSModules = SS.Modules
local ClientTypes = require(RSModules.ClientTypes)
local WeaponAnimations = RS.Animations.Weapons

local Restcooldowns = {}


local function StartResting(MovementObj:ClientTypes.MovementObj)
    local char = MovementObj.char
    local currentWeapon = char:GetAttribute("CurrentWeapon")
    local hum = char.Humanoid
    local HRP = char:FindFirstChild("HumanoidRootPart") :: BasePart
    if not char or not hum or not currentWeapon or not HRP or MovementObj.States.IsResting then return end 
    local restingAnim = hum.Animator:LoadAnimation(WeaponAnimations[currentWeapon].Movement.Resting)
    HRP.Anchored = true
    restingAnim:Play()
    MovementObj.States.IsResting = true
    MovementObj:ClearWalkAnims()

    



    local function RestStop()
        if not MovementObj.States.IsResting then return end 
        restingAnim:Stop()
        Restcooldowns[MovementObj] = tick()
        MovementObj:UpdateWalkTracks()
        HRP.Anchored = false
    end

    MovementObj.InfoTable.Resting.Stop = RestStop
end

function RestingModule.Start(MovementObj:ClientTypes.MovementObj)
    pcall(function() MovementObj:CancelConflictingActions("Resting") end)
    if Restcooldowns[MovementObj] and tick() - Restcooldowns[MovementObj] < 0.05 then return end  -- just a debounce not an actual cooldown
    if MovementObj.States.IsResting then return end 
    StartResting(MovementObj)
end

return RestingModule