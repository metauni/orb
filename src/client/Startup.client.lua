local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local OrbDummyGui = Players.LocalPlayer.PlayerGui:WaitForChild("OrbDummyGui",math.huge)
local Common = ReplicatedStorage:WaitForChild("OrbCommon")

local localPlayer = Players.LocalPlayer
local localCharacter = localPlayer.Character

local Gui = require(script.Parent.Gui)
local Halos = require(script.Parent.Halos)
local Config = require(Common.Config)

Halos.Init()

if localCharacter then
	-- When joining the game
	Gui.Init()
end

Players.LocalPlayer.CharacterAdded:Connect(function(character)
	-- When resetting
	Gui.OnResetCharacter()
end)

Players.LocalPlayer.CharacterRemoving:Connect(function()
	Gui.Detach()
	Gui.RemoveEar()
end)