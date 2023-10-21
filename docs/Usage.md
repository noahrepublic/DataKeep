---
sidebar_position: 3
---

# Basic Usage

DataKeep will lift everything, the only thing you need to do is load data. DataKeep does not use getter/setter functions allowing for customizable experience like, make your own wrapper.

The following is a very basic Keep loader implementation.

```lua
local Players = game:GetService("Player")

local DataKeep = require(path_to_datakeep)

local defaultData = {
    Coins = 0,
}

local loadedKeeps = {}

local keepStore = DataKeep.GetStore("PlayerData", defaultData) -- generally you can just :awaitValue() I just want to showcase Promises to those unfamiliar

local function onPlayerJoin(player)
    keepStore:LoadKeep("Player_" .. player.UserId):andThen(function(keep)
        if keep == nil then
            player:Kick("Data locked") -- will never happen, when no releaseHandler is passed it default steals from the locked session
        end

        keep:Reconcile()

        keep.OnRelease:Connect(function() -- don't have to clean up, it cleans up internally.
            player:Kick("Session Release")
        end)

        if not player:IsDescendantOf(Players) then
            keep:Release()
            return
        end

        print(`Loaded {player.Name}'s Keep!`)
            
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
    Players.PlayerAdded:Connect(onPlayerJoin)
end)
```

# Class Approach

For more experienced developers I personally opt in to create a service that returns a "Player" OOP class that holds it own cleaner and a Keep inside.
