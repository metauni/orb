local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Common = game:GetService("ReplicatedStorage").OrbCommon
local SoundService = game:GetService("SoundService")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local VRService = game:GetService("VRService")

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
local VRSpeakerChalkEquipRemoteEvent = Common.Remotes.VRSpeakerChalkEquip
local VRSpeakerChalkUnequipRemoteEvent = Common.Remotes.VRSpeakerChalkUnequip

local localPlayer

local storedCameraOffset = nil
local storedCameraFOV = nil
local targetForOrbTween = {} -- orb to target position and poi of tween

local Gui = {}
Gui.__index = Gui

function Gui.Init()
    localPlayer = Players.LocalPlayer
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
    Gui.ListenIcon = nil
    Gui.OrbcamIcon = nil
    Gui.SpeakerIcon = nil
    Gui.LuggageIcon = nil
    Gui.OrbReturnIcon = nil
    Gui.OrbcamGuiOff = false

    Gui.InitEar()

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

    -- 
    -- Attach and detach
    --

    OrbAttachSpeakerRemoteEvent.OnClientEvent:Connect(function(speaker,orb)
        Gui.RefreshPrompts(orb)
    end)
    OrbDetachSpeakerRemoteEvent.OnClientEvent:Connect(function(orb)
        Gui.RefreshPrompts(orb)
    end)

    -- If the Admin system is installed, the permission specified there
	-- overwrites the default "true" state of HasWritePermission
	local adminEvents = ReplicatedStorage:FindFirstChild("MetaAdmin")
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
                Gui.RefreshPrompts(orb)
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

    -- Setup Orbcam
    local ORBCAM_MACRO_KB = {Enum.KeyCode.LeftShift, Enum.KeyCode.C}
    local function CheckMacro(macro)
        for i = 1, #macro - 1 do
            if not UserInputService:IsKeyDown(macro[i]) then
                return
            end
        end

        -- Do not allow Shift-C to turn _off_ orbcam that was turned on
        -- via the topbar button
        if Gui.Orbcam and not Gui.OrbcamGuiOff then return end

        -- Do not allow the shortcut when not attached
        if Gui.Orb == nil then return end

        if Gui.OrbcamIcon:getToggleState() == "selected" then
            Gui.OrbcamIcon:deselect()
            Gui.OrbcamGuiOff = false
        else
            Gui.OrbcamGuiOff = true
            Gui.OrbcamIcon:select()
        end
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

    -- In VR we need to tell other clients when we equip the chalk
    if VRService.VREnabled then
        local chalkTool = localPlayer.Backpack:WaitForChild("MetaChalk", 20)
        if chalkTool ~= nil then
            chalkTool.Equipped:Connect(function()
                VRSpeakerChalkEquipRemoteEvent:FireServer()
            end)
            chalkTool.Unequipped:Connect(function()
                VRSpeakerChalkUnequipRemoteEvent:FireServer()
            end)
        else
            print("[MetaOrb] Failed to find MetaChalk tool")
        end
    end
	
    Gui.HandleVR()
    Gui.CreateTopbarItems()

	print("[Orb] Gui Initialised")
end

function Gui.MakePlayerTransparent(plr, transparency)
    if plr == nil then
        print("[MetaOrb] Passed nil player to MakePlayerTransparent")
        return
    end

    if plr.Character == nil then return end

    local character = plr.Character

    for _, desc in ipairs(character:GetDescendants()) do
		if desc:IsA("BasePart") then
			desc.Transparency = 1 - (transparency * (1 - desc.Transparency))
			desc.CastShadow = false
		end
	end

    -- origTransparency = 1 - 1/0.2 * (1 - newTransparency)
end

function Gui.HandleVR()
    VRSpeakerChalkEquipRemoteEvent.OnClientEvent:Connect(function(speaker)
		if Gui.Orb == nil then return end
        if Gui.Orb.Speaker.Value == nil then return end
        if Gui.Orb.Speaker.Value ~= speaker then return end

        if speaker == localPlayer then return end
        Gui.MakePlayerTransparent(speaker, 0.2)
	end)

    VRSpeakerChalkUnequipRemoteEvent.OnClientEvent:Connect(function(speaker)
		if Gui.Orb == nil then return end
        if Gui.Orb.Speaker.Value == nil then return end
        if Gui.Orb.Speaker.Value ~= speaker then return end

        if speaker == localPlayer then return end
        Gui.MakePlayerTransparent(speaker, 1/0.2)
	end)
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
function Gui.RefreshPrompts(orb)
    local speakerPrompt = if orb:IsA("BasePart") then orb:FindFirstChild("SpeakerPrompt") else orb.PrimaryPart:FindFirstChild("SpeakerPrompt")

    -- If we are not currently attached as either or speaker
    -- or listener, make the speaker prompt enabled
    if speakerPrompt ~= nil and Gui.Orb ~= orb then
        speakerPrompt.Enabled = Gui.HasSpeakerPermission and not orb:GetAttribute("tweening")
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

    return closestPoi
