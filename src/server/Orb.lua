local CollectionService = game:GetService("CollectionService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local TweenService = game:GetService("TweenService")

local Common = game:GetService("ReplicatedStorage").OrbCommon
local Config = require(Common.Config)

local OrbAttachRemoteEvent = Common.Remotes.OrbAttach
local OrbDetachRemoteEvent = Common.Remotes.OrbDetach
local OrbBecomeSpeakerRemoteEvent = Common.Remotes.OrbBecomeSpeaker
local OrbSpeakerMovedRemoteEvent = Common.Remotes.OrbSpeakerMoved

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

	OrbBecomeSpeakerRemoteEvent.OnServerEvent:Connect(function(plr, orb, state)
		if plr and orb and state == "on" then
			Orb.SetSpeaker(orb, plr.UserId)
		else
			Orb.SetSpeaker(orb, nil)
		end
	end)

	OrbSpeakerMovedRemoteEvent.OnServerEvent:Connect(function(plr, orb)
		local waypointsFolder = orb:FindFirstChild("Waypoints")

		if not plr.Character then return end
		if not waypointsFolder then return end

		local playerPos = plr.Character.HumanoidRootPart.Position

		-- Find the closest waypoint to the new speaker position
		-- and move the orb there
		local minDistance = math.huge
		local minWaypoint = nil

		if waypointsFolder then
			local waypoints = waypointsFolder:GetChildren()

			for _, waypoint in ipairs(waypoints) do
				local distance = (waypoint.Position - playerPos).Magnitude
				if distance < minDistance then
					minDistance = distance
					minWaypoint = waypoint
				end
			end

			if minWaypoint then
				local tweenInfo = TweenInfo.new(
					3, -- Time
					Enum.EasingStyle.Quad, -- EasingStyle
					Enum.EasingDirection.Out, -- EasingDirection
					0, -- RepeatCount (when less than zero the tween will loop indefinitely)
					false, -- Reverses (tween will reverse once reaching it's goal)
					0 -- DelayTime
				)
			
				local orbTween = TweenService:Create(orb, tweenInfo, 
					{Position = minWaypoint.Position})
				
				-- Note that if the position is already being tweened, this will
				-- stop that tween and commence this one
				orbTween:Play()
			end
		end
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
	proximityPrompt.MaxActivationDistance = 7
	proximityPrompt.HoldDuration = 1
	proximityPrompt.ObjectText = "Orb"
	proximityPrompt.Parent = orb

	ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		if prompt.Parent == orb then
			Orb.AddListener(orb, player.UserId)
			OrbAttachRemoteEvent:FireClient(player, orb)
		end
	end)

	-- Make waypoints invisible
	local waypointsFolder = orb:FindFirstChild("Waypoints")

	if waypointsFolder then
		for _, waypoints in ipairs(waypointsFolder:GetChildren()) do
			waypoints.Transparency = 1
			waypoints.Anchored = true
			waypoints.CanCollide = false
		end
	end
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