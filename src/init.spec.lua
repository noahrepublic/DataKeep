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

			expect(type(testDataStoreRaw.Data.Coins)).to.equal("number")
		end)
	end)

	local testKeep = testStore:LoadKeep("Data"):expect()

	describe("testKeep", function()
		it("should own session lock", function()
			expect(testKeep.MetaData.ActiveSession == { PlaceID = game.PlaceId, JobID = game.JobId })
		end)
	end)
end
