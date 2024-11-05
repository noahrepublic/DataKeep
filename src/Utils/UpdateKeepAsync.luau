--!strict

local DeepCopy = require(script.Parent.Parent.Utils.DeepCopy)
local DefaultData = require(script.Parent.Parent.DefaultData)
local Types = require(script.Parent.Parent.Types)

local function reconcileGlobalUpdates(newGlobalUpdates: Types.globalUpdates)
	local finalGlobals = DeepCopy(DefaultData.GlobalUpdates)

	local id = 0 -- used to fix any missing ids

	for _, newUpdate in newGlobalUpdates.Updates do
		id += 1
		finalGlobals.Id = id

		newUpdate.Id = id
		table.insert(finalGlobals.Updates, newUpdate)
	end

	return finalGlobals
end

local function updateAsync<T>(
	key: string,
	store: DataStore,
	updateSettings: {
		onCheck: (() -> boolean)?,
		onExisting: ((latestData: Types.keepStruct<T>) -> boolean)?,
		onMissing: ((latestData: Types.keepStruct<T>) -> boolean)?,
		edit: ((latestData: Types.keepStruct<T>) -> boolean)?,
	},
	useGet: { version: string? }?
)
	local function transformUpdate(latestData: Types.keepStruct<T>): (Types.keepStruct<T>?, Types.userIds?)
		local onCheck = if typeof(updateSettings.onCheck) == "function" then updateSettings.onCheck else nil

		if onCheck then
			local shouldCancelOperation = onCheck() == true

			if shouldCancelOperation then
				return nil
			end
		end

		local isEmpty = false

		local globalUpdates = DeepCopy(DefaultData.GlobalUpdates)

		if typeof(latestData) == "table" then
			if typeof(latestData.Data) == "table" and typeof(latestData.MetaData) == "table" and typeof(latestData.GlobalUpdates) == "table" then
				-- keep was loaded before

				globalUpdates = reconcileGlobalUpdates(latestData.GlobalUpdates)
				latestData.GlobalUpdates = globalUpdates

				local onExisting = if typeof(updateSettings.onExisting) == "function" then updateSettings.onExisting else nil

				if onExisting then
					local shouldCancelOperation = onExisting(latestData) == true

					if shouldCancelOperation then
						return nil
					end
				end
			elseif latestData.Data == nil and latestData.MetaData == nil and typeof(latestData.GlobalUpdates) == "table" then
				-- keep was not loaded before but GlobalUpdate data exists

				-- latestData.GlobalUpdates will get updated inside if isEmpty then block
				globalUpdates = reconcileGlobalUpdates(latestData.GlobalUpdates)

				isEmpty = true
			else
				isEmpty = true
			end
		else
			isEmpty = true
		end

		if isEmpty then
			latestData = {
				GlobalUpdates = globalUpdates,
			} :: any

			local onMissing = if typeof(updateSettings.onMissing) == "function" then updateSettings.onMissing else nil

			if onMissing then
				local shouldCancelOperation = onMissing(latestData) == true

				if shouldCancelOperation then
					return nil
				end
			end
		end

		local edit = if typeof(updateSettings.edit) == "function" then updateSettings.edit else nil

		if edit then
			local shouldCancelOperation = edit(latestData) == true

			if shouldCancelOperation then
				return nil
			end
		end

		return latestData, latestData.UserIds
	end

	if useGet then
		local getData, getDataStoreKeyInfo

		if useGet.version then
			getData, getDataStoreKeyInfo = store:GetVersionAsync(key, useGet.version)
		else
			local dataStoreGetOptions = Instance.new("DataStoreGetOptions")
			dataStoreGetOptions.UseCache = false

			getData, getDataStoreKeyInfo = store:GetAsync(key, dataStoreGetOptions)
		end

		getData = transformUpdate(getData)
		return getData, getDataStoreKeyInfo
	else
		return store:UpdateAsync(key, transformUpdate)
	end
end

return updateAsync
