--> Services

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

--> Variables

local DataKeep = require(ServerScriptService.DataKeep)

local keepStore = DataKeep.GetStore({ "TestStore" })

--> Public Functions

Players.PlayerAdded:Connect(function(player)
	local keep = keepStore:LoadKeep(player.UserId)

	print("Data:", keep.Data)
end)
