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

type latest<T> = {
	data: Types.keepStruct<T>,
	metadata: Types.metadata,
	userIds: Types.userIds,
}

local function updateAsync<T>(
	key: string,
	store: DataStore,
	updateSettings: {
		onCheck: (() -> boolean)?,
		onExisting: ((latest: latest<T>) -> boolean)?,
		onMissing: ((latest: latest<T>) -> boolean)?,
		edit: ((latest: latest<T>) -> boolean)?,
	},
	options: {
		useGet: { version: string? }?,
	}
): (Types.keepStruct<T>?, DataStoreKeyInfo?)
	local function transformUpdate(latestData: Types.keepStruct<T>, datastoreKeyInfo: DataStoreKeyInfo?): (Types.keepStruct<T>?, Types.userIds?, Types.metadata?)
		local onCheck = if typeof(updateSettings.onCheck) == "function" then updateSettings.onCheck else nil

		if onCheck then
			local shouldCancelOperation = onCheck() == true

			if shouldCancelOperation then
				return nil
			end
		end

		local globalUpdates = DeepCopy(DefaultData.GlobalUpdates)
		local metadata: Types.metadata = if datastoreKeyInfo then datastoreKeyInfo:GetMetadata() :: any else {}
		local userIds: Types.userIds = if datastoreKeyInfo then datastoreKeyInfo:GetUserIds() else {}

		local latest = {
			data = latestData,
			metadata = metadata,
			userIds = userIds,
		}

		if typeof(latest.data) == "table" and next(metadata) == nil then -- migrate from older versions (pre v6.0.0)
			local data: any = latest.data
			local oldMetadata: Types.metadata = data.MetaData

			if oldMetadata then
				metadata.Created = oldMetadata.Created or os.time()
				metadata.LastUpdate = oldMetadata.LastUpdate or os.time()
				metadata.LoadCount = oldMetadata.LoadCount or 1

				data.MetaData = nil
			end

			data.UserIds = nil
		end

		local isEmpty = false

		if typeof(latest.data) == "table" then
			if typeof(latest.data.Data) == "table" and typeof(latest.data.GlobalUpdates) == "table" then
				-- keep was loaded before

				globalUpdates = reconcileGlobalUpdates(latest.data.GlobalUpdates)
				latest.data.GlobalUpdates = globalUpdates

				local onExisting = if typeof(updateSettings.onExisting) == "function" then updateSettings.onExisting else nil

				if onExisting then
					local shouldCancelOperation = onExisting(latest) == true

					if shouldCancelOperation then
						return nil
					end
				end
			elseif latest.data.Data == nil and typeof(latest.data.GlobalUpdates) == "table" then
				-- keep was not loaded before but GlobalUpdate data exists

				-- latest.data.GlobalUpdates will get updated inside if isEmpty then block
				globalUpdates = reconcileGlobalUpdates(latest.data.GlobalUpdates)

				isEmpty = true
			else
				isEmpty = true
			end
		else
			isEmpty = true
		end

		if isEmpty then
			latest.data = {
				GlobalUpdates = globalUpdates,
			} :: any

			local onMissing = if typeof(updateSettings.onMissing) == "function" then updateSettings.onMissing else nil

			if onMissing then
				local shouldCancelOperation = onMissing(latest) == true

				if shouldCancelOperation then
					return nil
				end
			end
		end

		local edit = if typeof(updateSettings.edit) == "function" then updateSettings.edit else nil

		if edit then
			local shouldCancelOperation = edit(latest) == true

			if shouldCancelOperation then
				return nil
			end
		end

		return latest.data, latest.userIds, latest.metadata
	end

	if options.useGet then
		local latestData, dataStoreKeyInfo

		if options.useGet.version then
			latestData, dataStoreKeyInfo = store:GetVersionAsync(key, options.useGet.version)
		else
			local datastoreGetOptions = Instance.new("DataStoreGetOptions")
			datastoreGetOptions.UseCache = false

			latestData, dataStoreKeyInfo = store:GetAsync(key, datastoreGetOptions)
		end

		latestData = transformUpdate(latestData, dataStoreKeyInfo)
		return latestData, dataStoreKeyInfo
	else
		return store:UpdateAsync(key, transformUpdate)
	end
end

return updateAsync
