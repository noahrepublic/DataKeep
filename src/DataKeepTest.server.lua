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

		keep.OnGlobalUpdate:Connect(function(_, id)
			print(player.UserId .. " received global update", id)

			keep:ClearLockedUpdate(id)
		end)

		print("Lets try loading AGAIN")

		keepStore:LoadKeep("Player_" .. player.UserId):andThen(function()
			print("Loaded cached keep again")
		end)
	end)

	for i = 1, 2 do
		local message = if i == 1 then "Hello" else "Goodbye"

		keepStore:PostGlobalUpdate("Player" .. player.UserId, function(globalUpdates)
			print(globalUpdates:GetActiveUpdates())
			for _, globalUpdate in ipairs(globalUpdates:GetActiveUpdates()) do
				print("Changing global update", globalUpdate.ID)

				globalUpdates:ChangeActiveUpdate(globalUpdate.ID, {
					Message = globalUpdate.Data.Message .. message,
				})

				return
			end

			print("Posted global update")

			globalUpdates:AddGlobalUpdate({
				Message = message,
			})
		end)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	Keeps[player]:Release()
end)
