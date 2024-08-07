---
sidebar_position: 5
---

# WriteLib

WriteLib provides a way to give Keeps custom mutating functions. A [prebuilt WriteLib](https://github.com/noahrepublic/DataKeep/blob/main/src/Wrapper.lua) is provided in the module, but you can make your own, Keeps will inherit functions from the WriteLib.

## Defining a custom WriteLib

```lua
-- WriteLib.lua

return {
    AddCoins = function(self, amount: number)
        self.Data.Coins += amount
    end,
    RemoveCoins = function(self, amount: number)
        self.Data.Coins -= amount
    end,
}
```

```lua
-- Main.lua

local dataTemplate = {
    Coins = 0
}

local keepStore = DataKeep.GetStore("PlayerData", dataTemplate):expect()

keepStore.Wrapper = require(path_to_custom_WriteLib)

keepStore:LoadKeep(`Player_{player.UserId}`):andThen(function(keep)
    keep:AddCoins(100)
    keep:RemoveCoins(50)
end)
```
