local Common = game:GetService("ReplicatedStorage").OrbCommon
local SoundService = game:GetService("SoundService")
local CollectionService = game:GetService("CollectionService")
local ProximityPromptService = game:GetService("ProximityPromptService")

local Players = game:GetService("Players")
local Config = require(Common.Config)

local OrbAttachRemoteEvent = Common.Remotes.OrbAttach
local OrbDetachRemoteEvent = Common.Remotes.OrbDetach
local OrbAttachSpeakerRemoteEvent = Common.Remotes.OrbAttachSpeaker
local OrbSpeakerMovedRemoteEvent = Common.Remotes.OrbSpeakerMoved
local OrbTeleportRemoteEvent = Common.Remotes.OrbTeleport

local listenerGui, speakerGui, listenButton, detachButton, teleportButton
local viewportFrame, boardButton, detachSpeakerButton
local localPlayer

local Gui = {}
Gui.__index = Gui

function Gui.Init()
    localPlayer = Players.LocalPlayer
    listenerGui = localPlayer.PlayerGui.OrbGui
    speakerGui = localPlayer.PlayerGui.OrbGuiSpeaker
    Gui.Listening = false
    Gui.Speaking = false
    Gui.Orb = nil
    Gui.RunningConnection = nil
    Gui.ViewportOn = false
    Gui.HasSpeakerPermission = true -- can attach as speaker?

    listenButton = listenerGui.ListenButton
    detachButton = listenerGui.DetachButton
    detachSpeakerButton = speakerGui.DetachButton
    teleportButton = listenerGui.TeleportButton
    boardButton = listenerGui.BoardButton
    viewportFrame = listenerGui.ViewportFrame
    
    -- Disable the viewport frame if there are no boards
    local boards = CollectionService:GetTagged("metaboard")
    if #boards == 0 then
        boardButton.Visible = false
    end

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

    teleportButton.Activated:Connect(function()
        -- Teleport us to our ghost
        OrbTeleportRemoteEvent:FireServer(Gui.Orb)
        Gui.Detach()
    end)

    --
    -- Viewport
    --

    boardButton.Activated:Connect(function()
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

    -- Install proximity prompts
    local orbs = CollectionService:GetTagged(Config.ObjectTag)
    for _, orb in ipairs(orbs) do
        -- Attach proximity prompts
        local proximityPrompt = Instance.new("ProximityPrompt")
        proximityPrompt.Name = "NormalPrompt"
        proximityPrompt.ActionText = "Attach"
        proximityPrompt.MaxActivationDistance = 8
        proximityPrompt.HoldDuration = 1
        proximityPrompt.ObjectText = "Orb"
        proximityPrompt.Parent = orb

        -- Attach speaker prompts
        local speakerPrompt = Instance.new("ProximityPrompt")
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

	print("[Orb] Gui Initialised")
end

function Gui.PopulateViewport()
    viewportFrame:ClearAllChildren()
	local boards = CollectionService:GetTagged("metaboard")
	if #boards == 0 then return end
    if not Gui.Orb then return end

    -- Find the closest board
    local closestBoard = nil
    local minDistance = math.huge

    for _, board in ipairs(boards) do
        local distance = (board.Position - Gui.Orb.Position).Magnitude
        if distance < minDistance then
            minDistance = distance
            closestBoard = board
        end 
    end

    if not closestBoard then return end

    -- Put the board into the frame (we don't want to clone as this will trigger things)
    local boardCopy = Instance.new("Part")
    boardCopy.Size = closestBoard.Size
    boardCopy.Color = closestBoard.Color
    boardCopy.Material = closestBoard.Material
    boardCopy.CFrame = closestBoard.CFrame
    boardCopy.Parent = viewportFrame

    -- Grab all the curves
    if closestBoard:FindFirstChild("Canvas") and closestBoard.Canvas:FindFirstChild("Curves") then
        local curveClone = closestBoard.Canvas.Curves:Clone()
        curveClone.Parent = viewportFrame
    end
	
	local viewportCamera = Instance.new("Camera")
	viewportFrame.CurrentCamera = viewportCamera
	viewportCamera.Parent = viewportFrame
	
    local orbCameraPos = Vector3.new(Gui.Orb.Position.X, boardCopy.Position.Y, Gui.Orb.Position.Z)

	viewportCamera.CFrame = CFrame.new( orbCameraPos, closestBoard.Position )
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

    Gui.Orb.NormalPrompt.Enabled = true
    if Gui.HasSpeakerPermission then
        Gui.Orb.SpeakerPrompt.Enabled = true
    end

    Gui.ListenOff()
    Gui.Speaking = false
    listenerGui.Enabled = false
    speakerGui.Enabled = false

    if Gui.RunningConnection then
        Gui.RunningConnection:Disconnect()
        Gui.RunningConnection = nil
    end

    OrbDetachRemoteEvent:FireServer(Gui.Orb)
    Gui.Orb = nil
end

function Gui.AttachSpeaker(orb)
    -- Disable the proximity prompt
    orb.NormalPrompt.Enabled = false
    orb.SpeakerPrompt.Enabled = false
    
    -- Disconnect from the old source if there is one
    if Gui.Orb then Gui.Detach() end
    
    speakerGui.Enabled = true
    Gui.Orb = orb
    Gui.Speaking = true

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

return Gui