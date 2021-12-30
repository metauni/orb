do
	-- Move folder/guis around if they have been packaged inside OrbServer
	
	local orbCommon = script.Parent:FindFirstChild("OrbCommon")
	if orbCommon then
		orbCommon.Parent = game:GetService("ReplicatedStorage")
	end

	local orbPlayer = script.Parent:FindFirstChild("OrbPlayer")
	if orbPlayer then
		orbPlayer.Parent = game:GetService("StarterPlayer").StarterPlayerScripts
	end

	local orbGui = script.Parent:FindFirstChild("OrbGui")
	if orbGui then
		orbGui.Parent = game:GetService("StarterGui")
	end

	local orbGuiSpeaker = script.Parent:FindFirstChild("OrbGuiSpeaker")
	if orbGuiSpeaker then
		orbGuiSpeaker.Parent = game:GetService("StarterGui")
	end
end

local Orb = require(script.Parent.Orb)

Orb.Init()