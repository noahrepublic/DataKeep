local deepCopy = require(script.Parent.deepCopy)
local defaultData = require(script.Parent.defaultData)

type Session = {
	PlaceID: number,
	JobID: string,
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

type Data = {
	Data: { [string]: any },

	MetaData: MetaData,
	GlobalUpdates: GlobalUpdates,

	UserIds: { [number]: number },
}

local function isDataEmpty(newestData: Data)
	-- someone wants to fix this mess??

	return newestData == nil
		or type(newestData) ~= "table"
		or type(newestData.Data) ~= "table" and newestData.Data == nil and newestData.MetaData == nil and newestData.GlobalUpdates == nil -- might be global updates there
		or type(newestData.MetaData) ~= "table"
end

--[[local function isDataCorrupted(newestData: Data)
	if newestData == nil then
		return false
	end

	if type(newestData) ~= "table" then
		return true
	end

	if type(newestData.Data) ~= "table" then
		return true
	end

	if type(newestData.MetaData) ~= "table" then
		return true
	end

	if type(newestData.GlobalUpdates) ~= "table" then
		return true
	end

	if type(newestData.UserIds) ~= "table" then
		return true
	end

	return false
end]]

function updateAsync(
	key: string,
	store: DataStore,
	updateSettings: {
		existingHandle: ((latestData: Data) -> Data?)?,
		missingHandle: ((latestData: Data) -> Data?)?,
		edit: ((latestData: Data) -> Data?)?,
	}
)
	local function transformUpdate(latestData: Data)
		if not latestData then
			latestData = {} :: any
		end

		local isEmpty = isDataEmpty(latestData)
		--local isCorrupted = isDataCorrupted(latestData)

		local globalUpdates = deepCopy(defaultData.GlobalUpdates)

		if typeof(latestData) == "table" then
			if typeof(latestData.Data) == "table" and typeof(latestData.MetaData) == "table" and typeof(latestData.GlobalUpdates) == "table" then
				-- keep was loaded before
				globalUpdates = latestData.GlobalUpdates

				local existingHandle = if typeof(updateSettings.existingHandle) == "function" then updateSettings.existingHandle else nil

				if existingHandle then
					local shouldCancelOperation = existingHandle(latestData) == nil

					if shouldCancelOperation then
						return nil
					end
				end
			elseif latestData.Data == nil and latestData.MetaData == nil and typeof(latestData.GlobalUpdates) == "table" then
				-- keep was not loaded before but GlobalUpdate data exists
				globalUpdates = latestData.GlobalUpdates or globalUpdates

				isEmpty = true
			else
				isEmpty = true
			end
		end

		if isEmpty then
			latestData = {
				GlobalUpdates = globalUpdates,
			} :: any

			local missingHandle = if typeof(updateSettings.missingHandle) == "function" then updateSettings.missingHandle else nil

			if missingHandle then
				local shouldCancelOperation = missingHandle(latestData) == nil

				if shouldCancelOperation then
					return nil
				end
			end
		end

		local edit = if typeof(updateSettings.edit) == "function" then updateSettings.edit else nil

		if edit then
			local shouldCancelOperation = edit(latestData) == nil

			if shouldCancelOperation then
				return nil
			end
		end

		return latestData, latestData.UserIds
	end

	return store:UpdateAsync(key, transformUpdate)
end

return updateAsync