end

function Gui.ListenOn()
    Gui.Listening = true

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
        local luggagePrompt = if orb:IsA("BasePart") then orb.LuggagePrompt else orb.PrimaryPart.LuggagePrompt
        luggagePrompt.Enabled = true
        Gui.OrbcamOff()
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
        
        if Gui.RunningConnection then
            Gui.RunningConnection:Disconnect()
            Gui.RunningConnection = nil
        end
    end

    OrbDetachRemoteEvent:FireServer(orb)
    Gui.Orb = nil
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

    Gui.SpeakerIcon:setEnabled(true)
    Gui.SpeakerIcon:select()
    Gui.OrbcamIcon:setEnabled(true)
    Gui.OrbReturnIcon:setEnabled(true)

    -- This event fires when the running speed changes
    local humanoid = localPlayer.Character:WaitForChild("Humanoid")
    if VRService.VREnabled then
        local counter = 0
        local timeTillPositionCheck = 2
        local playerPosAtLastCheck = localPlayer.Character.PrimaryPart.Position

        Gui.RunningConnection = RunService.Heartbeat:Connect(function(step)
            counter = counter + step
            if counter >= timeTillPositionCheck then
                counter -= timeTillPositionCheck
                
                if localPlayer.Character ~= nil and localPlayer.Character.PrimaryPart ~= nil then
                    if (localPlayer.Character.PrimaryPart.Position - playerPosAtLastCheck).Magnitude > 2 then
                        OrbSpeakerMovedRemoteEvent:FireServer(Gui.Orb)
                    end
                    playerPosAtLastCheck = localPlayer.Character.PrimaryPart.Position
                end
            end
        end)
    else
        Gui.RunningConnection = humanoid.Running:Connect(function(speed)
            if speed == 0 then
                -- They were moving and then stood still
                OrbSpeakerMovedRemoteEvent:FireServer(Gui.Orb)
            end
        end)
    end
end

function Gui.CreateTopbarItems()
    if ReplicatedStorage:FindFirstChild("Icon") == nil then
        print("[Orb] Could not find Icon module")
        return
    end
    
    -- ear icon is https://fonts.google.com/icons?icon.query=hearing
    -- eye icon is https://fonts.google.com/icons?icon.query=eye
    -- luggage is https://fonts.google.com/icons?icon.query=luggage
    -- return is https://fonts.google.com/icons?icon.query=back
    local Icon = require(game:GetService("ReplicatedStorage").Icon)
    local Themes =  require(game:GetService("ReplicatedStorage").Icon.Themes)
    
    local icon, iconEye, iconSpeaker, iconLuggage, iconReturn

    icon = Icon.new()
    icon:setImage("rbxassetid://9675350772")
    icon:setLabel("Listener")
    icon:setEnabled(false)
    icon.deselectWhenOtherIconSelected = false
    icon:bindEvent("deselected", function(self)
        if iconEye.isSelected then
            iconEye:deselect()
        end
        
        Gui.Detach()
        iconEye:setEnabled(false)
        icon:setEnabled(false)
        iconReturn:setEnabled(false)
    end)
    icon:setTheme(Themes["BlueGradient"])
    Gui.ListenIcon = icon

    iconSpeaker = Icon.new()
    iconSpeaker:setImage("rbxassetid://9675604658")
    iconSpeaker:setLabel("Speaker")
    iconSpeaker:setTheme(Themes["BlueGradient"])
    iconSpeaker:setEnabled(false)
    iconSpeaker.deselectWhenOtherIconSelected = false
    iconSpeaker:bindEvent("deselected", function(self)
        if iconEye.isSelected then
            iconEye:deselect()
        end
        
        Gui.Detach()
        iconEye:setEnabled(false)
        iconSpeaker:setEnabled(false)
        iconReturn:setEnabled(false)
    end)
    Gui.SpeakerIcon = iconSpeaker

    iconLuggage = Icon.new()
    iconLuggage:setImage("rbxassetid://9679458066")
    iconLuggage:setLabel("Luggage")
    iconLuggage:setTheme(Themes["BlueGradient"])
    iconLuggage:setEnabled(false)
    iconLuggage.deselectWhenOtherIconSelected = false
    iconLuggage:bindEvent("deselected", function(self)
        if iconEye.isSelected then
            iconEye:deselect()
        end
        
        Gui.Detach()
        iconEye:setEnabled(false)
        iconLuggage:setEnabled(false)
    end)
    Gui.LuggageIcon = iconLuggage

    iconEye = Icon.new()
    iconEye:setImage("rbxassetid://9675397382")
    iconEye:setLabel("Orbcam")
    iconEye:setTheme(Themes["BlueGradient"])
    iconEye:setEnabled(false)
    iconEye.deselectWhenOtherIconSelected = false
    iconEye:bindEvent("selected", function(self)
        Gui.ToggleOrbcam(false)
    end)
    iconEye:bindEvent("deselected", function(self)
        Gui.ToggleOrbcam(false)
    end)
    Gui.OrbcamIcon = iconEye

    iconReturn = Icon.new()
    iconReturn:setImage("rbxassetid://9727704068")
    iconReturn:setTheme(Themes["BlueGradient"])
    iconReturn:setEnabled(false)
    iconReturn:bindEvent("selected", function(self)
        OrbTeleportRemoteEvent:FireServer(Gui.Orb)
        iconReturn:deselect()
    end)
    Gui.OrbReturnIcon = iconReturn
