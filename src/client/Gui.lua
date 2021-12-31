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
local OrbSpeakerMovedRemoteEvent = Common.Remotes.OrbSpeakerMoved
local OrbTeleportRemoteEvent = Common.Remotes.OrbTeleport
local OrbTweeningStartRemoteEvent = Common.Remotes.OrbTweeningStart
local OrbTweeningStopRemoteEvent = Common.Remotes.OrbTweeningStop

local listenerGui, speakerGui, listenButton, detachButton, returnButton
local viewportFrame, peekButton, detachSpeakerButton, speakerViewportFrame
local localPlayer

local Gui = {}
Gui.__index = Gui

function Gui.Init()
    localPlayer = Players.LocalPlayer
    listenerGui = localPlayer.PlayerGui:WaitForChild("OrbGui",math.huge)
    speakerGui = localPlayer.PlayerGui:WaitForChild("OrbGuiSpeaker",math.huge)
    Gui.Listening = false
    Gui.Speaking = false
    Gui.Orb = nil
    Gui.RunningConnection = nil
    Gui.ViewportOn = false
    Gui.HasSpeakerPermission = true -- can attach as speaker?
    Gui.Orbcam = false
    Gui.CameraTween = nil

    listenButton = listenerGui.ListenButton
    detachButton = listenerGui.DetachButton
    detachSpeakerButton = speakerGui.DetachButton
    returnButton = listenerGui.ReturnButton
    peekButton = listenerGui.PeekButton
    viewportFrame = listenerGui.ViewportFrame
    speakerViewportFrame = speakerGui.ViewportFrame

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
    OrbAttachRemoteEvent.OnClientEvent:Connect(Gui.Attach)
    OrbAttachSpeakerRemoteEvent.OnClientEvent:Connect(Gui.AttachSpeaker)

    -- 
    -- Teleporting
    --

    returnButton.Activated:Connect(function()
        -- Teleport us to our ghost
        OrbTeleportRemoteEvent:FireServer(Gui.Orb)
        Gui.Detach()
    end)

    --
    -- Viewport
    --

    peekButton.Activated:Connect(function()
        Gui.ViewportOn = not Gui.ViewportOn

        if Gui.ViewportOn then Gui.PopulateViewport() end	
	
	    viewportFrame.Visible = Gui.ViewportOn
    end)

    -- If the Admin system is installed, the permission specified there
	-- overwrites the default "true" state of HasWritePermission
	local adminEvents = game:GetService("ReplicatedStorage"):FindFirstChild("MetaAdmin")
	if adminEvents then
		local isScribeRF = adminEvents:FindFirstChild("IsScribe")

		if isScribeRF then
			Gui.HasSpeakerPermission = isScribeRF:InvokeServer()
		end

		-- Listen for updates to the permissions
		local permissionUpdateRE = adminEvents:FindFirstChild("PermissionsUpdate")
		permissionUpdateRE.OnClientEvent:Connect(function()
			-- Request the new permission
			if isScribeRF then
				Gui.HasSpeakerPermission = isScribeRF:InvokeServer()
			end
		end)
	end

    -- Give speaker permissions in Studio
    if RunService:IsStudio() then
        Gui.HasSpeakerPermission = true
    end

    -- Install proximity prompts
    local orbs = CollectionService:GetTagged(Config.ObjectTag)
    for _, orb in ipairs(orbs) do
        -- Attach proximity prompts
        local proximityPrompt = orb:FindFirstChild("NormalPrompt")
        local speakerPrompt = orb:FindFirstChild("SpeakerPrompt")

        -- Note that this gets called again after player reset
        if proximityPrompt == nil and speakerPrompt == nil then
            proximityPrompt = Instance.new("ProximityPrompt")
            proximityPrompt.Name = "NormalPrompt"
            proximityPrompt.ActionText = "Attach"
            proximityPrompt.MaxActivationDistance = 8
            proximityPrompt.HoldDuration = 1
            proximityPrompt.ObjectText = "Orb"
            proximityPrompt.Parent = orb

            -- Attach speaker prompts
            speakerPrompt = Instance.new("ProximityPrompt")
            speakerPrompt.Name = "SpeakerPrompt"
            speakerPrompt.ActionText = "Attach as Speaker"
            speakerPrompt.UIOffset = Vector2.new(0,75)
            speakerPrompt.MaxActivationDistance = 8
            speakerPrompt.HoldDuration = 1
            speakerPrompt.KeyboardKeyCode = Enum.KeyCode.F
            speakerPrompt.GamepadKeyCode = Enum.KeyCode.ButtonY
            speakerPrompt.ObjectText = "Orb"
            speakerPrompt.Enabled = Gui.HasSpeakerPermission
            speakerPrompt.Parent = orb

            ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
                if prompt.Parent == orb and prompt.Name == "NormalPrompt" then
                    OrbAttachRemoteEvent:FireServer(orb)
                    Gui.Attach(orb)
                end
    
                if prompt.Parent == orb and prompt.Name == "SpeakerPrompt" then
                    -- Only allow someone to attach if there is no current speaker
                    if orb.Speaker.Value == 0 then
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
        Gui.ToggleOrbcam()
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

