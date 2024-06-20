---
sidebar_position: 3
---

# Basic Usage

DataKeep will lift everything, the only thing you need to do is load data. DataKeep does not use getter / setter functions allowing for customizable experience like, make your own wrapper.

The following is a very basic Keep loader implementation.

```lua
local Players = game:GetService("Players")

local DataKeep = require(path_to_datakeep)

local defaultData = {
    Coins = 0,
}

local loadedKeeps = {}

local keepStore = DataKeep.GetStore("PlayerData", defaultData) -- generally you can just :expect() I just want to showcase Promises to those unfamiliar

local function onPlayerJoin(player)
    keepStore:LoadKeep("Player_" .. player.UserId):andThen(function(keep)
        if keep == nil then
            player:Kick("Session locked")
        end

        keep:Reconcile()
        keep:AddUserId(player.UserId) -- help with GDPR requests

        keep.Releasing:Connect(function(state) -- don't have to clean up, it cleans up internally
            print(`{player.Name}'s Keep is releasing!`)

            state:andThen(function()
                print(`{player.Name}'s Keep has been released!`)
                player:Kick("Session Release")
            end):catch(function(err)
                warn(`{player.Name}'s Keep failed to release!`, err)
            end)
        end)

        if not player:IsDescendantOf(Players) then
            keep:Release()
            return
        end

        print(`Loaded {player.Name}'s Keep!`)

        loadedKeeps[player] = keep

        local leaderstats = Instance.new("Folder")
        leaderstats.Name = "leaderstats"

        local coins = Instance.new("NumberValue")
        coins.Name = "Coins"
        coins.Value = keep.Data.Coins

        leaderstats.Parent = player
    end)
end

Players.PlayerRemoving:Connect(function(player)
    local keep = loadedKeeps[player]

    if not keep then return end

    keep:Release()
end)

keepStore:andThen(function(store)
    keepStore = store

    for _, player in Players:GetPlayers() do
        task.spawn(onPlayerJoin, player)
    end

    Players.PlayerAdded:Connect(onPlayerJoin)
end)
```

# Class Approach

For more experienced developers I personally opt in to create a service that returns a "Player" OOP class that holds it own cleaner and a Keep inside.

Note: "attributes" and "leaderstats" are folders in the script parent which contains numberValues / stringValues / boolValues

```lua
--> Services

local Players = game:GetService("Players")

--> Includes

local DataKeep = require(path_to_datakeep)

local DataTemplate = require(script.Parent.DataTemplate)

--> Module Definition

local Player = {}
Player.__index = Player

--> Variables

local keepStore = DataKeep.GetStore("PlayerData", DataTemplate):expect()

--> Private Functions

local function initKeep(playerClass, keep)
	local player = playerClass.Player

	-- attributes & leaderstats

	local attributes = Instance.new("Folder")
	attributes.Name = "attributes"
	attributes.Parent = player

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local function bindData(value, parent) -- leaderstats or attributes
		local doesExist = keep.Data[value.Name]

		if not doesExist then
			return
		end

		value = value:Clone()

		value.Value = keep.Data[value.Name]

		value:GetPropertyChangedSignal("Value"):Connect(function() -- should clean on value destroy
			keep.Data[value.Name] = value.Value
		end)

		value.Parent = parent

		playerClass._keys[value.Name] = value
	end

    -- "attributes" and "leaderstats" are folders in the script parent
	-- which contains numberValues / stringValues / boolValues

	for _, attribute in ipairs(script.Parent.attributes:GetChildren()) do
		bindData(attribute, attributes)
	end

	for _, leaderstat in ipairs(script.Parent.leaderstats:GetChildren()) do
		bindData(leaderstat, leaderstats)
	end

	-- listen for globals
end

local function loadKeep(playerClass)
	local player = playerClass.Player

	local keep = keepStore:LoadKeep("Player_" .. player.UserId)

	keep:andThen(function(dataKeep)
		if dataKeep == nil then
			player:Kick("Session locked")
		end

		dataKeep:Reconcile()
		dataKeep:AddUserId(player.UserId) -- help with GDPR requests

		dataKeep.Releasing:Connect(function(releaseState) -- don't have to clean up, it cleans up internally
			releaseState
				:andThen(function()
					player:Kick("Session released")
				end)
				:catch(function(err)
					warn(err)
				end)
		end)

		if not player:IsDescendantOf(Players) then
			playerClass:Destroy()
			return
		end

		initKeep(playerClass, dataKeep)
	end)

	return keep -- so they can attach to the promise
end

--> Constructor

function Player.new(player)
	local self = setmetatable({
		Player = player,

		Keep = {},

		_keys = {}, -- stored attribute / leaderstats keys for changing to automatically change the datakeep. **MUST USE THESE FOR ANY ATTRIBUTES / LEADERSTATS BINDED**
	}, Player)

	self.Keep = loadKeep(self)

	return self
end

--> Public Methods

function Player:GetKey(keyName: string)
	return self._keys[keyName]
end

function Player:GetData(key: string)
	local keep = self.Keep:expect()
	return keep.Data[key]
end

function Player:Destroy()
	-- do cleaning, this should generally include releasing the keep

	local keep = self.Keep:expect()
	keep:Release()
end

return Player
```
