print([[


▀███▄   ▀███▀████▀████▀  ▀████▀▀████▀████▀     ▄▄█▀▀██▄ ▀████▄     ▄███▀███▄   ▀███▀████▀     ██      
  ███▄    █   ██   ██      ██    ██   ██     ▄██▀    ▀██▄ ████    ████   ███▄    █   ██      ▄██▄     
  █ ███   █   ██   ██      ██    ██   ██     ██▀      ▀██ █ ██   ▄█ ██   █ ███   █   ██     ▄█▀██▄    
  █  ▀██▄ █   ██   ██████████    ██   ██     ██        ██ █  ██  █▀ ██   █  ▀██▄ █   ██    ▄█  ▀██    
  █   ▀██▄█   ██   ██      ██    ██   ██     ▄█▄      ▄██ █  ██▄█▀  ██   █   ▀██▄█   ██    ████████   
  █     ███   ██   ██      ██    ██   ██    ▄███▄    ▄██▀ █  ▀██▀   ██   █     ███   ██   █▀      ██  
▄███▄    ██ ▄████▄████▄  ▄████▄▄████▄█████████ ▀▀████▀▀ ▄███▄ ▀▀  ▄████▄███▄    ██ ▄████▄███▄   ▄████▄
]])










local RS = game:GetService("ReplicatedStorage")

local Events = RS.Events
local Modules = RS.Modules

local CombatEffectsModule = require(Modules.Combat.EffectsModule)



Events.VFX.OnClientEvent:Connect(function(action,...)
	if action == "CombatEffects" then
		local effect, cframe,destroytime =...
		
		CombatEffectsModule.EmitEffect(effect, cframe,destroytime)
	end

	if action == "AfterImage" then
		local char,anim,type = ...
		CombatEffectsModule.AfterImage(char, anim, type)
	end
	
	if action == "SwingEffect" then
		local effect, char =...

		CombatEffectsModule.triggerEffects(effect,char)
	end

	if action == "DestroyVFX" then
		local char, effect = ...
		CombatEffectsModule.DestroyEffects(char, effect)
	end

	if action == "Trail" then
		local char, duration = ...
		CombatEffectsModule.Trail(char, duration) 
		
	end

	if action == "TrailStop" then
		local char = ...
		CombatEffectsModule.StopTrails(char)
	end

	if action == "HyprParry" then 
		local char,echar = ...
		-- char = attacker (got parried), echar = defender (parrier / revenge holder)
		-- defender gets full cam+bars (isMainSource=true), attacker gets highlight only so they can hypr-parry the revenge
		CombatEffectsModule.HyprVfx(echar,char,true)
		CombatEffectsModule.HyprVfx(char,echar,false)
	end
	
	if	action == "Highlight" then
		local char, duration, FillColor, OutlineColor = ...
		
		CombatEffectsModule.Highlight(char, duration, FillColor, OutlineColor)
	end

	if action  ==  "HighlightBlink" then
		local target, fillcolor, duration, blinkSpeed = ...
		CombatEffectsModule.HighlightBlink(target, fillcolor, duration, blinkSpeed)
	end

	if action == "HyprIndicator" then
		local char,cframe = ...
		local effect = RS.Effects.Combat.HyprIndicator
		CombatEffectsModule.Highlight(char,0.5,Color3.new(0.980392, 0.572549, 0.003922),Color3.new(0.980392, 0.572549, 0.003922),true)
		CombatEffectsModule.EmitEffect(effect, cframe)
	end

	
	
end)