end

function Gui.Attach(orb)
    -- Disconnect from the old source if there is one
    if Gui.Orb then Gui.Detach() end
    Gui.Orb = orb

    if CollectionService:HasTag(orb, Config.TransportTag) then
        local luggagePrompt = if orb:IsA("BasePart") then orb.LuggagePrompt else orb.PrimaryPart.LuggagePrompt
        luggagePrompt.Enabled = false

        Gui.LuggageIcon:setEnabled(true)
        Gui.LuggageIcon:select()
        Gui.OrbcamIcon:setEnabled(true)
    else
        -- Disable the proximity prompt
        local normalPrompt = if orb:IsA("BasePart") then orb.NormalPrompt else orb.PrimaryPart.NormalPrompt
        local speakerPrompt = if orb:IsA("BasePart") then orb.SpeakerPrompt else orb.PrimaryPart.SpeakerPrompt
        normalPrompt.Enabled = false
        speakerPrompt.Enabled = false
        
        Gui.ListenIcon:setEnabled(true)
        Gui.ListenIcon:select()
        Gui.OrbcamIcon:setEnabled(true)
        Gui.OrbReturnIcon:setEnabled(true)
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

function Gui.OrbTweeningStart(orb, waypoint, poi)
    if orb == nil then
        print("[Orb] OrbTweeningStart passed a nil orb")
        return
    end

    if waypoint == nil then
        print("[Orb] OrbTweeningStart passed a nil waypoint")
        return
    end

    if poi == nil then
        print("[Orb] Warning: OrbTweeningStart passed a nil poi")
    end

    -- Start camera moving if it is enabled, and the tweening
    -- orb is the one we are attached to
    if Gui.Orb and orb == Gui.Orb and Gui.Orbcam then
        Gui.OrbcamTweeningStart(waypoint.Position, poi)
    end

    -- Turn off proximity prompts on this orb
    local normalPrompt = if orb:IsA("BasePart") then orb.NormalPrompt else orb.PrimaryPart.NormalPrompt
    local speakerPrompt = if orb:IsA("BasePart") then orb.SpeakerPrompt else orb.PrimaryPart.SpeakerPrompt
    normalPrompt.Enabled = false
    speakerPrompt.Enabled = false

    -- Store this so people attaching mid-flight can just jump to the target CFrame and FOV
    targetForOrbTween[orb] = { Waypoint = waypoint,
                                Poi = poi }

    orb:SetAttribute("tweening", true)
end

function Gui.OrbTweeningStop(orb)
    -- Turn back on the proximity prompts, but only for orbs we're not attached to
    if orb ~= Gui.Orb then
        local normalPrompt = if orb:IsA("BasePart") then orb.NormalPrompt else orb.PrimaryPart.NormalPrompt
        local speakerPrompt = if orb:IsA("BasePart") then orb.SpeakerPrompt else orb.PrimaryPart.SpeakerPrompt
        normalPrompt.Enabled = true
        speakerPrompt.Enabled = Gui.HasSpeakerPermission and (orb.Speaker.Value == nil)
    end

    targetForOrbTween[orb] = nil
    orb:SetAttribute("tweening", false)
end

