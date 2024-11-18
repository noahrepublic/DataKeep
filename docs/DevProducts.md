---
sidebar_position: 5
---

# Developer Products

The following example shows how you would handle developer product purchases:

```lua title="DataTemplate.luau"
local dataTemplate = {
	PurchaseHistory = {},

	Coins = 0,
}

export type template = typeof(dataTemplate)

return table.freeze(dataTemplate)
```

```lua title="DevProducts.luau"
local DataKeep = require(path_to_datakeep)
local DataTemplate = require(path_to_datatemplate)

local devProducts = {
    [product_id_here] = function(player: Player, keep: DataKeep.Keep<DataTemplate.template, {}>)
        keep.Data.Coins += 100

		print(`{player.Name} purchased some coins!`)
    end,
}

return devProducts
```

```lua title="SetProcessReceipt.luau"
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local DataKeep = require(path_to_datakeep)
local DataTemplate = require(path_to_datatemplate)
local DevProducts = require(path_to_devproducts)

local purchaseHistoryLimit = 50

local function setProcessReceipt(store: DataKeep.Store<DataTemplate.template, {}>, keyPrefix: string)
	local function processReceipt(receiptInfo): Enum.ProductPurchaseDecision
		local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)

		if not player then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		local isLoaded, keep = store:LoadKeep(keyPrefix .. player.UserId):await()

		if not isLoaded then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		if not keep then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		if not keep:IsActive() then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		if not keep.Data.PurchaseHistory then
			keep.Data.PurchaseHistory = {}
		end

		if table.find(keep.Data.PurchaseHistory, receiptInfo.PurchaseId) then
			-- the purchase has been added to the player's data, but it might not have saved yet
			local success = keep:Save():await()

			if success then
				return Enum.ProductPurchaseDecision.PurchaseGranted
			else
				return Enum.ProductPurchaseDecision.NotProcessedYet
			end
		end

		-- remove purchaseIds which are beyond the limit
		while #keep.Data.PurchaseHistory >= purchaseHistoryLimit do
			table.remove(keep.Data.PurchaseHistory, 1)
		end

		local grantProductSuccess = pcall(DevProducts[receiptInfo.ProductId], player, keep)

		if not grantProductSuccess then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		table.insert(keep.Data.PurchaseHistory, receiptInfo.PurchaseId)

		local saveSuccess = keep:Save():await()

		if not saveSuccess then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	MarketplaceService.ProcessReceipt = processReceipt
end

return setProcessReceipt
```

```lua title="Main.luau"
local Players = game:GetService("Players")

local DataKeep = require(path_to_datakeep)
local DataTemplate = require(path_to_datatemplate)
local SetProcessReceipt = require(path_to_setprocessreceipt)

local keyPrefix = "Player_"

local loadedKeeps = {}

local store = DataKeep.GetStore("PlayerData", DataTemplate, {}):expect()

local function onPlayerAdded(player: Player)
	store:LoadKeep(keyPrefix .. player.UserId):andThen(function(keep)
		if keep == nil then
			player:Kick("Session lock interrupted!")
		end

		keep:AddUserId(player.UserId) -- help with GDPR requests

		keep.Releasing:Connect(function(state) -- don't have to clean up, it cleans up internally
			state:andThen(function()
				print(`{player.Name}'s Keep has been released!`)

				player:Kick("Session released!")
				loadedKeeps[player] = nil
			end):catch(function(err)
				warn(`{player.Name}'s Keep failed to release!`, err)
			end)
		end)

		if not player:IsDescendantOf(Players) then
			keep:Release()
			return
		end

		loadedKeeps[player] = keep

		print(`Loaded {player.Name}'s Keep!`)
	end)
end

-- SetProcessReceipt() must be called before the onPlayerAdded(),
-- otherwise the player's existing receipts won't be processed.
SetProcessReceipt(store, keyPrefix)

-- loop through already connected players in case they joined before DataKeep loaded
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerAdded:Connect(onPlayerAdded)

Players.PlayerRemoving:Connect(function(player)
	local keep = loadedKeeps[player]

	if not keep then
		return
	end

	keep:Release()
end)
```
