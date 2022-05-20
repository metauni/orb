local args = {...}
local input = args[1] or "build.rbxlx"
local output = args[2] or "metaorb.rbxmx"

local game = remodel.readPlaceFile(input)

local orbServer = game.ServerScriptService.OrbServer
local orbPlayer = game.StarterPlayer.StarterPlayerScripts.OrbPlayer
local orbCommon = game.ReplicatedStorage.OrbCommon
local orbGuiLuggage = game.StarterGui.OrbGuiLuggage

orbPlayer.Parent = orbServer
orbCommon.Parent = orbServer
orbGuiLuggage.Parent = orbServer

remodel.writeModelFile(orbServer, output)