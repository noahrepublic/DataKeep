---
sidebar_position: 5
---

# WriteLib

WriteLib provides a way to give Keeps custom mutating functions. A prebuilt WriteLib is provided in the module, but you can make your own, Keeps will inherit functions from the WriteLib

## Defining a WriteLib

```lua
-- WriteLib.lua (stored anywheres you can access)
return {
    AddCoins = function(keep, amount)
        keep.Data.Coins += amount
    end,
    RemoveCoins = function(keep, amount)
        keep.Data.Coins -= amount
    end,
}

-- main.lua

DataKeep.WriteLib = require(path_to_WriteLib)

local keepStore = DataKeep.GetStore("PlayerData", defaultData):awaitValue()

keepStore:LoadKeep("Player_" .. player.UserId):andThen(function(keep)
    keep:AddCoins(100)
    keep:RemoveCoins(50)
end)
```