-- Note that we will refuse to move the camera if there is nothing to look _at_
function Gui.OrbcamTweeningStart(newPos, poi)
    if Gui.Orbcam == nil then return end
    if newPos == nil then
        print("[Orb] OrbcamTweeningStart passed a nil position")
        return
    end
    
    if poi == nil then
        print("[Orb] OrbcamTweeningStart passed a nil poi")
        return
    end

    local poiPos = poi:GetPivot().Position

    local camera = workspace.CurrentCamera
	local tweenInfo = TweenInfo.new(
			Config.TweenTime, -- Time
			Enum.EasingStyle.Quad, -- EasingStyle
			Enum.EasingDirection.Out, -- EasingDirection
			0, -- RepeatCount (when less than zero the tween will loop indefinitely)
			false, -- Reverses (tween will reverse once reaching it's goal)
			0 -- DelayTime
		)


    -- By default the camera looks from (newPos.X, poiPos.Y, newPos.Z)
    -- but this can be overridden by specifying a Camera ObjectValue
    local orbCameraPos = Vector3.new(newPos.X, poiPos.Y, newPos.Z)

    local cameraOverride = poi:FindFirstChild("Camera")
    if cameraOverride ~= nil then
        local cameraPart = cameraOverride.Value
        if cameraPart ~= nil then
            orbCameraPos = cameraPart.Position
        end
    end

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
    local camera = workspace.CurrentCamera

    if poi == nil then
        return camera.FieldOfView
    end

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
        return camera.FieldOfView
    end

    local cameraCFrame = CFrame.lookAt(cameraPos, poi:GetPivot().Position)
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

    -- Return camera to its original configuration
    camera.CFrame = oldCameraCFrame
    camera.FieldOfView = oldCameraFieldOfView

    return verticalFOV
end

function Gui.OrbcamOn()
    local guiOff = Gui.OrbcamGuiOff
    OrbcamOnRemoteEvent:FireServer()

    if Gui.Orb == nil then return end
    local orb = Gui.Orb
    
	local camera = workspace.CurrentCamera
	storedCameraFOV = camera.FieldOfView
    
    local character = localPlayer.Character
	if character and character.Head then
		storedCameraOffset = camera.CFrame.Position - character.Head.Position
	end
    
    if CollectionService:HasTag(Gui.Orb, Config.TransportTag) then
        -- A transport orb looks from the next stop back to the orb as it approaches
        camera.CameraType = Enum.CameraType.Watch
        camera.CameraSubject = if orb:IsA("BasePart") then orb else orb.PrimaryPart

        local nextStop = orb.NextStop.Value
        local nextStopPart = orb.Stops:FindFirstChild(tostring(nextStop)).Value.Marker

        camera.CFrame = CFrame.new(nextStopPart.Position + Vector3.new(0,20,0))

        if guiOff then
            StarterGui:SetCore("TopbarEnabled", false)
        end
    
        Gui.Orbcam = true
        return
    end

    -- If the orb is tweening, we use the stored data for poi
    local tweenData = targetForOrbTween[orb]

    local poi = nil
    local orbPos = nil

    if tweenData ~= nil then
        poi = tweenData.Poi
        orbPos = tweenData.Waypoint.Position
    else
        poi = Gui.PointOfInterest()
        orbPos = orb:GetPivot().Position
    end

    if poi == nil or orbPos == nil then
        print("[Orb] Could not find point of interest to look at")
        return
    end

    if camera.CameraType ~= Enum.CameraType.Scriptable then
        camera.CameraType = Enum.CameraType.Scriptable
    end

    local poiPos = poi:GetPivot().Position    

    -- By default the camera looks from (orbPos.X, poiPos.Y, orbPos.Z)
    -- but this can be overridden by specifying a Camera ObjectValue
    local orbCameraPos = Vector3.new(orbPos.X, poiPos.Y, orbPos.Z)

    local cameraOverride = poi:FindFirstChild("Camera")
    if cameraOverride ~= nil then
        local cameraPart = cameraOverride.Value
        if cameraPart ~= nil then
            orbCameraPos = cameraPart.Position
        end
    end
    
    camera.CFrame = CFrame.lookAt(orbCameraPos, poiPos)

    local verticalFOV = Gui.FOVForPoi(orbCameraPos, poi)
    camera.FieldOfView = verticalFOV

    if guiOff then
        StarterGui:SetCore("TopbarEnabled", false)
    end

    Gui.Orbcam = true
end

function Gui.OrbcamOff()
    local guiOff = Gui.OrbcamGuiOff
    OrbcamOffRemoteEvent:FireServer()

	if Gui.CameraTween then Gui.CameraTween:Cancel() end

    if guiOff then
	    StarterGui:SetCore("TopbarEnabled", true)
    end
	
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Custom
    if storedCameraFOV ~= nil then
        camera.FieldOfView = storedCameraFOV
    else
        camera.FieldOfView = 70
    end
	
	resetCameraSubject()
    Gui.Orbcam = false
end

function Gui.ToggleOrbcam()
    if Gui.Orbcam then
		Gui.OrbcamOff()
	elseif not Gui.Orbcam and Gui.Orb ~= nil then
        Gui.OrbcamOn()
	end
end

return Gui