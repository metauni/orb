local Players = game:GetService("Players")
local ListenerGui = Players.LocalPlayer.PlayerGui:WaitForChild("OrbGui", math.huge)
local SoundService = game:GetService("SoundService")

local localPlayer = Players.LocalPlayer
local localCharacter = localPlayer.Character

local Gui = require(script.Parent.Gui)
local Common = game:GetService("ReplicatedStorage").OrbCommon
local Config = require(Common.Config)

if localCharacter then
	Gui.Init()
end

Players.LocalPlayer.CharacterAdded:Connect(function(character)
	Gui.Init()
end)