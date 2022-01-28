local Common = game:GetService("ReplicatedStorage").OrbCommon
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Config = require(Common.Config)

local OrbAttachRemoteEvent = Common.Remotes.OrbAttach
local OrbDetachRemoteEvent = Common.Remotes.OrbDetach
local OrbListenOnRemoteEvent = Common.Remotes.OrbListenOn
local OrbListenOffRemoteEvent = Common.Remotes.OrbListenOff
local OrbcamOnRemoteEvent = Common.Remotes.OrbcamOn
local OrbcamOffRemoteEvent = Common.Remotes.OrbcamOff

local Halos = {}
Halos.__index = Halos

function Halos.Init()
    -- Fired whenever someone attaches to an orb as listener or luggage
    -- Note that these halos are created on the client for every player (not
    -- just the local player)
    OrbAttachRemoteEvent.OnClientEvent:Connect(function(plr,orb)
        if CollectionService:HasTag(orb, Config.TransportTag) then return end

        -- Copy the rings from the orb
        local earRing = orb:FindFirstChild("EarRing")
        local eyeRing = orb:FindFirstChild("EyeRing")

        if earRing then
            local whiteHalo = earRing:Clone()
            whiteHalo.Name = Config.WhiteHaloName
            whiteHalo.Transparency = 1
            whiteHalo.Parent = plr.Character
        end

        if eyeRing then
            local blackHalo = eyeRing:Clone()
            blackHalo.Name = Config.BlackHaloName
            blackHalo.Transparency = 1
            blackHalo.Parent = plr.Character
        end
    end)

    -- Fired whenever someone detaches from an orb
    OrbDetachRemoteEvent.OnClientEvent:Connect(function(plr,orb)
        if CollectionService:HasTag(orb, Config.TransportTag) then return end

        local whiteHalo = plr.Character:FindFirstChild(Config.WhiteHaloName)
        local blackHalo = plr.Character:FindFirstChild(Config.BlackHaloName)
        if whiteHalo then
            whiteHalo:Destroy()
        end

        if blackHalo then
            blackHalo:Destroy()
        end
    end)

    OrbListenOnRemoteEvent.OnClientEvent:Connect(function(plr)
        if not plr then return end
        if not plr.Character then return end

        local whiteHalo = plr.Character:FindFirstChild(Config.WhiteHaloName)
        if whiteHalo then
            whiteHalo.Transparency = 0
        end
    end)

    OrbListenOffRemoteEvent.OnClientEvent:Connect(function(plr)
        if not plr then return end
        if not plr.Character then return end
        
        local whiteHalo = plr.Character:FindFirstChild(Config.WhiteHaloName)
        if whiteHalo then
            whiteHalo.Transparency = 1
        end
    end)

    OrbcamOnRemoteEvent.OnClientEvent:Connect(function(plr)
        if not plr then return end
        if not plr.Character then return end

        local blackHalo = plr.Character:FindFirstChild(Config.BlackHaloName)
        if blackHalo then
            blackHalo.Transparency = 0
        end
    end)

    OrbcamOffRemoteEvent.OnClientEvent:Connect(function(plr)
        if not plr then return end
        if not plr.Character then return end
        
        local blackHalo = plr.Character:FindFirstChild(Config.BlackHaloName)
        if blackHalo then
            blackHalo.Transparency = 1
        end
    end)

    -- Update the halo positions
	RunService.RenderStepped:Connect(function(delta)
		for _, player in ipairs(Players:GetPlayers()) do
			local character = player.Character
			if character then
				local head = character:FindFirstChild("Head")
				local whiteHalo = character:FindFirstChild(Config.WhiteHaloName)
				local blackHalo = character:FindFirstChild(Config.BlackHaloName)

				if head and whiteHalo and blackHalo then
					whiteHalo.CFrame = head.CFrame * CFrame.new(0,Config.HaloOffset,0) * CFrame.Angles(0,0,math.pi/2) 
					blackHalo.CFrame = head.CFrame * CFrame.new(0,Config.HaloOffset,0) * CFrame.Angles(0,0,math.pi/2)
				end
			end
		end
	end)
end

return Halos