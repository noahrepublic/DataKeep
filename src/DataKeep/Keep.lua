--!strict

--> Structure

local Keep = {
	assumeDeadLock = 0,

	ServiceDone = false, -- set to true when server shutdown
}
Keep.__index = Keep

--> Includes

local Promise = require(script.Parent.Promise)
local Signal = require(script.Parent.Signal)

--> Types

export type KeepStruct = {
	Data: any,

	MetaData: MetaData,
	GlobalUpdates: GlobalUpdates,

	UserIds: { [number]: number },

	LatestKeep: any,
}

type MetaData = {
	ActiveSession: ActiveSession | nil,

	ForceLoad: ActiveSession | nil, -- the session stealing the session lock, if any

	LastUpdate: number,
}

type GlobalUpdates = {}

export type ActiveSession = {
	PlaceID: number,
	JobID: number,
}

--> Constructor

local DefaultMetaData: MetaData = {
	ActiveSession = { PlaceID = game.PlaceId, JobID = game.JobId }, -- we can change to number indexes for speed, but worse for types

	LastUpdate = 0,
}

local DefaultGlobalUpdates: GlobalUpdates = {}

local DefaultKeep: KeepStruct = {
	Data = {},
	-- can future add metatags or whateva
	MetaData = DefaultMetaData,
	GlobalUpdates = DefaultGlobalUpdates, -- really like how profile service supports these, so adding to this module as I use them lots.

	UserIds = {},

	LatestKeep = {},
}

function Keep.new(structure: KeepStruct): Keep
	assert(structure.Data ~= nil, "Data must be provided") -- everything else is optional, because we have defaults available in scope.

	local self = setmetatable({
		Data = structure.Data,
		MetaData = structure.MetaData or DefaultKeep.MetaData, -- auto locks the session too if new keep

		GlobalUpdates = structure.GlobalUpdates or DefaultKeep.GlobalUpdates,
		UserIds = structure.UserIds or DefaultKeep.UserIds,

		LatestKeep = structure.Data,

		OnRelease = Signal.new(),
		_released = false,

		_store = nil,
		_key = "", -- the scope of the keep, used for the store class to know where to save it

		_load_time = os.clock(),
		_store_info = { Name = "", Scope = "" },
	}, Keep)

	return self
end

export type Keep = typeof(Keep.new({
	Data = DefaultKeep.Data,

	MetaData = DefaultMetaData,
	GlobalUpdates = DefaultGlobalUpdates,

	UserIds = DefaultKeep.UserIds,

	LatestKeep = DefaultKeep.LatestKeep,
})) -- the actual Keep class type

--> Private Functions

local function isLocked(metaData: MetaData)
	return metaData.ActiveSession
		and metaData.ActiveSession.PlaceID ~= game.PlaceId
		and metaData.ActiveSession.JobID ~= game.JobId
end

local function transformUpdate(keep: Keep, newestData: KeepStruct, release: boolean)
	-- TODO: this is where we would process globals

	local empty = newestData == nil
		or type(newestData) ~= "table"
		or type(newestData.Data) ~= "table"
			and newestData.Data == nil
			and newestData.MetaData == nil
			and newestData.GlobalUpdates == nil -- might be global updates there
		or type(newestData.MetaData) ~= "table"
	local corrupted = newestData ~= nil
		and (type(newestData) ~= "table" or type(newestData.Data) ~= "table" or type(newestData.MetaData) ~= "table")

	if not corrupted and not empty then
		if newestData.Data == nil and newestData.MetaData == nil and type(newestData.GlobalUpdates) == "table" then -- global updates, just no data
			print("global updates")
			-- support global updates
		end

		if
			type(newestData.Data) == "table"
			and typeof(newestData.MetaData) == "table"
			and typeof(newestData.GlobalUpdates) -- full profile
		then
			if not isLocked(newestData.MetaData) then
				newestData.Data = keep.Data

				newestData.UserIds = keep.UserIds
			end

			-- support global updates
		end
	end

	if corrupted then
		local replaceData = {
			Data = newestData.Data,
			MetaData = newestData.MetaData or DefaultKeep.MetaData, -- auto locks the session too if new keep

			GlobalUpdates = newestData.GlobalUpdates or DefaultKeep.GlobalUpdates,
			UserIds = newestData.UserIds or DefaultKeep.UserIds,

			LatestKeep = newestData.Data,
		}

		newestData = replaceData
	end

	if empty then
		newestData = {
			Data = keep.Data,
			MetaData = keep.MetaData,

			GlobalUpdates = keep.GlobalUpdates,
			UserIds = keep.UserIds,
		}
	end

	if not isLocked(newestData.MetaData) then
		newestData.MetaData.ActiveSession = if release and newestData.MetaData.ForceLoad
			then newestData.MetaData.ForceLoad
			else DefaultMetaData.ActiveSession -- give the session to the new keep

		if release then
			newestData.MetaData.ForceLoad = nil -- remove the force load, if any
		end

		newestData.MetaData.LastUpdate = os.time()

		keep.LatestKeep = newestData
	end

	if release and not isLocked(newestData.MetaData) then -- if it is locked, we never had the lock, so we can't release it
		print("Released profile signal")
		keep.OnRelease:Fire() -- unlocked, but not removed internally
		keep._released = true -- will tell the store class to remove internally
	end

	return newestData, newestData.UserIds
end

function Keep:IsActive()
	return not isLocked(self.MetaData)
end

function Keep:Identify()
	return string.format(
		"%s/%s%s",
		self._store_info.Name,
		string.format("%s%s", self._store_info.Scope, if self._store_info.Scope ~= "" then "/" else ""),
		self._key
	)
end

function Keep:Release()
	return Promise.new(function(resolve)
		if self._released then
			return resolve(self)
		end

		self._released = true

		print("Releasing")

		self._store:UpdateAsync(self._key, function(newestData: KeepStruct)
			return self:_Save(newestData, true)
		end)

		resolve(self) -- this is called before internal release, but after session release, no edits can be made after this point
	end)
end

function Keep:_Save(newestData: KeepStruct, release: boolean)
	if not self:IsActive() then
		return newestData
	end

	release = release
		or if newestData
				and newestData.MetaData
				and newestData.MetaData.ForceLoad
				and newestData.MetaData.ForceLoad.PlaceID ~= game.PlaceId
				and newestData.MetaData.ForceLoad.JobID ~= game.JobId
			then true
			else false

	print(release)

	return transformUpdate(self, newestData, release)
end

return Keep
