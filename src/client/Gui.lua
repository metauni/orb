local Common = game:GetService("ReplicatedStorage").OrbCommon
local SoundService = game:GetService("SoundService")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ProximityPromptService = game:GetService("ProximityPromptService")

local Players = game:GetService("Players")
local Config = require(Common.Config)

local OrbAttachRemoteEvent = Common.Remotes.OrbAttach
local OrbDetachRemoteEvent = Common.Remotes.OrbDetach
local OrbAttachSpeakerRemoteEvent = Common.Remotes.OrbAttachSpeaker
local OrbDetachSpeakerRemoteEvent = Common.Remotes.OrbDetachSpeaker
local OrbSpeakerMovedRemoteEvent = Common.Remotes.OrbSpeakerMoved
local OrbTeleportRemoteEvent = Common.Remotes.OrbTeleport
local OrbTweeningStartRemoteEvent = Common.Remotes.OrbTweeningStart
local OrbTweeningStopRemoteEvent = Common.Remotes.OrbTweeningStop
local OrbListenOnRemoteEvent = Common.Remotes.OrbListenOn
local OrbListenOffRemoteEvent = Common.Remotes.OrbListenOff
local OrbcamOnRemoteEvent = Common.Remotes.OrbcamOn
local OrbcamOffRemoteEvent = Common.Remotes.OrbcamOff

local listenerGui, speakerGui, listenButton, detachButton, returnButton
local peekButton, detachSpeakerButton, speakerViewportFrame
local returnButtonSpeaker, peekButtonSpeaker, luggageGui
local peekButtonLuggage, detachLuggageButton
local localPlayer

local storedCameraOffset = nil
local storedCameraFOV = nil
local targetForOrbTween = {} -- orb to target position and poi of tween

local Gui = {}
Gui.__index = Gui