-- A point of interest is any object tagged with either
-- metaboard or metaorb_poi. Returns the closest point
-- of interest to the current orb and its position and nil if none can
-- be found. Note that a point of interest is either nil,
-- a BasePart or a Model with non-nil PrimaryPart
function Gui.PointOfInterest()
    if Gui.Orb == nil then return end

    local boards = CollectionService:GetTagged("metaboard")
    local pois = CollectionService:GetTagged("metaorb_poi")

    if #boards == 0 and #pois == 0 then return nil end

    -- Find the closest board
    local closestPoi = nil
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
                local distance = (pos - Gui.Orb.Position).Magnitude
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

function Gui.PopulateViewport()
    viewportFrame:ClearAllChildren()

    if Gui.Orb == nil then return end
    local pointOfInterest, poiPosition = Gui.PointOfInterest()
    if pointOfInterest == nil or poiPosition == nil then return end

    -- Copy the point of interest and put it into the viewport
    local poiCopy = pointOfInterest:Clone()
    for _, tag in ipairs(CollectionService:GetTags(poiCopy)) do
        CollectionService:RemoveTag(poiCopy, tag)
    end
    poiCopy.Parent = viewportFrame
	
	local viewportCamera = Instance.new("Camera")
	viewportFrame.CurrentCamera = viewportCamera
	viewportCamera.Parent = viewportFrame
	
    local orbCameraPos = Vector3.new(Gui.Orb.Position.X, poiPosition.Y, Gui.Orb.Position.Z)

	viewportCamera.CFrame = CFrame.new( orbCameraPos, poiPosition )
end

function Gui.ListenOn()
    Gui.Listening = true
    listenButton.BackgroundColor3 = Color3.new(0, 0.920562, 0.199832)
    listenButton.BackgroundTransparency = 0.2

    if Gui.Orb then
        -- Enum.ListenerType.ObjectPosition (if player rotates camera, it changes angle of sound sources)
        -- Enum.LIstenerType.ObjectCFrame (sound from the position and angle of object)
        SoundService:SetListener(Enum.ListenerType.ObjectCFrame, Gui.Orb)
    end
end

function Gui.ListenOff()
    Gui.Listening = false
    listenButton.BackgroundColor3 = Color3.new(0,0,0)
    listenButton.BackgroundTransparency = 0.75

    if Gui.Orb then
        SoundService:SetListener(Enum.ListenerType.Camera)
    end
end

