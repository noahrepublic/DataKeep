--> Services

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

--> Variables

local DataKeep = require(ServerScriptService.DataKeep)

local keepStore = DataKeep.GetStore("TestStore", {
	Test = "Hello World!",
}):awaitValue()

local Keeps = {}

--> Public Functions

Players.PlayerAdded:Connect(function(player)
	keepStore:LoadKeep("Player_" .. player.UserId):andThen(function(keep)
		print("Data:", keep.Data)

		Keeps[player] = keep
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	Keeps[player]:Release()
end)
