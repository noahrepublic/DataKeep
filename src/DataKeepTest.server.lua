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
		Keeps[player] = keep

		keep.OnGlobalUpdate:Connect(function(id, globalUpdate)
			print("Global update received", id)
			print(globalUpdate)
		end)
	end)

	task.delay(5, function()
		print("Creating a global update")

		local keep = Keeps[player]

		print(keep.GlobalUpdates)

		keepStore:PostGlobalUpdate("Player_" .. player.UserId, function(globalUpdates)
			local updateId = globalUpdates
				:AddGlobalUpdate({
					Hello = "World!",
				})
				:awaitValue()

			print("Added global update", updateId)

			print(keep.GlobalUpdates)

			print("Changing global update")

			globalUpdates:ChangeActiveUpdate(updateId, {
				Hello = "World!",
				Hello2 = "World!",
			})
		end)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	Keeps[player]:Release()
end)
