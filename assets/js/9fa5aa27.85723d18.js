"use strict";(self.webpackChunkdocs=self.webpackChunkdocs||[]).push([[790],{50967:e=>{e.exports=JSON.parse('{"functions":[{"name":"GetStore","desc":"Loads a store from a DataStoreService:GetDataStore() and returns a Store object\\n\\n```lua\\nlocal keepStore = DataKeep.GetStore(\\"TestStore\\", {\\n\\tTest = \\"Hello World!\\",\\n}):awaitValue()\\n```","params":[{"name":"storeInfo","desc":"","lua_type":"StoreInfo | string"},{"name":"dataTemplate","desc":"","lua_type":"any"}],"returns":[{"desc":"","lua_type":"Promise<Store>"}],"function_type":"static","source":{"line":312,"path":"src/init.lua"}},{"name":"LoadKeep","desc":"Loads a Keep from the store and returns a Keep object\\n\\n```lua\\nkeepStore:LoadKeep(\\"Player_\\" .. player.UserId, function() return \\"Ignore\\" end)):andThen(function(keep)\\n\\tprint(\\"Loaded Keep!\\")\\nend)\\n```\\n\\n:::info\\nStores can be loaded multiple times as they are cached, that way you can call :LoadKeep() and get the same cached Keeps\\n:::info","params":[{"name":"key","desc":"","lua_type":"string"},{"name":"unReleasedHandler","desc":"","lua_type":"UnReleasedHandler?"}],"returns":[{"desc":"","lua_type":"Promise<Keep>"}],"function_type":"method","source":{"line":396,"path":"src/init.lua"}},{"name":"ViewKeep","desc":"Loads a Keep from the store and returns a Keep object, but doesn\'t save it\\n\\nView only Keeps have the same functions as normal Keeps, but can not operate on data\\n\\n```lua\\nkeepStore:ViewKeep(\\"Player_\\" .. player.UserId):andThen(function(viewOnlyKeep)\\n\\tprint(`Viewing {viewOnlyKeep:Identify()}`)\\nend)\\n```","params":[{"name":"key","desc":"","lua_type":"string"},{"name":"version","desc":"","lua_type":"string?"}],"returns":[{"desc":"","lua_type":"Promise<Keep?>"}],"function_type":"method","source":{"line":519,"path":"src/init.lua"}},{"name":"PreSave","desc":"Runs before saving a Keep, allowing you to modify the data before, like compressing data\\n\\n:::caution\\nFunctions **must** return a new data table. Failure to do so will result in data loss.\\n:::caution\\n\\n:::warning\\nPreSave can only be set once\\n:::warning\\n\\nCompression example:\\n\\n```lua\\nkeepStore:PreSave(function(data)\\n\\tlocal newData = {}\\n\\n\\tfor key, value in data do\\n\\t\\tnewData[key] = HttpService:JSONEncode(value)\\n\\tend\\n\\n\\treturn newData\\nend)\\n```","params":[{"name":"callback","desc":"","lua_type":"({ any }) -> { any: any }"}],"returns":[{"desc":"","lua_type":"void"}],"function_type":"method","source":{"line":592,"path":"src/init.lua"}},{"name":"PreLoad","desc":"Runs before loading a Keep, allowing you to modify the data before, like decompressing compressed data\\n\\n:::caution\\nFunctions **must** return a new data table. Failure to do so will result in data loss.\\n:::caution\\n\\n:::warning\\nPreLoad can only be set once\\n:::warning\\n\\nDecompression example:\\n\\n```lua\\nkeepStore:PreLoad(function(data)\\n\\tlocal newData = {}\\n\\n\\tfor key, value in data do\\n\\t\\tnewData[key] = HttpService:JSONDecode(value)\\n\\tend\\n\\n\\treturn newData\\nend)\\n```","params":[{"name":"callback","desc":"","lua_type":"({ any }) -> { any: any }"}],"returns":[{"desc":"","lua_type":"void"}],"function_type":"method","source":{"line":632,"path":"src/init.lua"}},{"name":"PostGlobalUpdate","desc":"Posts a global update to a Keep\\n\\n```updateHandler``` reveals globalUpdates to the API\\n\\n```lua\\nkeepStore:PostGlobalUpdate(\\"Player_\\" .. player.UserId, function(globalUpdates)\\n\\tglobalUpdates:AddGlobalUpdate({\\n\\t\\tHello = \\"World!\\",\\n\\t}):andThen(function(updateId)\\n\\t\\tprint(\\"Added Global Update!\\")\\n\\tend)\\nend)\\n```","params":[{"name":"key","desc":"","lua_type":"string"},{"name":"updateHandler","desc":"","lua_type":"(GlobalUpdates) -> nil"}],"returns":[{"desc":"","lua_type":"Promise<void>"}],"function_type":"method","source":{"line":665,"path":"src/init.lua"}}],"properties":[{"name":"Wrapper","desc":"Wrapper functions that are inheritted by Keeps when they are loaded\\n\\n:::info\\nAny wrapper changes post .GetStore will not apply to that store but the next one.\\n:::info","lua_type":"{}","source":{"line":98,"path":"src/init.lua"}}],"types":[{"name":"StoreInfo","desc":"Table format for a store\'s info in :GetStore()","lua_type":"{Name: string, Scope: string?}","source":{"line":70,"path":"src/init.lua"}},{"name":"Store","desc":"Stores are used to load and save Keeps from a DataStoreService:GetDataStore()","lua_type":"{Mock: MockStore, LoadKeep: (string, UnReleasedHandler?) -> Promise<Keep>, ViewKeep: (string) -> Promise<Keep>, PreSave: (({any}) -> {any}) -> nil, PreLoad: (({any}) -> {any}) -> nil, PostGlobalUpdate: (string, (GlobalUpdates) -> nil) -> Promise<void>}","source":{"line":87,"path":"src/init.lua"}},{"name":"UnReleasedActions","desc":"","lua_type":"{Ignore: string, Cancel: string}","source":{"line":119,"path":"src/init.lua"}},{"name":"UnReleasedHandler","desc":"Used to determine how to handle an session locked Keep\\n\\n### Default: \\"Ignore\\"\\n\\nIgnores the locked Keep and steals the lock, releasing the previous session \\n\\n\\n### \\"Cancel\\"\\n\\nCancels the load of the Keep","lua_type":"(Keep.ActiveSession) -> UnReleasedActions","source":{"line":136,"path":"src/init.lua"}}],"name":"Store","desc":"A store is a class that holds inner savable objects, Keep(s), from a datastore (DataStoreService:GetDataStore())","realm":["Server"],"source":{"line":25,"path":"src/init.lua"}}')}}]);