-- Detach, as listener or speaker
function Gui.Detach()
    if not Gui.Orb then return end
    local orb = Gui.Orb

    -- If the orb is currently on the move, do not enable it yet
    if not orb:GetAttribute("tweening") then
        orb.NormalPrompt.Enabled = true
        orb.SpeakerPrompt.Enabled = Gui.HasSpeakerPermission
    end

    Gui.ListenOff()
    Gui.OrbcamOff()
    Gui.Speaking = false
    listenerGui.Enabled = false
    speakerGui.Enabled = false

    if Gui.RunningConnection then
        Gui.RunningConnection:Disconnect()
        Gui.RunningConnection = nil
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

    -- Get rid of waypoints and such
    orbClone:ClearAllChildren()

    orbClone.Position = Vector3.new(0,0,0)
    orbClone.Name = "Orb"
    orbClone.Parent = speakerViewportFrame
    speakerViewportFrame.Camera.CFrame = CFrame.new(orbClone.Position + Vector3.new(0, 1.3 * orbClone.Size.Y, 0), orbClone.Position)
end

function Gui.AttachSpeaker(orb)
    -- Disable the proximity prompt
    orb.NormalPrompt.Enabled = false
    orb.SpeakerPrompt.Enabled = false
    
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
    -- Disable the proximity prompt
    orb.NormalPrompt.Enabled = false
    orb.SpeakerPrompt.Enabled = false

    -- Disconnect from the old source if there is one
    if Gui.Orb then Gui.Detach() end
    
    listenerGui.Enabled = true
    Gui.Orb = orb
end

-- 
-- Orbcam
--

local function resetCameraSubject()
	local localPlayer = Players.LocalPlayer

	if workspace.CurrentCamera and localPlayer.Character then
		local humanoid = localPlayer.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			workspace.CurrentCamera.CameraSubject = humanoid
		end
	end
end

function Gui.OrbTweeningStart(orb, newPos, poiPos)
    -- Start camera moving if it is enabled, and the tweening
    -- orb is the one we are attached to
    if Gui.Orb and orb == Gui.Orb and Gui.Orbcam then
        Gui.OrbcamTweeningStart(newPos, poiPos)
    end

    -- Turn off proximity prompts on this orb
    orb.NormalPrompt.Enabled = false
    orb.SpeakerPrompt.Enabled = false
    orb:SetAttribute("tweening", true)
end

function Gui.OrbTweeningStop(orb)
    -- Turn back on the proximity prompts, but only for orbs we're not attached to
    if orb ~= Gui.Orb then
        orb.NormalPrompt.Enabled = true
        orb.SpeakerPrompt.Enabled = Gui.HasSpeakerPermission
    end

    orb:SetAttribute("tweening", false)
end

-- Note that we will refuse to move the camera if there is nothing to look _at_
function Gui.OrbcamTweeningStart(newPos, poiPos)
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

    Gui.CameraTween = TweenService:Create(camera, tweenInfo, 
        {CFrame = CFrame.new(orbCameraPos, poiPos)})

    Gui.CameraTween:Play()
end

function Gui.OrbcamOn()
    if Gui.Orb == nil then return end

    local poi, poiPos = Gui.PointOfInterest()
    if poi == nil or poiPos == nil then return end

	local camera = workspace.CurrentCamera
	
	if camera.CameraType ~= Enum.CameraType.Scriptable then
		camera.CameraType = Enum.CameraType.Scriptable
	end
	
    local orbCameraPos = Vector3.new(Gui.Orb.Position.X, poiPos.Y, Gui.Orb.Position.Z)
	camera.CFrame = CFrame.new(orbCameraPos,poiPos)
    
	speakerGui.Enabled = false
    listenerGui.Enabled = false
	StarterGui:SetCore("TopbarEnabled", false)
    Gui.Orbcam = true
end

function Gui.OrbcamOff()
	if Gui.CameraTween then Gui.CameraTween:Cancel() end
	StarterGui:SetCore("TopbarEnabled", true)
	
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Custom

    if Gui.Speaking then speakerGui.Enabled = true end
    if Gui.Orb ~= nil and not Gui.Speaking then listenerGui.Enabled = true end
	
	resetCameraSubject()
    Gui.Orbcam = false
end

function Gui.ToggleOrbcam()
    if Gui.Orbcam then
		Gui.OrbcamOff()
	elseif not Gui.Orbcam and Gui.Orb ~= nil and Gui.HasSpeakerPermission then
        Gui.OrbcamOn()
	end
end

return Gui