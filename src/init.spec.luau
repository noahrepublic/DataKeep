return function()
	local datakeep = require(script.Parent)

	datakeep.SetConfig({
		logLevel = datakeep.Enums.LogLevel.All,
		logPromiseTraceback = true,
	})

	local dataTemplate = {
		Coins = 0,
	}

	local store = datakeep.GetStore("Test", dataTemplate, datakeep.Wrapper):expect()

	describe("datakeep", function()
		it("should only allow existing config values", function()
			local config = require(script.Parent.Config)

			local defaultAssumeDeadLock = config.assumeDeadLock

			datakeep.SetConfig({
				someRandomValue = "someRandomValue",
				assumeDeadLock = defaultAssumeDeadLock - 1,
			})

			expect((config :: any).someRandomValue).to.equal(nil)
			expect(config.assumeDeadLock).never.to.equal(defaultAssumeDeadLock)

			-- return back to defaults
			datakeep.SetConfig({
				assumeDeadLock = defaultAssumeDeadLock,
			})
		end)
	end)

	describe("store", function()
		it("should be mock", function()
			expect(store._isMockEnabled).to.equal(true)
		end)

		it("should return cached values", function()
			local keep1 = store:LoadKeep("cacheTest"):expect()
			local keep2 = store:LoadKeep("cacheTest"):expect()

			expect(keep1 == keep2).to.equal(true)
		end)

		it("should pass validate before saving", function()
			store.validate = function(data)
				for key in data do
					local dataTempVersion = dataTemplate[key]

					if typeof(data[key]) ~= typeof(dataTempVersion) then
						return false, `Invalid type for key: {key}`
					end
				end

				return true
			end

			local keep = store:LoadKeep("validateTest"):expect()
			keep.Data.Coins = "not a number"

			keep:Save():await()

			local testDataStoreRaw = store._datastore:GetAsync("validateTest")
			expect(testDataStoreRaw.Data.Coins).to.be.a("number")

			store.validate = function() -- revert to prevent other tests from failing
				return true
			end
		end)

		it("should wait for previous keep to release before loading again and loads it's data", function()
			local keep = store:LoadKeep("awaitReleaseTest"):expect()
			keep.Data.Money = 50

			keep._releasing = true -- tell future :LoadKeep() that this keep is in releasing process. This is the only way to check if it's working

			local start = os.clock()

			task.delay(2, function()
				keep:Release()
					:andThen(function()
						print("[DataKeep Unit Tests] Time passed while waiting for keep to release:", os.clock() - start)
					end)
					:await()
			end)

			keep = store:LoadKeep("awaitReleaseTest"):expect()

			expect(keep ~= nil).to.be.ok()
			expect(keep.Data.Money).to.equal(50)
		end)

		it("should remove saved keep", function()
			local keep = store:LoadKeep("removeTest"):expect()
			keep.Data.Money = 50

			keep:Release():await()

			local testDataStoreRaw = store._datastore:GetAsync("removeTest")
			expect(testDataStoreRaw).to.be.a("table")
			expect(testDataStoreRaw.Data.Money).to.equal(50)

			local oldData, datastoreKeyInfo = store:RemoveKeep("removeTest"):expect()
			expect(oldData ~= nil).to.be.ok()
			expect(datastoreKeyInfo ~= nil).to.be.ok()

			testDataStoreRaw = store._datastore:GetAsync("removeTest")
			expect(testDataStoreRaw).to.equal(nil)
		end)
	end)

	describe("keep", function()
		it("should save keep", function()
			local keep = store:LoadKeep("Data"):expect()
			keep.Data.Coins = 100

			keep:Save():await()

			local testDataStoreRaw = store._datastore:GetAsync("Data")
			expect(testDataStoreRaw.Data.Coins).to.equal(100)
		end)

		it("should not let view-only keep save data", function()
			local viewKeep = store:ViewKeep("Data2"):expect()
			viewKeep.Data.Coins = 100

			local success = viewKeep:Save():await()
			expect(success).to.equal(false)
		end)

		it("should not let view-only keep release", function()
			local viewKeep = store:ViewKeep("Data3"):expect()
			viewKeep.Data.Coins = 100

			local success = viewKeep:Release():await()
			expect(success).to.equal(false)
		end)

		it("should let view-only keeps overwrite data", function()
			local viewKeep = store:ViewKeep("Data"):expect()
			viewKeep.Data.Coins = 100

			local success = viewKeep:Overwrite():await()
			expect(success).to.equal(true)

			expect(viewKeep.Data.Coins).to.equal(100)

			local testDataStoreRaw = store._datastore:GetAsync("Data")
			expect(testDataStoreRaw.Data.Coins).to.equal(100)
		end)

		it("should own session lock", function()
			local thisSession = { PlaceId = game.PlaceId, JobId = game.JobId }

			local keep = store:LoadKeep("Data"):expect()
			expect(keep.MetaData.ActiveSession == thisSession).to.be.ok()
		end)

		it("should be active", function()
			local keep = store:LoadKeep("Data"):expect()
			expect(keep:IsActive()).to.equal(true)
		end)

		it("should add userId", function()
			local keep = store:LoadKeep("Data"):expect()

			keep:AddUserId(0)

			expect(table.find(keep.UserIds, 0)).to.be.ok()
		end)

		it("should remove userId", function()
			local keep = store:LoadKeep("Data"):expect()

			keep:RemoveUserId(0)

			expect(table.find(keep.UserIds, 0)).never.to.be.ok()
		end)

		it("should reconcile missing data", function()
			local keep = store:LoadKeep("Data"):expect()
			keep.Data.Coins = nil

			keep:Reconcile()

			expect(keep.Data.Coins).to.equal(0)
		end)

		it("should be able to rollback versions", function()
			local keep = store:LoadKeep("Data5"):expect()
			keep.Data.Coins = 100

			keep:Save():await()

			expect(keep.Data.Coins).to.equal(100)

			local testDataStoreRaw = store._datastore:GetAsync("Data5")
			expect(testDataStoreRaw.Data.Coins).to.equal(100)

			local versions = keep:GetVersions()
			local iterator = versions:expect()

			local versionToRoll = iterator.Current()
			keep:SetVersion(versionToRoll.Version):await()

			expect(keep.Data.Coins).to.equal(0)
		end)

		it("should release keep", function()
			local keep = store:LoadKeep("Data"):expect()

			keep:Release():await()

			local testDataStoreRaw = store._datastore:GetAsync("Data")
			expect(testDataStoreRaw.MetaData.ActiveSession).to.equal(nil)
		end)
	end)

	describe("globalUpdates", function()
		it("should add an global update to new keep", function()
			store
				:PostGlobalUpdate("NewKeep", function(globalUpdates)
					globalUpdates:AddGlobalUpdate({
						Message = "World",
					})

					expect(#globalUpdates:GetActiveUpdates()).to.equal(1)
				end)
				:await()

			local testDataStoreRaw = store._datastore:GetAsync("NewKeep")
			expect(testDataStoreRaw.GlobalUpdates.Updates[1].Data.Message).to.equal("World")
		end)

		it("should add an global update to offline keep", function()
			local keep = store:LoadKeep("OfflineKeep"):expect()
			keep:Release():await()

			local datastoreRaw = store._datastore:GetAsync("OfflineKeep")
			expect(#datastoreRaw.GlobalUpdates.Updates).to.equal(0)

			store
				:PostGlobalUpdate("OfflineKeep", function(globalUpdates)
					globalUpdates:AddGlobalUpdate({
						Message = "HelloWorld",
					})

					expect(#globalUpdates:GetActiveUpdates()).to.equal(1)
				end)
				:await()

			datastoreRaw = store._datastore:GetAsync("OfflineKeep")
			expect(datastoreRaw.GlobalUpdates.Updates[1].Data.Message).to.equal("HelloWorld")
		end)

		it("should add an global update to already loaded keep", function()
			store:LoadKeep("Data"):expect()

			store
				:PostGlobalUpdate("Data", function(globalUpdates)
					globalUpdates:AddGlobalUpdate({
						Message = "Hello",
					})

					expect(#globalUpdates:GetActiveUpdates()).to.equal(1)
				end)
				:await()

			local testDataStoreRaw = store._datastore:GetAsync("Data")
			expect(testDataStoreRaw.GlobalUpdates.Updates[1].Data.Message).to.equal("Hello")
		end)

		it("should change and add to an active update", function()
			store
				:PostGlobalUpdate("Data", function(globalUpdates)
					for i, globalUpdate in globalUpdates:GetActiveUpdates() do
						globalUpdates:ChangeActiveUpdate(globalUpdate.Id, {
							Message = `{globalUpdate.Data.Message}Goodbye`,
						})

						expect(#globalUpdates:GetActiveUpdates()).to.equal(1)
						expect(globalUpdates:GetActiveUpdates()[i].Data.Message).to.equal("HelloGoodbye")
					end
				end)
				:await()

			local testDataStoreRaw = store._datastore:GetAsync("Data")
			expect(#testDataStoreRaw.GlobalUpdates.Updates).to.equal(1)
			expect(testDataStoreRaw.GlobalUpdates.Updates[1].Data.Message).to.equal("HelloGoodbye")
		end)

		it("should get active updates", function()
			store
				:PostGlobalUpdate("Data", function(globalUpdates)
					expect(#globalUpdates:GetActiveUpdates()).to.equal(1)
				end)
				:await()

			local keep = store:LoadKeep("Data"):expect()
			expect(#keep:GetActiveGlobalUpdates()).to.equal(0)
		end)

		it("should remove an active update", function()
			store
				:PostGlobalUpdate("Data", function(globalUpdates)
					expect(#globalUpdates:GetActiveUpdates()).to.equal(1)

					for _, globalUpdate in globalUpdates:GetActiveUpdates() do
						globalUpdates:RemoveActiveUpdate(globalUpdate.Id)

						expect(#globalUpdates:GetActiveUpdates()).to.equal(0)
					end
				end)
				:await()

			local testDataStoreRaw = store._datastore:GetAsync("Data")
			expect(#testDataStoreRaw.GlobalUpdates.Updates).to.equal(0)
		end)

		it("should clear locked updates", function()
			local keep = store:LoadKeep("ClearLockTest"):expect()

			store
				:PostGlobalUpdate("ClearLockTest", function(globalUpdates)
					globalUpdates:AddGlobalUpdate({
						Message = "ClearLockTest",
					})

					expect(#globalUpdates:GetActiveUpdates()).to.equal(1)
				end)
				:await()

			keep:Save():await() -- get new and lock globalUpdates

			expect(#keep:GetLockedGlobalUpdates()).to.equal(1)

			for _, update in keep:GetLockedGlobalUpdates() do
				keep:ClearLockedUpdate(update.Id):await()
			end

			keep:Save():await()

			expect(#keep:GetLockedGlobalUpdates()).to.equal(0)
		end)
	end)
end
