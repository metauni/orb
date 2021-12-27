local Players = game:GetService("Players")
local ListenerGui = Players.LocalPlayer.PlayerGui:WaitForChild("OrbListenerGui", 10)
local SoundService = game:GetService("SoundService")

local localPlayer = Players.LocalPlayer
local localCharacter = localPlayer.Character

local Gui = require(script.Parent.Gui)
local Common = game:GetService("ReplicatedStorage").OrbCommon
local Config = require(Common.Config)

if localCharacter then
	Gui.Init(localPlayer)
end

Players.LocalPlayer.CharacterAdded:Connect(function(character)
	Gui.Init(localPlayer)
end)