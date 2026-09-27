-- Gradually regenerates the Humanoid's Health over time.
local RS = game:GetService("ReplicatedStorage")
local Movement = require(RS.Modules.Movement.Objects.Movement)

local REGEN_RATE = 1 / 100 -- Regenerate this fraction of MaxHealth per second.
local REGEN_STEP = 1 -- Wait this long between each regeneration step.
local RestingRegen_Rate = 8 / 100

--------------------------------------------------------------------------------

local Character = script.Parent
local Humanoid = Character:WaitForChild("Humanoid")
local IsResting = Character:GetAttribute("IsResting")

--------------------------------------------------------------------------------

while true do
	while Humanoid.Health < Humanoid.MaxHealth do
        local dt = wait(REGEN_STEP)
        local rate = REGEN_RATE
		if IsResting then
			rate = RestingRegen_Rate
		end
        local dh = dt * rate * Humanoid.MaxHealth
		Humanoid.Health = math.min(Humanoid.Health + dh, Humanoid.MaxHealth)
         

	end
	Humanoid.HealthChanged:Wait()
end
