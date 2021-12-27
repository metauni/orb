do
	-- Move folder/guis around if they have been packaged inside MetaBoardServer
	
	local orbCommon = script.Parent:FindFirstChild("OrbCommon")
	if orbCommon then
		orbCommon.Parent = game:GetService("ReplicatedStorage")
	end

	local orbPlayer = script.Parent:FindFirstChild("OrbPlayer")
	if orbPlayer then
		orbPlayer.Parent = game:GetService("StarterPlayer").StarterPlayerScripts
	end

	local boardGui = script.Parent:FindFirstChild("BoardGui")
	if boardGui then
		boardGui.Parent = game:GetService("StarterGui")
	end
end

local Orb = require(script.Parent.Orb)
local PersonalBoardManager = require(script.Parent.PersonalBoardManager)
local ServerDrawingTasks = require(script.Parent.ServerDrawingTasks)
local Persistence = require(script.Parent.Persistence)

MetaBoard.Init()
PersonalBoardManager.Init()
ServerDrawingTasks.Init()
Persistence.Init()