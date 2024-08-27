--!strict

local DeepFreeze = require(script.Parent.Utils.DeepFreeze)

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

type Data = {
	Data: { [string]: any },

	MetaData: MetaData,
	GlobalUpdates: GlobalUpdates,

	UserIds: { [number]: number },
}

local defaultMetaData: MetaData = {
	ActiveSession = { PlaceId = game.PlaceId, JobId = game.JobId }, -- we can change to number indexes for speed, but worse for types

	LastUpdate = 0,

	Created = 0,
	LoadCount = 0,
}

local defaultGlobalUpdates: GlobalUpdates = {
	ID = 0, -- [recentUpdateId] newest global update id to process in order
	Updates = {},
}

local defaultData: Data = {
	Data = {},
	-- can future add metatags or whateva
	MetaData = defaultMetaData,
	GlobalUpdates = defaultGlobalUpdates, -- really like how profile service supports these, so adding to this module as I use them lots.

	UserIds = {},
}

DeepFreeze(defaultData)

return defaultData
