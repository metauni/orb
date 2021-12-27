local CollectionService = game:GetService("CollectionService")
local Common = game:GetService("ReplicatedStorage").OrbCommon
local Config = require(Common.Config)

local Orb = {}
Orb.__index = Orb

function Orb.Init()

	print("Orb Server initialized")
end

return Orb