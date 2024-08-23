--!strict

local DeepCopy = require(script.Parent.Utils.DeepCopy)
local DefaultData = require(script.Parent.DefaultData)

type Session = {
	PlaceId: number,
	JobId: string,
}

type MetaData = {
	ActiveSession: Session?,

	ForceLoad: Session?, -- the session stealing the session lock, if any

	IsOverwriting: boolean?, -- true if .ActiveSession is found during :Overwrite()
	ReleaseSessionOnOverwrite: boolean?,

	LastUpdate: number,
	Created: number,
	LoadCount: number,
}

type GlobalUpdateData = { [string]: any }

type GlobalUpdate = {
	ID: number,
	Locked: boolean,
	Data: GlobalUpdateData,
}

type GlobalUpdates = {
	ID: number,
	Updates: { GlobalUpdate },
}

type UserIds = { [number]: number }

type Data = {
	Data: { [string]: any },

	MetaData: MetaData,
	GlobalUpdates: GlobalUpdates,

	UserIds: UserIds,
}

local function isDataEmpty(latestData: Data)
	-- someone wants to fix this mess??

	return latestData == nil
		or typeof(latestData) ~= "table"
		or typeof(latestData.Data) ~= "table" and latestData.Data == nil and latestData.MetaData == nil and latestData.GlobalUpdates == nil -- might be global updates there
		or typeof(latestData.MetaData) ~= "table"
end

local function reconcileGlobalUpdates(newGlobalUpdates: GlobalUpdates)
	local finalGlobals = DeepCopy(DefaultData.GlobalUpdates)

	local id = 0 -- used to fix any missing ids

	for _, newUpdate in newGlobalUpdates.Updates do
		id += 1
		finalGlobals.ID = id

		newUpdate.ID = id
		table.insert(finalGlobals.Updates, newUpdate)
	end

	return finalGlobals
end

local function updateAsync(
	key: string,
	store: DataStore,
	updateSettings: {
		onExisting: ((latestData: Data) -> boolean?)?,
		onMissing: ((latestData: Data) -> boolean?)?,
		edit: ((latestData: Data) -> boolean?)?,
	},
	useGet: { version: string }?
)
	local function transformUpdate(latestData: Data): (Data?, UserIds?)
		local isEmpty = isDataEmpty(latestData)

		if not latestData then
			latestData = {} :: any
		end

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
				globalUpdates = reconcileGlobalUpdates(latestData.GlobalUpdates) -- latestData.GlobalUpdates will get updated inside if isEmpty then block

				isEmpty = true
			else
				isEmpty = true
			end
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
