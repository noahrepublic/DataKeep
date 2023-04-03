--[[ Keep.lua
    Class that holds data and saving methods with it's assigned information.


    Events:
        Released: Fired when the Keep object is unlocked from the session, fired as the profile is removed from the server's memory.
]]

--> Class Structure

local Keep = {}
Keep.__index = Keep

--> Variables

local Signal = require(script.Parent.Signal)

--> Public Functions

--[[ Keep.new()
    Creates a new Keep object that holds data and saving methods with it's assigned information.

    Called when a new Keep object is created, this is called by the Store class.

    @param rawData: table
        The raw data from the datastore save
]]

function Keep.new(rawData: table)
	local self = setmetatable({}, Keep)

	self.Data = rawData.Data
	self.MetaData = rawData.MetaData or { Active = { game.GameId, game.PlaceId } }

	self._canSave = self.MetaData.Active[1] == game.GameId and self.MetaData.Active[2] == game.PlaceId -- Determines if the session possesses the Keep object and can overwrite data

	self.Released = Signal.new() -- Fired when the Keep object is released ("freed") from the session

	return self
end

function Keep:Save()
	print("Saving data...")
	if not self._canSave then -- DEVELOPERS SHOULD NOT BE CALLING THIS MANUALLY THIS IS TO MAKE SURE THE DATA IS NOT OVERWRITTEN BY ANOTHER SESSION
		return
	end
end

--[[ Keep:Mock()
	Enable Mock data, not saving to the datastore. ("Fake data")

	@return void
]]

function Keep:Mock() end

--[[ Keep:Release()
    Destroys and releases the Keep object from the session.

    "Releases" the Keep object from the session, meaning this session will no longer be able to overwrite data; and allows other sessions to take ownership.

    @return void
]]

function Keep:Release()
	self:Save()

	self.MetaData.Active = nil

	self.Released:Fire()
	setmetatable(self, nil)
end

return Keep
