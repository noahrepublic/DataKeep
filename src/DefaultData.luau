--!strict

local DeepFreeze = require(script.Parent.Utils.DeepFreeze)
local Types = require(script.Parent.Types)

local defaultMetaData: Types.metaData = {
	ActiveSession = { PlaceId = game.PlaceId, JobId = game.JobId }, -- we can change to number indexes for speed, but worse for types

	LastUpdate = 0,

	Created = 0,
	LoadCount = 0,
}

local defaultGlobalUpdates: Types.globalUpdates = {
	--- [recentUpdateId] newest global update id to process in order
	Id = 0,
	Updates = {},
}

local defaultData: Types.keepStruct<{}> = {
	Data = {},
	MetaData = defaultMetaData, -- can future add metatags or whateva
	GlobalUpdates = defaultGlobalUpdates, -- really like how ProfileService supports these, so adding to this module as I use them lots.
	UserIds = {},
}

DeepFreeze(defaultData)

return defaultData
