--> Services

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

--> Variables

local ServerPackages = ServerScriptService:FindFirstChild("ServerPackages")

local DataKeep = require(ServerPackages:FindFirstChild("datakeep"))

local Wrapper = require(ServerScriptService:FindFirstChild("Wrapper"))

type DataTemplate = {
	T: number,
}

local dataTemplate: DataTemplate = {
	T = 0,
}

local keepStore = DataKeep.GetStore("TestStore", dataTemplate):awaitValue()
keepStore.Wrapper = Wrapper

local Keeps = {}

keepStore.validate = function(data)
	local function isValid(dataToCheck, reference)
		if typeof(dataToCheck) ~= typeof(reference) then
			return false
		end

		if typeof(dataToCheck) == "table" then
			for key, value in pairs(dataToCheck) do
				if not isValid(value, reference[key]) then
					return false, `Key {key} returned type {typeof(value)}, should have been {typeof(reference[key])}`
				end
			end
		end
		return true
	end

	return isValid(data, dataTemplate)
end

keepStore.IssueSignal:Connect(function(err)
	print(err)
end)

--> Public Functions

Players.PlayerAdded:Connect(function(player)
	keepStore:LoadKeep("Player_" .. player.UserId):andThen(function(keep)
		Keeps[player] = keep

		print(keep)

		-- keep:onDataChange("Inventory.Sword", function(newValue)
		-- 	print("Sword changed to", newValue)
		-- end)

		-- keep:Mutate("Inventory.Sword", function()
		-- 	return "Iron Sword 2"
		-- end)

		--keep.Data.Test = nil

		print(keep.Data)

		keep:Reconcile()

		print(keep.Data)

		keep.OnGlobalUpdate:Connect(function(_, id)
			print(player.UserId .. " received global update", id)

			keep:ClearLockedUpdate(id)
		end)

		keep.Releasing:Connect(function(state)
			print(`Releasing {keep:Identify()}`)
			state:andThen(function()
				print(`Released {keep:Identify()}`)
				player:Kick("Keep released")
			end, function()
				print(`Failed to release {keep:Identify()}`)
			end)
		end)

		keep.Saving:Connect(function(state)
			print(`Saving {keep:Identify()}`)

			state
				:andThen(function()
					print(`Saved {keep:Identify()}`)
				end)
				:catch(function()
					print(`Failed to save {keep:Identify()}`)
				end)
		end)

		-- print("Lets try loading AGAIN")

		-- keepStore:LoadKeep("Player_" .. player.UserId):andThen(function(keep2)
		-- 	print("Loaded cached keep again")
		-- 	print(keep2, keep)
		-- end)

		-- keep.Data.Test = "Hello World! 2"
		-- keep:Save()

		-- local versions = keep:GetVersions()

		-- versions:andThen(function(iterator)
		-- 	print(keep.Data)
		-- 	local versionToRoll = iterator.Current()

		-- 	keep:SetVersion(versionToRoll.Version)

		-- 	print(keep.Data)
		-- end)

		-- print("UserIds: ")
		-- keep:AddUserId(player.UserId)

		-- print(keep.UserIds)

		-- keep:AddUserId(player.UserId)

		-- print(keep.UserIds)

		warn(keep.Data)

		print(keepStore._store:GetAsync(keep._key))
	end)

	-- for i = 1, 2 do
	-- 	local message = if i == 1 then "Hello" else "Goodbye"

	-- 	keepStore:PostGlobalUpdate("Player_" .. player.UserId, function(globalUpdates)
	-- 		print(globalUpdates:GetActiveUpdates())
	-- 		for _, globalUpdate in ipairs(globalUpdates:GetActiveUpdates()) do
	-- 			print("Changing global update", globalUpdate.ID)

	-- 			globalUpdates:ChangeActiveUpdate(globalUpdate.ID, {
	-- 				Message = globalUpdate.Data.Message .. message,
	-- 			})

	-- 			print(globalUpdates:GetActiveUpdates())

	-- 			return
	-- 		end

	-- 		print("Posted global update")

	-- 		globalUpdates:AddGlobalUpdate({
	-- 			Message = message,
	-- 		})
	-- 	end)
	-- end

	-- print("viewing")
	-- keepStore:ViewKeep("Player_" .. player.UserId):andThen(function(keep)
	-- 	print("Viewed keep")
	-- 	print(keep.Data)

	-- 	print("Changing")

	-- 	keep:Mutate("Inventory.Sword", function()
	-- 		return "Iron Sword 2"
	-- 	end)

	-- 	print(keep.Data)

	-- 	keep:Overwrite()

	-- 	print(keepStore._store:GetAsync(keep._key))
	-- end)
end)

Players.PlayerRemoving:Connect(function(player)
	local keep = Keeps[player]

	local t = os.time()

	keep.Data.T = t
	keep:Release()
end)
