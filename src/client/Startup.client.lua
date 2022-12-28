local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Common = ReplicatedStorage:WaitForChild("OrbCommon")

if Common:GetAttribute("OrbServerInitialised") == nil then
    Common:GetAttributeChangedSignal("OrbServerInitialised"):Wait()
end

local localPlayer = Players.LocalPlayer
local localCharacter = localPlayer.Character or localPlayer.CharacterAdded:Wait()

local Gui = require(script.Parent.Gui)
local Halos = require(script.Parent.Halos)
local Config = require(Common.Config)

Gui.Init()
Halos.Init()

Players.LocalPlayer.CharacterAdded:Connect(function(character)
	-- When resetting
	Gui.OnResetCharacter()
end)

Players.LocalPlayer.CharacterRemoving:Connect(function()
	Gui.Detach()
	Gui.RemoveEar()
end)