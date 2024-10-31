---
sidebar_position: 4
---

# WriteLib

WriteLib provides a way to give Keeps custom mutating functions. A [prebuilt WriteLib](https://github.com/noahrepublic/DataKeep/blob/main/src/Wrapper.luau) is provided in the module, but you can make your own, Keeps will inherit functions from the WriteLib.

## Defining a custom WriteLib

```lua
-- WriteLib.luau

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
-- Main.luau

local dataTemplate = {
    Coins = 0
}

local wrapper = require(path_to_custom_WriteLib)

local store = DataKeep.GetStore("PlayerData", dataTemplate, wrapper):expect()

store:LoadKeep(`Player_{player.UserId}`):andThen(function(keep)
    keep:AddCoins(100)
    keep:RemoveCoins(50)
end)
```