function Gui.Init()
    localPlayer = Players.LocalPlayer
    listenerGui = localPlayer.PlayerGui:WaitForChild("OrbGui",math.huge)
    speakerGui = localPlayer.PlayerGui:WaitForChild("OrbGuiSpeaker",math.huge)
    luggageGui = localPlayer.PlayerGui:WaitForChild("OrbGuiLuggage",math.huge)
    Gui.Listening = false
    Gui.Speaking = false

    if Gui.Orb then
        print("[orb] WARNING: Gui.Orb was non-nil on Init")
    end

    Gui.Orb = nil
    Gui.RunningConnection = nil
    Gui.ViewportOn = false
    Gui.HasSpeakerPermission = true -- can attach as speaker?
    Gui.Orbcam = false
    Gui.CameraTween = nil
    Gui.Head = nil
    Gui.Ear = nil
    Gui.EarConnection = nil
    Gui.CharacterChildAddedConnection = nil

    Gui.InitEar()

    listenButton = listenerGui:WaitForChild("ListenButton")
    detachButton = listenerGui:WaitForChild("DetachButton")
    detachSpeakerButton = speakerGui:WaitForChild("DetachButton")
    returnButton = listenerGui:WaitForChild("ReturnButton")
    peekButton = listenerGui:WaitForChild("PeekButton")
    speakerViewportFrame = speakerGui:WaitForChild("ViewportFrame")
    returnButtonSpeaker = speakerGui:WaitForChild("ReturnButton")
    peekButtonSpeaker = speakerGui:WaitForChild("PeekButton")
    peekButtonLuggage = luggageGui:WaitForChild("PeekButton")
    detachLuggageButton = luggageGui:WaitForChild("DetachButton")

    -- 
    -- Listening
    --

    local function toggleListen()
        if Gui.Listening then
            Gui.ListenOff()
        else
            Gui.ListenOn()
        end
    end

    listenButton.Activated:Connect(toggleListen)

    -- 
    -- Attach and detach
    --

    detachButton.Activated:Connect(Gui.Detach)
    detachSpeakerButton.Activated:Connect(Gui.Detach)
    detachLuggageButton.Activated:Connect(Gui.Detach)
    OrbAttachSpeakerRemoteEvent.OnClientEvent:Connect(Gui.RefreshPrompts)
    OrbDetachSpeakerRemoteEvent.OnClientEvent:Connect(Gui.RefreshPrompts)

    -- 
    -- Teleporting
    --

    returnButton.Activated:Connect(function()
        -- Teleport us to our ghost
        OrbTeleportRemoteEvent:FireServer(Gui.Orb)
    end)

    returnButtonSpeaker.Activated:Connect(function()
        -- Teleport us to our orb
        OrbTeleportRemoteEvent:FireServer(Gui.Orb)
    end)

    --
    -- Viewport
    --

    local function peekButtonActivated(button)
        Gui.ToggleOrbcam(false)

        if Gui.Orbcam then
            button.BackgroundColor3 = Color3.new(1,1,1)
        else
            button.BackgroundColor3 = Color3.new(0,0,0)
        end
    end

    peekButton.Activated:Connect(function()
        peekButtonActivated(peekButton)
    end)

    peekButtonSpeaker.Activated:Connect(function()
        peekButtonActivated(peekButtonSpeaker)
    end)

    peekButtonLuggage.Activated:Connect(function()
        peekButtonActivated(peekButtonLuggage)
    end)

    -- If the Admin system is installed, the permission specified there
	-- overwrites the default "true" state of HasWritePermission
	local adminEvents = game:GetService("ReplicatedStorage"):FindFirstChild("MetaAdmin")
	if adminEvents then
		local isScribeRF = adminEvents:WaitForChild("IsScribe")

		if isScribeRF then
			Gui.HasSpeakerPermission = isScribeRF:InvokeServer()
		end

		-- Listen for updates to the permissions
		local permissionUpdateRE = adminEvents:WaitForChild("PermissionsUpdate")
		permissionUpdateRE.OnClientEvent:Connect(function()
			-- Request the new permission
			if isScribeRF then
				Gui.HasSpeakerPermission = isScribeRF:InvokeServer()
			end

            -- Update the visibility of speaker prompts
            local orbs = CollectionService:GetTagged(Config.ObjectTag)
            for _, orb in ipairs(orbs) do
                local speakerPrompt = if orb:IsA("BasePart") then orb:FindFirstChild("SpeakerPrompt") else orb.PrimaryPart:FindFirstChild("SpeakerPrompt")

                -- If we are not currently attached as either or speaker
                -- or listener, make the speaker prompt enabled
                if speakerPrompt and not Gui.Orb == orb then
                    speakerPrompt.Enabled = Gui.HasSpeakerPermission and orb.Speaker.Value == nil
                end
            end
		end)
	end

    -- Give speaker permissions in Studio
    if RunService:IsStudio() then
        Gui.HasSpeakerPermission = true
    end

    -- Install proximity prompts (note that this gets called again after player reset)
    local orbs = CollectionService:GetTagged(Config.ObjectTag)
    for _, orb in ipairs(orbs) do
        local luggagePrompt = if orb:IsA("BasePart") then orb:FindFirstChild("LuggagePrompt") else orb.PrimaryPart:FindFirstChild("LuggagePrompt")
        if luggagePrompt == nil and CollectionService:HasTag(orb, Config.TransportTag) then
            luggagePrompt = Instance.new("ProximityPrompt")
            luggagePrompt.Name = "LuggagePrompt"
            luggagePrompt.ActionText = "Attach as Luggage"
            luggagePrompt.MaxActivationDistance = 8
            luggagePrompt.HoldDuration = 1
            luggagePrompt.ObjectText = "Orb"
            luggagePrompt.RequiresLineOfSight = false
            luggagePrompt.Parent = if orb:IsA("BasePart") then orb else orb.PrimaryPart

            ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
                if prompt == luggagePrompt and prompt.Name == "LuggagePrompt" then
                    OrbAttachRemoteEvent:FireServer(orb)
                    Gui.Attach(orb)
                end
            end)
        end

        local normalPrompt = if orb:IsA("BasePart") then orb:FindFirstChild("NormalPrompt") else orb.PrimaryPart:FindFirstChild("NormalPrompt")
        if normalPrompt == nil and not CollectionService:HasTag(orb, Config.TransportTag) then
            normalPrompt = Instance.new("ProximityPrompt")
            normalPrompt.Name = "NormalPrompt"
            normalPrompt.ActionText = "Attach as Listener"
            normalPrompt.MaxActivationDistance = 8
            normalPrompt.HoldDuration = 1
            normalPrompt.ObjectText = "Orb"
            normalPrompt.RequiresLineOfSight = false
            normalPrompt.Parent = if orb:IsA("BasePart") then orb else orb.PrimaryPart

            ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
                if prompt == normalPrompt and prompt.Name == "NormalPrompt" then
                    OrbAttachRemoteEvent:FireServer(orb)
                    Gui.Attach(orb)
                end
            end)
        end

        local speakerPrompt = if orb:IsA("BasePart") then orb:FindFirstChild("SpeakerPrompt") else orb.PrimaryPart:FindFirstChild("SpeakerPrompt")
        if speakerPrompt == nil and not CollectionService:HasTag(orb, Config.TransportTag) then
            speakerPrompt = Instance.new("ProximityPrompt")
            speakerPrompt.Name = "SpeakerPrompt"
            speakerPrompt.ActionText = "Attach as Speaker"
            speakerPrompt.UIOffset = Vector2.new(0,75)
            speakerPrompt.MaxActivationDistance = 8
            speakerPrompt.HoldDuration = 1
            speakerPrompt.KeyboardKeyCode = Enum.KeyCode.F
            speakerPrompt.GamepadKeyCode = Enum.KeyCode.ButtonY
            speakerPrompt.ObjectText = "Orb"
            speakerPrompt.RequiresLineOfSight = false
            speakerPrompt.Enabled = Gui.HasSpeakerPermission
            speakerPrompt.Parent = if orb:IsA("BasePart") then orb else orb.PrimaryPart

            ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
                if prompt == speakerPrompt and prompt.Name == "SpeakerPrompt" then
                    -- Only allow someone to attach if there is no current speaker
                    if orb.Speaker.Value == nil then
                        OrbAttachSpeakerRemoteEvent:FireServer(orb)
                        Gui.AttachSpeaker(orb)
                    end
                end
            end)
        end
    end

    -- Setup a camera on the speaker viewport frame
    local viewportCamera = Instance.new("Camera")
    viewportCamera.Name = "Camera"
	speakerViewportFrame.CurrentCamera = viewportCamera
	viewportCamera.Parent = speakerViewportFrame

    -- Setup Orbcam
    local ORBCAM_MACRO_KB = {Enum.KeyCode.LeftShift, Enum.KeyCode.C}
    local function CheckMacro(macro)
        for i = 1, #macro - 1 do
            if not UserInputService:IsKeyDown(macro[i]) then
                return
            end
        end
        Gui.ToggleOrbcam(true)
    end

    local function HandleActivationInput(action, state, input)
        if state == Enum.UserInputState.Begin then
            if input.KeyCode == ORBCAM_MACRO_KB[#ORBCAM_MACRO_KB] then
                CheckMacro(ORBCAM_MACRO_KB)
            end
        end
        return Enum.ContextActionResult.Pass
    end

    ContextActionService:BindAction("OrbcamToggle", HandleActivationInput, false, ORBCAM_MACRO_KB[#ORBCAM_MACRO_KB])

    -- Handle orb tweening
    OrbTweeningStartRemoteEvent.OnClientEvent:Connect(Gui.OrbTweeningStart)
    OrbTweeningStopRemoteEvent.OnClientEvent:Connect(Gui.OrbTweeningStop)

	print("[Orb] Gui Initialised")
end

-- We create a part inside the player's head, whose CFrame
-- is tracked by SetListener
function Gui.InitEar()
    if not Config.ListenFromPlayer then
        SoundService:SetListener(Enum.ListenerType.Camera)
        return
    end

    local character = localPlayer.Character
    local head = character:WaitForChild("Head")

    local camera = workspace.CurrentCamera
	if not camera then return end

    local lookDirection = camera.CFrame.LookVector

    local ear = character:FindFirstChild(Config.EarName)
    if ear then
        ear:Destroy()
    end

    ear = Instance.new("Part")
    ear.Name = Config.EarName
    ear.Size = Vector3.new(0.1,0.1,0.1)
    ear.CanCollide = false
    ear.CastShadow = false
    ear.CFrame = CFrame.lookAt(head.Position, head.Position + lookDirection)
    ear.Transparency = 1
    ear.Parent = character

    Gui.Ear = ear
    Gui.Head = head
    SoundService:SetListener(Enum.ListenerType.ObjectCFrame, ear)

    -- When the avatar editor is used, a new head may be parented to the character
    -- NOTE: that the old head may _not_ be destroyed, so you can't just check for nil
    Gui.CharacterChildAddedConnection = localPlayer.Character.ChildAdded:Connect(function(child)
        if child.Name ~= "Head" then return end
        Gui.Head = child
    end)

    Gui.EarConnection = RunService.RenderStepped:Connect(function(delta)
        local nowCamera = workspace.CurrentCamera
	    if not nowCamera then return end
        
        -- The head may be destroyed
        if Gui.Head == nil then
            Gui.Head = localPlayer.Character:FindFirstChild("Head")
            if Gui.Head == nil then return end
        end

        ear.CFrame = CFrame.lookAt(Gui.Head.Position, 
            Gui.Head.Position + nowCamera.CFrame.LookVector)
    end)
end

function Gui.RemoveEar()
    if Gui.EarConnection then
        Gui.EarConnection:Disconnect()
        Gui.EarConnection = nil
    end

    if Gui.CharacterChildAddedConnection then
        Gui.CharacterChildAddedConnection:Disconnect()
        Gui.CharacterChildAddedConnection = nil
    end

    if Gui.Ear then
        Gui.Ear:Destroy()
    end
end

-- Refresh the visibility of the normal and speaker proximity prompts
function Gui.RefreshPrompts(speaker, orb)
    local speakerPrompt = if orb:IsA("BasePart") then orb:FindFirstChild("SpeakerPrompt") else orb.PrimaryPart:FindFirstChild("SpeakerPrompt")

    -- If we are not currently attached as either or speaker
    -- or listener, make the speaker prompt enabled
    if speakerPrompt ~= nil and Gui.Orb ~= orb then
        speakerPrompt.Enabled = Gui.HasSpeakerPermission and speaker == nil and not orb:GetAttribute("tweening")
    end
end

-- A point of interest is any object tagged with either
-- metaboard or metaorb_poi. Returns the closest point
-- of interest to the current orb and its position and nil if none can
-- be found. Note that a point of interest is either nil,
-- a BasePart or a Model with non-nil PrimaryPart
function Gui.PointOfInterest()
    if Gui.Orb == nil then return end

    local boards = CollectionService:GetTagged("metaboard")
    local pois = CollectionService:GetTagged(Config.PointOfInterestTag)

    if #boards == 0 and #pois == 0 then return nil end

    -- Find the closest board
    local closestPoi = nil
    local closestPos = nil
    local minDistance = math.huge

    local families = {boards, pois}
    local orbPos = Gui.Orb:GetPivot().Position

    for _, family in ipairs(families) do
        for _, p in ipairs(family) do
			if CollectionService:HasTag(p, "metaboard_personal") then continue end

            local pos = p:GetPivot().Position

            if pos ~= nil then
                local distance = (pos - orbPos).Magnitude
                if distance < minDistance then
                    minDistance = distance
                    closestPos = pos
                    closestPoi = p
                end
            end
        end
    end

    return closestPoi, closestPos
end

function Gui.ListenOn()
    Gui.Listening = true
    listenButton.BackgroundTransparency = 0.2

    if Gui.Orb then
        -- Enum.ListenerType.ObjectPosition (if player rotates camera, it changes angle of sound sources)
        -- Enum.LIstenerType.ObjectCFrame (sound from the position and angle of object)
        -- Note that the orb's EarRingTracker points at the current speaker (if there is one)
        -- and at the current point of interest otherwise
        SoundService:SetListener(Enum.ListenerType.ObjectCFrame, Gui.Orb.EarRingTracker)
    end

    OrbListenOnRemoteEvent:FireServer()
end

function Gui.ListenOff()
    Gui.Listening = false
    listenButton.BackgroundTransparency = 0.75

    if Config.ListenFromPlayer and Gui.Ear ~= nil then
        SoundService:SetListener(Enum.ListenerType.ObjectCFrame, Gui.Ear)
    else
        SoundService:SetListener(Enum.ListenerType.Camera)
    end

    OrbListenOffRemoteEvent:FireServer()
end

-- Detach, as listener or speaker
function Gui.Detach()
    if not Gui.Orb then return end
    local orb = Gui.Orb

    if CollectionService:HasTag(orb, Config.TransportTag) then
        luggageGui.Enabled = false
        local luggagePrompt = if orb:IsA("BasePart") then orb.LuggagePrompt else orb.PrimaryPart.LuggagePrompt
        luggagePrompt.Enabled = true
        Gui.OrbcamOff()
        peekButtonLuggage.BackgroundColor3 = Color3.new(0,0,0)
    else
        -- If the orb is currently on the move, do not enable it yet
        if not orb:GetAttribute("tweening") then
            local normalPrompt = if orb:IsA("BasePart") then orb.NormalPrompt else orb.PrimaryPart.NormalPrompt
            local speakerPrompt = if orb:IsA("BasePart") then orb.SpeakerPrompt else orb.PrimaryPart.SpeakerPrompt
            normalPrompt.Enabled = true
            speakerPrompt.Enabled = Gui.HasSpeakerPermission
        end

        Gui.ListenOff()
        Gui.OrbcamOff()
        Gui.Speaking = false
        listenerGui.Enabled = false
        speakerGui.Enabled = false
        peekButton.BackgroundColor3 = Color3.new(0,0,0)
        peekButtonSpeaker.BackgroundColor3 = Color3.new(0,0,0)

        if Gui.RunningConnection then
            Gui.RunningConnection:Disconnect()
            Gui.RunningConnection = nil
        end
    end

    OrbDetachRemoteEvent:FireServer(orb)
    Gui.Orb = nil
end

function Gui.PopulateViewportSpeaker()
    local oldOrb = speakerViewportFrame:FindFirstChild("Orb")
    if oldOrb then oldOrb:Destroy() end
    if not Gui.Orb then return end

    local orbClone = Gui.Orb:Clone()

    -- Remove tags
    for _, tag in ipairs(CollectionService:GetTags(orbClone)) do
        CollectionService:RemoveTag(orbClone, tag)
    end

    -- Get rid of rings
    local eyeRingClone = orbClone:FindFirstChild("EyeRing")
    if eyeRingClone then
        eyeRingClone:Destroy()
    end

    local earRingClone = orbClone:FindFirstChild("EarRing")
    if earRingClone then
        earRingClone:Destroy()
    end
    
    orbClone:PivotTo(CFrame.new(0,0,0))
    orbClone.Name = "Orb"
    orbClone.Parent = speakerViewportFrame
    local orbSize = if orbClone:IsA("BasePart") then orbClone.Size else orbClone.PrimaryPart.Size
    speakerViewportFrame.Camera.CFrame = CFrame.new(Vector3.new(0, 1.3 * orbSize.Y, 0), Vector3.new(0,0,0))
end

function Gui.AttachSpeaker(orb)
    -- Disable the proximity prompt
    local normalPrompt = if orb:IsA("BasePart") then orb.NormalPrompt else orb.PrimaryPart.NormalPrompt
    local speakerPrompt = if orb:IsA("BasePart") then orb.SpeakerPrompt else orb.PrimaryPart.SpeakerPrompt
    normalPrompt.Enabled = false
    speakerPrompt.Enabled = false
    
    -- Disconnect from the old source if there is one
    if Gui.Orb then Gui.Detach() end
    
    Gui.Orb = orb
    Gui.Speaking = true

    -- Setup the viewport to show a copy of the orb
    Gui.PopulateViewportSpeaker()
    speakerGui.Enabled = true

    -- This event fires when the running speed changes
    local humanoid = localPlayer.Character:WaitForChild("Humanoid")
    Gui.RunningConnection = humanoid.Running:Connect(function(speed)
        if speed == 0 then
            -- They were moving and then stood still
            OrbSpeakerMovedRemoteEvent:FireServer(Gui.Orb)
        end
    end)
end

function Gui.Attach(orb)
    -- Disconnect from the old source if there is one
    if Gui.Orb then Gui.Detach() end
    Gui.Orb = orb

    if CollectionService:HasTag(orb, Config.TransportTag) then
        local luggagePrompt = if orb:IsA("BasePart") then orb.LuggagePrompt else orb.PrimaryPart.LuggagePrompt
        luggagePrompt.Enabled = false
        luggageGui.Enabled = true
    else
        -- Disable the proximity prompt
        local normalPrompt = if orb:IsA("BasePart") then orb.NormalPrompt else orb.PrimaryPart.NormalPrompt
        local speakerPrompt = if orb:IsA("BasePart") then orb.SpeakerPrompt else orb.PrimaryPart.SpeakerPrompt
        normalPrompt.Enabled = false
        speakerPrompt.Enabled = false
        listenerGui.Enabled = true
        Gui.ListenOn()
    end
end

-- 
-- Orbcam
--

local function resetCameraSubject()
	local camera = workspace.CurrentCamera
	if not camera then return end

    local character = localPlayer.Character
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		workspace.CurrentCamera.CameraSubject = humanoid
	end

    if storedCameraOffset then
	    if character.Head then
		    camera.CFrame = CFrame.lookAt(character.Head.Position + storedCameraOffset, character.Head.Position)
	    end

        storedCameraOffset = nil
    else
        print("ERROR: storedCameraOffset not set.")
    end
end

function Gui.OrbTweeningStart(orb, newPos, poiPos, poi)
    -- Start camera moving if it is enabled, and the tweening
    -- orb is the one we are attached to
    if Gui.Orb and orb == Gui.Orb and Gui.Orbcam then
        Gui.OrbcamTweeningStart(newPos, poiPos, poi)
    end

    -- Turn off proximity prompts on this orb
    local normalPrompt = if orb:IsA("BasePart") then orb.NormalPrompt else orb.PrimaryPart.NormalPrompt
    local speakerPrompt = if orb:IsA("BasePart") then orb.SpeakerPrompt else orb.PrimaryPart.SpeakerPrompt
    normalPrompt.Enabled = false
    speakerPrompt.Enabled = false

    -- Store this so people attaching mid-flight can just jump to the target CFrame and FOV
    local orbCameraPos = Vector3.new(newPos.X, poiPos.Y, newPos.Z)
    targetForOrbTween[orb] = { Position = orbCameraPos, 
                                Poi = poi }

    orb:SetAttribute("tweening", true)
end

function Gui.OrbTweeningStop(orb)
    -- Turn back on the proximity prompts, but only for orbs we're not attached to
    if orb ~= Gui.Orb then
        local normalPrompt = if orb:IsA("BasePart") then orb.NormalPrompt else orb.PrimaryPart.NormalPrompt
        local speakerPrompt = if orb:IsA("BasePart") then orb.SpeakerPrompt else orb.PrimaryPart.SpeakerPrompt
        normalPrompt.Enabled = true
        speakerPrompt.Enabled = Gui.HasSpeakerPermission and orb.Speaker.Value == nil
    end

    targetForOrbTween[orb] = nil
    orb:SetAttribute("tweening", false)
end

-- Note that we will refuse to move the camera if there is nothing to look _at_
function Gui.OrbcamTweeningStart(newPos, poiPos, poi)
    if not Gui.Orbcam then return end
    if newPos == nil or poiPos == nil then return end

    local camera = workspace.CurrentCamera
	local tweenInfo = TweenInfo.new(
			Config.TweenTime, -- Time
			Enum.EasingStyle.Quad, -- EasingStyle
			Enum.EasingDirection.Out, -- EasingDirection
			0, -- RepeatCount (when less than zero the tween will loop indefinitely)
			false, -- Reverses (tween will reverse once reaching it's goal)
			0 -- DelayTime
		)

    local orbCameraPos = Vector3.new(newPos.X, poiPos.Y, newPos.Z)
    local verticalFOV = Gui.FOVForPoi(orbCameraPos, poi)

    if verticalFOV == nil then
        Gui.CameraTween = TweenService:Create(camera, tweenInfo, 
            {CFrame = CFrame.lookAt(orbCameraPos, poiPos)})
    else
        Gui.CameraTween = TweenService:Create(camera, tweenInfo, 
            {CFrame = CFrame.lookAt(orbCameraPos, poiPos),
            FieldOfView = verticalFOV})
    end

    Gui.CameraTween:Play()
end

-- Computes the vertical FOV for the player's camera at the given poi
function Gui.FOVForPoi(cameraPos, poi)
    if poi == nil then return end

    -- Adjust the zoom level
    local targets = {}
    for _, c in ipairs(poi:GetChildren()) do
        if c:IsA("ObjectValue") and c.Name == "Target" then
            if c.Value ~= nil then
                table.insert(targets, c.Value)
            end
        end
    end

    if #targets == 0 then
        return
    end

    local cameraCFrame = CFrame.lookAt(cameraPos, poi:GetPivot().Position)
    local camera = workspace.CurrentCamera
    local oldCameraCFrame = camera.CFrame
    local oldCameraFieldOfView = camera.FieldOfView
    camera.CFrame = cameraCFrame
    camera.FieldOfView = 70

    -- Find the most extreme points among all targets
    local extremeLeftCoord, extremeRightCoord, extremeTopCoord, extremeBottomCoord
    local extremeLeft, extremeRight, extremeTop, extremeBottom

    for _, t in ipairs(targets) do
        local extremities = {}
        local unitVectors = { X = Vector3.new(1,0,0),
                                Y = Vector3.new(0,1,0),
                                Z = Vector3.new(0,0,1)}

        for _, direction in ipairs({"X", "Y", "Z"}) do
            local extremeOne = t.CFrame * CFrame.new(0.5 * unitVectors[direction] * t.Size[direction])
            local extremeTwo = t.CFrame * CFrame.new(-0.5 * unitVectors[direction] * t.Size[direction])
            table.insert(extremities, extremeOne.Position)
            table.insert(extremities, extremeTwo.Position)
        end

        for _, pos in ipairs(extremities) do
            local screenPos = camera:WorldToScreenPoint(pos)
            if extremeLeftCoord == nil or screenPos.X < extremeLeftCoord then
                extremeLeftCoord = screenPos.X
                extremeLeft = pos
            end

            if extremeRightCoord == nil or screenPos.X > extremeRightCoord then
                extremeRightCoord = screenPos.X
                extremeRight = pos
            end

            if extremeTopCoord == nil or screenPos.Y < extremeTopCoord then
                extremeTopCoord = screenPos.Y
                extremeTop = pos
            end

            if extremeBottomCoord == nil or screenPos.Y > extremeBottomCoord then
                extremeBottomCoord = screenPos.Y
                extremeBottom = pos
            end
        end
    end

    if extremeTop == nil or extremeBottom == nil or extremeLeft == nil or extremeRight == nil then
        camera.CFrame = oldCameraCFrame
        camera.FieldOfView = oldCameraFieldOfView
        return
    end

    -- Compute the angles made with the current camera and the top and bottom
    local leftProj = camera.CFrame:ToObjectSpace(CFrame.new(extremeLeft)).Position
    local rightProj = camera.CFrame:ToObjectSpace(CFrame.new(extremeRight)).Position
    local topProj = camera.CFrame:ToObjectSpace(CFrame.new(extremeTop)).Position
    local bottomProj = camera.CFrame:ToObjectSpace(CFrame.new(extremeBottom)).Position
    local xMid = 0.5 * (leftProj.X + rightProj.X)
    local yMid = 0.5 * (topProj.Y + bottomProj.Y)
    
    local avgZ = 0.25 * ( leftProj.Z + rightProj.Z + topProj.Z + bottomProj.Z )
    topProj = Vector3.new(xMid, topProj.Y, avgZ)
    bottomProj = Vector3.new(xMid, bottomProj.Y, avgZ)
    leftProj = Vector3.new(leftProj.X, yMid, avgZ)
    rightProj = Vector3.new(rightProj.X, yMid, avgZ)
    
    --for _, apos in ipairs({leftProj, rightProj, topProj, bottomProj}) do
    --	if apos ~= nil then
    --		local pos = camera.CFrame:ToWorldSpace(CFrame.new(apos)).Position
    --		local p = Instance.new("Part")
    --		p.Name = "Bounder"
    --		p.Shape = Enum.PartType.Ball
    --		p.Color = Color3.new(0,0,1)
    --		p.Size = Vector3.new(0.5, 0.5, 0.5)
    --		p.Position = pos
    --		p.Anchored = true
    --		p.Parent = game.workspace
    --	end
    --end

    -- Compute the horizontal angle subtended by rectangle we have just defined
    local A = leftProj.Magnitude
    local B = rightProj.Magnitude
    local cosgamma = leftProj:Dot(rightProj) * 1/A * 1/B
    local horizontalAngle = nil

    if cosgamma < -1 or cosgamma > 1 then 
        camera.CFrame = oldCameraCFrame
        camera.FieldOfView = oldCameraFieldOfView
        return
    end
    
    horizontalAngle = math.acos(cosgamma)
    
    -- https://en.wikipedia.org/wiki/Field_of_view_in_video_games
    local aspectRatio = camera.ViewportSize.Y / camera.ViewportSize.X
    local verticalRadian = 2 * math.atan(math.tan(horizontalAngle / 2) * aspectRatio)
    local verticalFOV = math.deg(verticalRadian)
    verticalFOV = verticalFOV * Config.FOVFactor
    -- print("[Orb] Discovered vertical FOV is "..verticalFOV)

    -- Return camera to its original configuration
    camera.CFrame = oldCameraCFrame
    camera.FieldOfView = oldCameraFieldOfView

    return verticalFOV
end

function Gui.OrbcamOn(guiOff)
    OrbcamOnRemoteEvent:FireServer()

    if Gui.Orb == nil then return end
    local orb = Gui.Orb

    local poi, poiPos = Gui.PointOfInterest()
    if poi == nil or poiPos == nil then return end

	local camera = workspace.CurrentCamera
	storedCameraFOV = camera.FieldOfView

    local orbPos = orb:GetPivot().Position
    
    local character = localPlayer.Character
	if character and character.Head then
		storedCameraOffset = camera.CFrame.Position - character.Head.Position
	end
    
    if CollectionService:HasTag(Gui.Orb, Config.TransportTag) then
        -- A transport orb looks from the next stop back to the orb
        -- as it approaches
        camera.CameraType = Enum.CameraType.Watch
        camera.CameraSubject = if orb:IsA("BasePart") then orb else orb.PrimaryPart

        local nextStop = orb.NextStop.Value
        local nextStopPart = orb.Stops:FindFirstChild(tostring(nextStop)).Value.Marker

        camera.CFrame = CFrame.new(nextStopPart.Position + Vector3.new(0,20,0))
    else
        if camera.CameraType ~= Enum.CameraType.Scriptable then
            camera.CameraType = Enum.CameraType.Scriptable
        end

        -- If we are a normal orb we look from a height adjusted to the point of interest
        if targetForOrbTween[orb] == nil then
            -- The orb is not tweening
            local orbCameraPos = Vector3.new(orbPos.X, poiPos.Y, orbPos.Z)
            camera.CFrame = CFrame.lookAt(orbCameraPos, poiPos)

            local verticalFOV = Gui.FOVForPoi(orbCameraPos, poi)
            if verticalFOV ~= nil then
                camera.FieldOfView = verticalFOV
            end
        else
            -- The orb is tweening, jump to the target CFrame and FOV
            local tweenData = targetForOrbTween[orb]
            local verticalFOV = Gui.FOVForPoi(tweenData.Position, tweenData.Poi)
            camera.CFrame = CFrame.lookAt(tweenData.Position, tweenData.Poi:GetPivot().Position)

            if verticalFOV ~= nil then
                camera.FieldOfView = verticalFOV
            end
        end
    end
    
    if guiOff then
        if CollectionService:HasTag(Gui.Orb, Config.TransportTag) then
            luggageGui.Enabled = false
        else
            speakerGui.Enabled = false
            listenerGui.Enabled = false
        end

        StarterGui:SetCore("TopbarEnabled", false)
    end

    Gui.Orbcam = true
end

function Gui.OrbcamOff(guiOff)
    OrbcamOffRemoteEvent:FireServer()

	if Gui.CameraTween then Gui.CameraTween:Cancel() end

    if guiOff then
        if CollectionService:HasTag(Gui.Orb, Config.TransportTag) then
            luggageGui.Enabled = true
        else
            if Gui.Speaking then
                speakerGui.Enabled = true
            elseif Gui.Orb ~= nil then
                listenerGui.Enabled = true
            end
        end

	    StarterGui:SetCore("TopbarEnabled", true)
    end
	
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Custom
    if storedCameraFOV ~= nil then
        camera.FieldOfView = storedCameraFOV
    else
        camera.FieldOfView = 70
    end

    if Gui.Speaking then speakerGui.Enabled = true end
    if Gui.Orb ~= nil and not Gui.Speaking and not CollectionService:HasTag(Gui.Orb, Config.TransportTag) then
        listenerGui.Enabled = true
    end
	
	resetCameraSubject()
    Gui.Orbcam = false
end

-- guiOff sets whether we turn off the topbar and other
-- GUI elements, i.e. for when we use Shift-C
function Gui.ToggleOrbcam(guiOff)
    if Gui.Orbcam then
		Gui.OrbcamOff(guiOff)
	elseif not Gui.Orbcam and Gui.Orb ~= nil then
        Gui.OrbcamOn(guiOff)
	end
end

return Gui