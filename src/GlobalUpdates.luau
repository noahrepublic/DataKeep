--!strict

local Promise = require(script.Parent.Parent.Promise)

local Log = require(script.Parent.Utils.Log)
local PromiseTypes = require(script.Parent.PromiseTypes)
local Types = require(script.Parent.Types)

--> Structure

local GlobalUpdates = {}
GlobalUpdates.__index = GlobalUpdates

--> Types

--[=[
	@class GlobalUpdates
	@server

	Used to add, lock and change global updates.

	Revealed through [:PostGlobalUpdate()](Store#PostGlobalUpdate).
]=]

--> Public Methods

--[=[
	@method AddGlobalUpdate
	@within GlobalUpdates

	@param globalData {}

	@return Promise<number>

	Adds a global update to the Keep.

	```lua
	globalUpdates:AddGlobalUpdate({
		Hello = "World!",
	}):andThen(function(updateId)
		print("Added Global Update!", updateId)
	end)
	```
]=]

function GlobalUpdates:AddGlobalUpdate(globalData: {}): PromiseTypes.TypedPromise<number>
	return Promise.new(function(resolve)
		local globalUpdates = self._updates

		local updateId: number = globalUpdates.Id
		updateId += 1

		globalUpdates.Id = updateId

		table.insert(globalUpdates.Updates, {
			Id = updateId,
			Locked = false,
			Data = globalData,
		})

		return resolve(updateId)
	end)
end

--[=[
	@method ChangeActiveUpdate
	@within GlobalUpdates

	@param updateId number
	@param globalData {}

	@return Promise

	Change an **active** global update's data to the new data.

	Useful for stacking updates to save space for Keeps that maybe receiving lots of globals. Ex. a content creator receiving gifts.
]=]

function GlobalUpdates:ChangeActiveUpdate(updateId: number, globalData: {}): PromiseTypes.TypedPromise<()>
	return Promise.new(function(resolve, reject)
		if not updateId or not (typeof(updateId) == "number") then
			return reject()
		end

		local globalUpdates = self._updates

		if globalUpdates.Id < updateId then
			return reject()
		end

		for _, update in globalUpdates.Updates do
			if update.Id == updateId and not update.Locked then
				update.Data = globalData

				return resolve()
			end
		end

		return reject()
	end)
end

--[=[
	@method RemoveActiveUpdate
	@within GlobalUpdates

	@param updateId number

	@return Promise

	Removes an active global update.

	```lua
	local updates = globalUpdates:GetActiveUpdates()

	for _, update in updates do
		globalUpdates:RemoveActiveUpdate(update.Id):andThen(function()
			print("Removed Global Update!")
		end)
	end
	```
]=]

function GlobalUpdates:RemoveActiveUpdate(updateId: number): PromiseTypes.TypedPromise<()>
	return Promise.new(function(resolve, reject)
		if not updateId or not (typeof(updateId) == "number") then
			return reject()
		end

		local globalUpdates = self._updates

		if globalUpdates.Id < updateId then
			return reject()
		end

		local globalUpdateIndex = nil

		for i = 1, #globalUpdates.Updates do
			if globalUpdates.Updates[i].Id == updateId then
				globalUpdateIndex = i
				break
			end
		end

		if globalUpdateIndex == nil then
			return reject()
		end

		if globalUpdates.Updates[globalUpdateIndex].Locked then
			Log.error("[DataKeep] Unable to remove active update on a locked update")
			return reject()
		end

		-- instantly removes internally, unlike locked updates. This is because locked updates can still be deleted mid-processing
		table.remove(globalUpdates.Updates, globalUpdateIndex)
		return resolve()
	end)
end

--[=[
	@method GetActiveUpdates
	@within GlobalUpdates

	@return { GlobalUpdate }

	Returns all **active** global updates.

	```lua
	local updates = globalUpdates:GetActiveUpdates()

	for _, update in updates do
		print("ActiveUpdate data:", update.Data)
	end
	```
]=]

function GlobalUpdates:GetActiveUpdates(): { Types.globalUpdate }
	local globalUpdates = self._updates

	local updates = {}

	for _, update in globalUpdates.Updates do
		if not update.Locked then
			table.insert(updates, update)
		end
	end

	return updates
end

return GlobalUpdates
