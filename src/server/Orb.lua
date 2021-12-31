local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local Common = game:GetService("ReplicatedStorage").OrbCommon
local Config = require(Common.Config)

local OrbAttachRemoteEvent = Common.Remotes.OrbAttach
local OrbDetachRemoteEvent = Common.Remotes.OrbDetach
local OrbAttachSpeakerRemoteEvent = Common.Remotes.OrbAttachSpeaker
local OrbSpeakerMovedRemoteEvent = Common.Remotes.OrbSpeakerMoved
local OrbTeleportRemoteEvent = Common.Remotes.OrbTeleport
local OrbTweeningStartRemoteEvent = Common.Remotes.OrbTweeningStart
local OrbTweeningStopRemoteEvent = Common.Remotes.OrbTweeningStop

local Orb = {}
Orb.__index = Orb

function Orb.Init()
	-- Offset of ghosts from orbs (playedID -> Vector3)
	Orb.GhostOffsets = {}
	Orb.GhostTargets = {}

	local orbs = CollectionService:GetTagged(Config.ObjectTag)
	for _, orb in ipairs(orbs) do
		Orb.InitOrb(orb)
	end

	CollectionService:GetInstanceAddedSignal(Config.ObjectTag):Connect(function(orb)
		Orb.InitOrb(orb)
	end)

	OrbDetachRemoteEvent.OnServerEvent:Connect(function(plr, orb)
		Orb.RemoveListener(orb, plr.UserId)

		-- If this user was the speaker, detaching means
		-- they detached from being the speaker
		if orb.Speaker.Value == plr.UserId then
			Orb.SetSpeaker(orb, nil)
		end
	end)

	OrbAttachRemoteEvent.OnServerEvent:Connect(function(plr, orb)
		Orb.AddListener(orb, plr.UserId)
	end)

	OrbAttachSpeakerRemoteEvent.OnServerEvent:Connect(function(plr, orb)
		Orb.SetSpeaker(orb, plr.UserId)
	end)

	OrbSpeakerMovedRemoteEvent.OnServerEvent:Connect(function(plr, orb)
		if not plr.Character then return end
		local playerPos = plr.Character.PrimaryPart.Position

		local waypointPos = Orb.TweenOrbToNearPosition(orb, playerPos)

		if waypointPos then
			if (waypointPos - orb.Position).Magnitude > 0.01 then
				Orb.WalkGhosts(orb, waypointPos)
			else
				Orb.RotateGhosts(orb)
			end
		end
	end)

	-- Handle teleports
	OrbTeleportRemoteEvent.OnServerEvent:Connect(function(plr, orb)
		local ghost = Orb.GetGhost(orb, plr.UserId)
		local targetCFrame

		if ghost ~= nil then
			-- This is a user attached as listener
			targetCFrame = ghost.PrimaryPart.CFrame
			Orb.RemoveGhost(orb, plr.UserId)
			wait(0.1)
		else
			-- This is a speaker
			targetCFrame = CFrame.new(orb.Position + Vector3.new(0,5 * orb.Size.Y,0))
		end

		if plr.Character then
			plr.Character.PrimaryPart.CFrame = targetCFrame
		end
	end)

	-- Remove leaving players as listeners
	Players.PlayerRemoving:Connect(function(plr)
		Orb.RemoveListenerFromAllOrbs(plr.UserId)
	end)

	-- Make waypoints invisible
	local waypoints = CollectionService:GetTagged(Config.WaypointTag)

	for _, waypoint in ipairs(waypoints) do
		waypoint.Transparency = 1
		waypoint.Anchored = true
		waypoint.CanCollide = false
	end

	print("[Orb] Server ".. Config.Version .." initialized")
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

	-- Add ghosts folder
	local ghosts = orb:FindFirstChild("Ghosts")

	if ghosts == nil then
		ghosts = Instance.new("Folder")
		ghosts.Name = "Ghosts"
		ghosts.Parent = orb
	end

    -- Make a waypoint at the position of every orb
	local waypoint = Instance.new("Part")
	waypoint.Position = orb.Position
	waypoint.Name = "OriginWaypoint"
	waypoint.Size = Vector3.new(1,1,1)
	waypoint.Transparency = 1
	waypoint.Anchored = true
	waypoint.CanCollide = false
	CollectionService:AddTag(waypoint, "metaorb_waypoint")
	waypoint.Parent = orb
end

