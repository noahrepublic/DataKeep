return function()
	local datakeep = require(script.Parent)

	local dataTemplate = {
		Coins = 0,
	}

	local testStore = datakeep.GetStore("Test", dataTemplate):expect()

	describe("testStore", function()
		it("should be mock", function()
			expect(testStore.Mock == true).to.be.ok()
		end)

		it("should return cached values", function()
			local testKeep1 = testStore:LoadKeep("Data"):expect()
			local testKeep2 = testStore:LoadKeep("Data"):expect()

			expect(testKeep1 == testKeep2).to.equal(true)
		end)

		it("should pass validate before saving", function()
			testStore.validate = function(data)
				for key in data do
					local dataTempVersion = dataTemplate[key]

					if typeof(data[key]) ~= typeof(dataTempVersion) then
						return false, "Invalid type for key " .. key
					end
				end

				return true
			end

			local testKeep = testStore:LoadKeep("Data"):expect()

			testKeep.Data.Coins = "not a number"

			testKeep:Save()

			local testDataStoreRaw = testStore._store:GetAsync("Data")

			expect(type(testDataStoreRaw.Data.Coins)).to.equal("string")
		end)
	end)

	local testKeep = testStore:LoadKeep("Data"):expect()

	describe("testKeep", function()
		it("should own session lock", function()
			expect(testKeep.MetaData.ActiveSession == { PlaceID = game.PlaceId, JobID = game.JobId })
		end)

		it("should add userids", function()
			testKeep:AddUserId(0)

			expect(table.find(testKeep.UserIds, 0)).to.be.ok()
		end)

		it("should remove userids", function()
			testKeep:RemoveUserId(0)
			expect(table.find(testKeep.UserIds, 0)).never.to.be.ok()
		end)

		it("should be active", function()
			expect(testKeep:IsActive()).to.be.ok()
		end)

		it("should reconcile missing data", function()
			testKeep.Data.Coins = nil
			testKeep:Reconcile()

			expect(testKeep.Data.Coins == 0).to.be.ok()
		end)

		it("should be able to rollback versions", function()
			testKeep.Data.Coins = 100
			testKeep:Save()

			expect(testKeep.Data.Coins == 100).to.be.ok()

			local versions = testKeep:GetVersions()

			local iterator = versions:expect()

			local versionToRoll = iterator.Current()
			testKeep:SetVersion(versionToRoll.Version)

			expect(testKeep.Data.Coins == 0).to.be.ok()
		end)

		it("should add an update", function()
			testStore:PostGlobalUpdate("Data", function(globalUpdates)
				globalUpdates:AddGlobalUpdate({
					Message = "Hello",
				})
			end)
		end)

		it("should change and add to an active update", function()
			testStore:PostGlobalUpdate("Data", function(globalUpdates)
				for i, globalUpdate in globalUpdates:GetActiveUpdates() do
					globalUpdates:ChangeActiveUpdate(globalUpdate.ID, {
						Message = globalUpdate.Data.Message .. "Goodbye",
					})

					expect(#globalUpdates:GetActiveUpdates() == 1).to.be.ok()
					expect(globalUpdates:GetActiveUpdates()[i].Data.Message == "HelloGoodbye").to.be.ok()
				end
			end)
		end)

		it("should get active updates", function()
			testStore:PostGlobalUpdate("Data", function(globalUpdates)
				expect(#globalUpdates:GetActiveUpdates() == 1).to.be.ok()
			end)
		end)

		it("should remove an active update", function()
			testStore:PostGlobalUpdate("Data", function(globalUpdates)
				for i, globalUpdate in globalUpdates:GetActiveUpdates() do
					globalUpdates:RemoveActiveUpdate(globalUpdate.ID)

					expect(#globalUpdates:GetActiveUpdates() == 0).to.be.ok()
				end
			end)
		end)

		it("should clear locked updates", function()
			warn(testKeep:GetLockedGlobalUpdates())

			for _, update in testKeep:GetLockedGlobalUpdates() do
				testKeep:ClearLockedUpdate(update.ID)
			end

			expect(#testKeep:GetLockedGlobalUpdates() == 0).to.be.ok()
		end)

		it("should let viewkeeps :Overwrite", function()
			local viewKeep = testStore:ViewKeep("Data"):expect()

			viewKeep.Data.Coins = 100

			viewKeep:Overwrite()
			expect(viewKeep.Data.Coins == 100).to.be.ok()
		end)

		-- it("should not let viewkeeps change data", function()
		-- 	local viewKeep = testStore:ViewKeep("Data"):expect()

		-- 	viewKeep.Data.Coins = 100
		-- 	testStore.IssueSignal:Connect(function(err)
		-- 		expect(err).to.be.ok()
		-- 	end)

		-- 	viewKeep:Save() -- not sure how to catch this. this doesn't error but processError does.
		-- end)
	end)
end
