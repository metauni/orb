local ReplicatedStorage = game:GetService("ReplicatedStorage")

do
	-- Move folder/guis around if they have been packaged inside OrbServer
	
	local orbCommon = script.Parent:FindFirstChild("OrbCommon")
	if orbCommon then
		if ReplicatedStorage:FindFirstChild("Icon") == nil then
			orbCommon.Packages.Icon.Parent = ReplicatedStorage
		end
		orbCommon.Parent = ReplicatedStorage
	end

	local orbPlayer = script.Parent:FindFirstChild("OrbPlayer")
	if orbPlayer then
		orbPlayer.Parent = game:GetService("StarterPlayer").StarterPlayerScripts
	end

	local orbGuiLuggage = script.Parent:FindFirstChild("OrbGuiLuggage")
	if orbGuiLuggage then
		orbGuiLuggage.Parent = game:GetService("StarterGui")
	end
end

local Orb = require(script.Parent.Orb)

Orb.Init()