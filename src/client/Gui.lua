local Common = game:GetService("ReplicatedStorage").OrbCommon
local SoundService = game:GetService("SoundService")
local CollectionService = game:GetService("CollectionService")

local Players = game:GetService("Players")
local Config = require(Common.Config)

local OrbAttachRemoteEvent = Common.Remotes.OrbAttach
local OrbDetachRemoteEvent = Common.Remotes.OrbDetach
local OrbBecomeSpeakerRemoteEvent = Common.Remotes.OrbBecomeSpeaker
local OrbSpeakerMovedRemoteEvent = Common.Remotes.OrbSpeakerMoved
local OrbTeleportRemoteEvent = Common.Remotes.OrbTeleport

local listenerGui, listenButton, detachButton, speakerButton, teleportButton
local viewportFrame, boardButton
local localPlayer

local Gui = {}
Gui.__index = Gui

function Gui.Init()
    localPlayer = Players.LocalPlayer
    listenerGui = localPlayer.PlayerGui.OrbListenerGui
    Gui.Listening = false
    Gui.Speaking = false
    Gui.Orb = nil
    Gui.RunningConnection = nil
    Gui.ViewportOn = false

    listenButton = listenerGui.ListenButton
    detachButton = listenerGui.DetachButton
    speakerButton = listenerGui.SpeakerButton
    teleportButton = listenerGui.TeleportButton
    boardButton = listenerGui.BoardButton
    viewportFrame = listenerGui.ViewportFrame
    
    -- Disable the viewport frame if there are no boards
    local boards = CollectionService:GetTagged("metaboard")
    if #boards == 0 then
        boardButton.Visible = false
        speakerButton.Position += UDim2.new(0,0,0,-45)
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
    -- Speaking
    --

    local function toggleSpeaker()
        if Gui.Speaking then
            Gui.SpeakerOff()
        else
            Gui.SpeakerOn()
        end
    end

    speakerButton.Activated:Connect(toggleSpeaker)

    -- 
    -- Attach and detach
    --

    detachButton.Activated:Connect(Gui.Detach)
    OrbAttachRemoteEvent.OnClientEvent:Connect(Gui.Attach)

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

	print("Orb Gui Initialised")
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

function Gui.SpeakerOn()
    Gui.Speaking = true
    speakerButton.BackgroundColor3 = Color3.new(0, 0.920562, 0.199832)
    --speakerButton.BackgroundTransparency = 0.2

    if Gui.Orb then
        OrbBecomeSpeakerRemoteEvent:FireServer(Gui.Orb, "on")
    end

    -- This event fires when the running speed changes
    local humanoid = localPlayer.Character:WaitForChild("Humanoid")
    Gui.RunningConnection = humanoid.Running:Connect(function(speed)
        if speed == 0 then
            -- They were moving and then stood still
            OrbSpeakerMovedRemoteEvent:FireServer(Gui.Orb)
        end
    end)
end

function Gui.SpeakerOff()
    Gui.Speaking = false
    speakerButton.BackgroundColor3 = Color3.new(0,0,0)
    --speakerButton.BackgroundTransparency = 0.75

    if Gui.Orb then
        OrbBecomeSpeakerRemoteEvent:FireServer(Gui.Orb, "off")
    end

    if Gui.RunningConnection then
        Gui.RunningConnection:Disconnect()
        Gui.RunningConnection = nil
    end
end

function Gui.ListenOn()
    Gui.Listening = true
    listenButton.BackgroundColor3 = Color3.new(0, 0.920562, 0.199832)
    --listenButton.BackgroundTransparency = 0.2

    if Gui.Orb then
        -- Enum.ListenerType.ObjectPosition (if player rotates camera, it changes angle of sound sources)
        -- Enum.LIstenerType.ObjectCFrame (sound from the position and angle of object)
        SoundService:SetListener(Enum.ListenerType.ObjectCFrame, Gui.Orb)
    end
end

function Gui.ListenOff()
    Gui.Listening = false
    listenButton.BackgroundColor3 = Color3.new(0,0,0)
    --listenButton.BackgroundTransparency = 0.75

    if Gui.Orb then
        SoundService:SetListener(Enum.ListenerType.Camera)
    end
end

function Gui.Detach()
    Gui.Orb.ProximityPrompt.Enabled = true
    Gui.ListenOff()
    Gui.SpeakerOff()
    listenerGui.Enabled = false

    OrbDetachRemoteEvent:FireServer(Gui.Orb)
    Gui.Orb = nil
end

function Gui.Attach(orb)
    -- Disconnect from the old source if there is one
    if Gui.Orb then Gui.Detach() end
    
    listenerGui.Enabled = true
    Gui.Orb = orb

    -- Disable the proximity prompt
    orb.ProximityPrompt.Enabled = false
end

return Gui