function Orb.RotateGhostToFaceSpeaker(orb, ghost)
	if not ghost then return end

	local speakerPos = Orb.GetSpeakerPosition(orb)
	if not speakerPos then return end

	local ghostPos = ghost.PrimaryPart.Position
	local speakerPosXZ = Vector3.new(speakerPos.X,ghostPos.Y,speakerPos.Z)

	local tweenInfo = TweenInfo.new(
		0.5, -- Time
		Enum.EasingStyle.Linear, -- EasingStyle
		Enum.EasingDirection.Out, -- EasingDirection
		0, -- RepeatCount (when less than zero the tween will loop indefinitely)
		false, -- Reverses (tween will reverse once reaching it's goal)
		0 -- DelayTime
	)

	local ghostTween = TweenService:Create(ghost.PrimaryPart, tweenInfo, 
		{CFrame = CFrame.new(ghostPos,speakerPosXZ)})
	
	ghostTween:Play()
end

function Orb.RotateGhosts(orb)
	for _, ghost in ipairs(orb.Ghosts:GetChildren()) do
		Orb.RotateGhostToFaceSpeaker(orb, ghost)
	end
end

function Orb.WalkGhosts(orb, pos)
	-- Animate all the ghosts
	for _, ghost in ipairs(orb.Ghosts:GetChildren()) do
		-- Maintain relative positioning
		local offset = Orb.GhostOffsets[ghost.Name]
		local newPos

		if offset ~= nil then
			newPos = pos + offset
		else
			newPos = pos - orb.Position + ghost.PrimaryPart.Position
		end
		
		-- If we're already on our way, don't repeat it
		local alreadyMoving = (Orb.GhostTargets[ghost.Name] ~= nil) and (Orb.GhostTargets[ghost.Name] - newPos).Magnitude < 0.01

		if not alreadyMoving then
			ghost.Humanoid:MoveTo(newPos)

			Orb.GhostTargets[ghost.Name] = newPos

			local animator = ghost.Humanoid:FindFirstChild("Animator")
			local animation = animator:LoadAnimation(Common.WalkAnim)
			animation:Play()

			local connection
			connection = ghost.Humanoid.MoveToFinished:Connect(function(reached)
				animation:Stop()

				-- If it was too far for the ghost to reach, just teleport them
				if not reached then
					local speakerPos = Orb.GetSpeakerPosition(orb)
					if speakerPos ~= nil then
						ghost.PrimaryPart.CFrame = CFrame.new(newPos, speakerPos)
					else
						ghost.PrimaryPart.Position = newPos
					end
				else
					Orb.RotateGhostToFaceSpeaker(orb, ghost)
				end

				Orb.GhostTargets[ghost.Name] = nil
				connection:Disconnect()
				connection = nil
			end)
		end
	end
end

function Orb.TweenOrbToNearPosition(orb, pos)
	local waypoints = CollectionService:GetTagged(Config.WaypointTag)

	if #waypoints == 0 then return orb.Position end

	-- Find the closest waypoint to the new position
	-- and move the orb there
	local minDistance = math.huge
	local minWaypoint = nil

	for _, waypoint in ipairs(waypoints) do
		local distance = (waypoint.Position - pos).Magnitude
		if distance < minDistance then
			minDistance = distance
			minWaypoint = waypoint
		end
	end

	if minWaypoint then
		-- If we are already there, don't tween
		if (minWaypoint.Position - orb.Position).Magnitude < 0.01 then
			return orb.Position
		end

		-- If there is an orb already there, don't tween
		local orbs = CollectionService:GetTagged(Config.ObjectTag)

		for _, otherOrb in ipairs(orbs) do
			if otherOrb ~= orb and (minWaypoint.Position - otherOrb.Position).Magnitude < 0.01 then
				return orb.Position
			end
		end

		local tweenInfo = TweenInfo.new(
			Config.TweenTime, -- Time
			Enum.EasingStyle.Quad, -- EasingStyle
			Enum.EasingDirection.Out, -- EasingDirection
			0, -- RepeatCount (when less than zero the tween will loop indefinitely)
			false, -- Reverses (tween will reverse once reaching it's goal)
			0 -- DelayTime
		)
	
		local poiPos = Orb.PointOfInterest(minWaypoint.Position)
		
		local orbTween
		if poiPos ~= nil then
			orbTween = TweenService:Create(orb, tweenInfo, 
				{CFrame = CFrame.new(minWaypoint.Position, poiPos)})
		else
			orbTween = TweenService:Create(orb, tweenInfo, 
				{Position = minWaypoint.Position})
		end

		orbTween.Completed:Connect(function()
			OrbTweeningStopRemoteEvent:FireAllClients(orb)
		end)

		-- Note that if the position is already being tweened, this will
		-- stop that tween and commence this one
		orbTween:Play()

		-- Announce this tween to clients
		OrbTweeningStartRemoteEvent:FireAllClients(orb, minWaypoint.Position, poiPos)

		return minWaypoint.Position
	end

	return orb.Position
end

function Orb.AddGhost(orb, playerId)
	local plr = Players:GetPlayerByUserId(playerId)
	if plr then
		local character = plr.Character
		character.Archivable = true
		local ghost = plr.Character:Clone()
		character.Archivable = false

		ghost.Name = tostring(playerId)
		local distanceOrbPlayer = (orb.Position - character.PrimaryPart.Position).Magnitude
		local ghostPos = ghost.PrimaryPart.Position - distanceOrbPlayer * ghost.PrimaryPart.CFrame.LookVector
		ghostPos += Vector3.new(0,0.3,0) -- pop them up in the air a bit

		-- This offset is preserved when walking ghosts
		Orb.GhostOffsets[ghost.Name] = ghostPos - orb.Position

		-- Make the ghost look towards the speaker, if there is one
		local speakerPos = Orb.GetSpeakerPosition(orb)
		if speakerPos then
			local speakerPosXZ = Vector3.new(speakerPos.X,ghostPos.Y,speakerPos.Z)
			ghost:SetPrimaryPartCFrame(CFrame.new(ghostPos,speakerPosXZ))
		else
			ghost:SetPrimaryPartCFrame(CFrame.new(ghostPos, character.PrimaryPart.Position))
		end

		for _, desc in ipairs(ghost:GetDescendants()) do
			if desc:IsA("BasePart") then
				desc.Transparency = 1 - (0.2 * (1 - desc.Transparency))
				desc.CastShadow = false
			end
		end

		ghost.Parent = orb.Ghosts
	end
end

function Orb.GetGhost(orb, playerId)
	for _, ghost in ipairs(orb.Ghosts:GetChildren()) do
		if ghost.Name == tostring(playerId) then
			return ghost
		end
	end

	return nil
end

function Orb.AddListener(orb, listenerID)
	for _, listenerValue in ipairs(orb.Listeners:GetChildren()) do
		if listenerValue.Value == listenerID then return end
	end

	local newListenerValue = Instance.new("IntValue")
	newListenerValue.Name = "ListenerValue"
	newListenerValue.Value = listenerID
	newListenerValue.Parent = orb.Listeners

	Orb.AddGhost(orb, listenerID)
end

function Orb.RemoveGhost(orb, playerId)
	for _, ghost in ipairs(orb.Ghosts:GetChildren()) do
		if ghost.Name == tostring(playerId) then
			ghost:Destroy()
			break
		end
	end
end

function Orb.RemoveListener(orb, listenerID)
	for _, listenerValue in ipairs(orb.Listeners:GetChildren()) do
		if listenerValue.Value == listenerID then
			listenerValue:Destroy()
			break
		end
	end

	Orb.RemoveGhost(orb, listenerID)
end

function Orb.RemoveListenerFromAllOrbs(listenerID)
	local orbs = CollectionService:GetTagged(Config.ObjectTag)

	for _, orb in ipairs(orbs) do
		Orb.RemoveListener(orb, listenerID)
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

function Orb.GetSpeakerPosition(orb)
	if orb.Speaker.Value == 0 then return nil end

	local plr = Players:GetPlayerByUserId(orb.Speaker.Value)
	if not plr then return nil end

	return plr.Character.PrimaryPart.Position
end

-- A point of interest is any object tagged with either
-- metaboard or metaorb_poi. Returns the closest point
-- of interest to the current orb and its position and nil if none can
-- be found. Note that a point of interest is either nil,
-- a BasePart or a Model with non-nil PrimaryPart
function Orb.PointOfInterest(targetPos)
    local boards = CollectionService:GetTagged("metaboard")
    local pois = CollectionService:GetTagged("metaorb_poi")

    if #boards == 0 and #pois == 0 then return nil end

    -- Find the closest board
    local closestPos = nil
    local minDistance = math.huge

    local families = {boards, pois}

    for _, family in ipairs(families) do
        for _, p in ipairs(family) do
            local pos = nil

            if p:IsA("BasePart") then
                pos = p.Position
            elseif p:IsA("Model") and p.PrimaryPart ~= nil then
                pos = p.PrimaryPart.Position
            end

            if pos ~= nil then
                local distance = (pos - targetPos).Magnitude
                if distance < minDistance then
                    minDistance = distance
                    closestPos = pos
                end
            end
        end
    end

    return closestPos
end

return Orb