local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")

local localPlayer = Players.LocalPlayer
local localCharacter = localPlayer.Character

local Gui = require(script.Parent.Gui)
local Halos = require(script.Parent.Halos)
local Common = game:GetService("ReplicatedStorage").OrbCommon
local Config = require(Common.Config)

Halos.Init()

if localCharacter then
	-- When joining the game
	Gui.Init()
end

Players.LocalPlayer.CharacterAdded:Connect(function(character)
	-- When resetting
	Gui.Init()
end)

Players.LocalPlayer.CharacterRemoving:Connect(function()
	Gui.Detach()
	Gui.RemoveEar()
end)