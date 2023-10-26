--> Services

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

--> Variables

local ServerPackages = ServerScriptService:FindFirstChild("ServerPackages")

local DataKeep = require(ServerPackages:FindFirstChild("datakeep"))

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

		keepStore:LoadKeep("Player_" .. player.UserId):andThen(function(keep2)
			print("Loaded cached keep again")
			print(keep2, keep)
		end)

		keep:Save()

		keep.Data.Test = "Hello World! 2"
		keep:Save()

		local versions = keep:GetVersions()

		versions:andThen(function(iterator)
			print(keep.Data)
			local versionToRoll = iterator.Next()

			keep:SetVersion(versionToRoll.Version)

			print(keep.Data)
		end)
	end)

	for i = 1, 2 do
		local message = if i == 1 then "Hello" else "Goodbye"

		keepStore:PostGlobalUpdate("Player_" .. player.UserId, function(globalUpdates)
			print(globalUpdates:GetActiveUpdates())
			for _, globalUpdate in ipairs(globalUpdates:GetActiveUpdates()) do
				print("Changing global update", globalUpdate.ID)

				globalUpdates:ChangeActiveUpdate(globalUpdate.ID, {
					Message = globalUpdate.Data.Message .. message,
				})

				print(globalUpdates:GetActiveUpdates())

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
