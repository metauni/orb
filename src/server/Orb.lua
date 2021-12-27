local CollectionService = game:GetService("CollectionService")
local ProximityPromptService = game:GetService("ProximityPromptService")
 
local Common = game:GetService("ReplicatedStorage").OrbCommon
local Config = require(Common.Config)

local OrbAttachRemoteEvent = Common.Remotes.OrbAttach
local OrbDetachRemoteEvent = Common.Remotes.OrbDetach

local Orb = {}
Orb.__index = Orb

function Orb.Init()
	local orbs = CollectionService:GetTagged(Config.ObjectTag)

	for _, orb in ipairs(orbs) do
		Orb.InitOrb(orb)
	end

	CollectionService:GetInstanceAddedSignal(Config.ObjectTag):Connect(function(orb)
		Orb.InitBoard(orb)
	end)

	OrbDetachRemoteEvent.OnServerEvent:Connect(function(plr, orb)
		Orb.RemoveListener(orb, plr.UserId)
	end)

	print("Orb Server initialized")
end

function Orb.InitOrb(orb)
	local listeners = orb:FindFirstChild("Listeners")

	if listeners == nil then
		listeners = Instance.new("Folder")
		listeners.Name = "Listeners"
		listeners.Parent = orb
	end

	local speaker = orb:FindFirstChild("Speaker")

	if speaker == nil then
		speaker = Instance.new("IntValue")
		speaker.Name = "Speaker"
		speaker.Value = 0
		speaker.Parent = orb
	end

	-- Attach proximity prompts
	local proximityPrompt = Instance.new("ProximityPrompt")
	proximityPrompt.ActionText = "Attach"
	proximityPrompt.MaxActivationDistance = 5
	proximityPrompt.HoldDuration = 1
	proximityPrompt.ObjectText = "Orb"
	proximityPrompt.Parent = orb

	ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		if prompt.Parent == orb then
			print("Orb triggered by"..player.Name)
			Orb.AddListener(orb, player.UserId)
			OrbAttachRemoteEvent:FireClient(player, orb)
		end
	end)
end

-- TODO: Disconnect a listener when the player quits
function Orb.AddListener(orb, listenerID)
	for _, listenerValue in ipairs(orb.Listeners:GetChildren()) do
		if listenerValue.Value == listenerID then return end
	end

	local newListenerValue = Instance.new("IntValue")
	newListenerValue.Name = "ListenerValue"
	newListenerValue.Value = listenerID
	newListenerValue.Parent = orb.Listeners
end

function Orb.RemoveListener(orb, listenerID)
	for _, listenerValue in ipairs(orb.Listeners:GetChildren()) do
		if listenerValue.Value == listenerID then
			listenerValue:Destroy()
			break
		end
	end
end

function Orb.SetSpeaker(orb, speaker)
	if speaker and typeof(speaker) == "number" then
		orb.Speaker.Value = speaker
	else
		-- Set speaker to nil to disconnect a speaker
		orb.Speaker.Value = 0
	end
end

return Orb