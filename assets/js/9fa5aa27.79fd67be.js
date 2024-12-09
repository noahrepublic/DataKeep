"use strict";(self.webpackChunkdocs=self.webpackChunkdocs||[]).push([[723],{3245:e=>{e.exports=JSON.parse('{"functions":[{"name":"Identify","desc":"Returns the string identifier for the Store.","params":[],"returns":[{"desc":"","lua_type":"string"}],"function_type":"method","source":{"line":137,"path":"src/Store.luau"}},{"name":"LoadKeep","desc":"Loads a Keep from the store and returns a Keep object.\\n\\n```lua\\nstore:LoadKeep(`Player_{player.UserId}`, function()\\n\\treturn DataKeep.Enums.LoadMethod.ForceLoad\\nend)):andThen(function(keep)\\n\\tprint(`Loaded {keep:Identify()}!`)\\nend):catch(function()\\n\\tplayer:Kick(\\"Data failed to load\\")\\nend)\\n```\\n\\n:::info\\nKeeps are cached, that way you can call [:LoadKeep()](#LoadKeep) multiple times and get the same Keeps.\\n:::","params":[{"name":"key","desc":"","lua_type":"string"},{"name":"unreleasedHandler","desc":"","lua_type":"unreleasedHandler?"}],"returns":[{"desc":"","lua_type":"Promise<Keep>"}],"function_type":"method","source":{"line":171,"path":"src/Store.luau"}},{"name":"ViewKeep","desc":"Loads a Keep from the store and returns a Keep object, but doesn\'t save it.\\n\\nView-only Keeps have the same functions as normal Keeps, but cannot operate on data.\\n\\n```lua\\nstore:ViewKeep(`Player_{player.UserId}`):andThen(function(viewOnlyKeep)\\n\\tprint(`Viewing {viewOnlyKeep:Identify()}!`)\\nend):catch(function(err)\\n\\twarn(`Something went wrong! {err}`)\\nend)\\n```\\n\\n:::danger\\nView-only Keeps are not cached!\\n:::\\n\\n:::danger\\n[Keep:Destroy()](Keep#Destroy) must be called when view-only Keep is not needed anymore.\\n:::","params":[{"name":"key","desc":"","lua_type":"string"},{"name":"version","desc":"","lua_type":"string?"}],"returns":[{"desc":"","lua_type":"Promise<Keep>"}],"function_type":"method","source":{"line":481,"path":"src/Store.luau"}},{"name":"RemoveKeep","desc":"Removes the ```key``` from the DataStore.\\n\\n:::info\\nCalling ```:RemoveKeep()``` on the loaded Keep will release it (.Releasing signal will be fired) before removing.\\n:::\\n\\n:::warning\\nIn live servers ```:RemoveKeep()``` must be used on Keeps created through mock stores.\\n:::","params":[{"name":"key","desc":"","lua_type":"string"}],"returns":[{"desc":"","lua_type":"Promise<previousData, DataStoreKeyInfo>"}],"function_type":"method","source":{"line":584,"path":"src/Store.luau"}},{"name":"PreLoad","desc":"Runs before loading a Keep, allowing you to modify the data before, like decompressing compressed data.\\n\\nDecompression example:\\n\\n```lua\\nstore:PreLoad(function(data)\\n\\tlocal newData = {}\\n\\n\\tfor key, value in data do\\n\\t\\tnewData[key] = HttpService:JSONDecode(value)\\n\\tend\\n\\n\\treturn newData\\nend)\\n```\\n\\n:::warning\\nCallback **must** return a new data table.\\n:::\\n\\n:::danger\\n```:PreLoad()``` can only be set once.\\n:::","params":[{"name":"callback","desc":"","lua_type":"({ [string]: any }) -> { [string]: any }"}],"returns":[],"function_type":"method","source":{"line":641,"path":"src/Store.luau"}},{"name":"PreSave","desc":"Runs before saving a Keep, allowing you to modify the data before, like compressing data.\\n\\nCompression example:\\n\\n```lua\\nstore:PreSave(function(data)\\n\\tlocal newData = {}\\n\\n\\tfor key, value in data do\\n\\t\\tnewData[key] = HttpService:JSONEncode(value)\\n\\tend\\n\\n\\treturn newData\\nend)\\n```\\n\\n:::warning\\nCallback **must** return a new data table.\\n:::\\n\\n:::danger\\n```:PreSave()``` can only be set once.\\n:::","params":[{"name":"callback","desc":"","lua_type":"({ [string]: any }) -> { [string]: any }"}],"returns":[],"function_type":"method","source":{"line":679,"path":"src/Store.luau"}},{"name":"PostGlobalUpdate","desc":"Posts a global update to a Keep.\\n\\n```lua\\nstore:PostGlobalUpdate(`Player_{player.UserId}`, function(globalUpdates)\\n\\tglobalUpdates:AddGlobalUpdate({\\n\\t\\tHello = \\"World!\\",\\n\\t}):andThen(function(updateId)\\n\\t\\tprint(\\"Added Global Update!\\")\\n\\tend)\\nend)\\n```\\n\\n:::info\\nCheck [GlobalUpdates](GlobalUpdates) for more info.\\n:::\\n\\n:::danger\\nYielding inside ```updateHandler``` is not allowed.\\n:::","params":[{"name":"key","desc":"","lua_type":"string"},{"name":"updateHandler","desc":"","lua_type":"(GlobalUpdates) -> ()"}],"returns":[{"desc":"","lua_type":"Promise<updatedData, DataStoreKeyInfo>"}],"function_type":"method","source":{"line":716,"path":"src/Store.luau"}}],"properties":[{"name":"Mock","desc":"Same as [Store](Store) but it operates on a fake datastore.\\n\\n```lua\\nlocal store = DataKeep.GetStore(\\"TestStore\\", {}, {}):expect()\\n\\nlocal keep = store.Mock:LoadKeep(\\"TestKey\\"):expect()\\nkeep:Release():await()\\n\\n-- must be used when done with the keep on live servers\\nstore.Mock:RemoveKeep(\\"TestKey\\")\\n```","lua_type":"MockStore","source":{"line":53,"path":"src/Store.luau"}},{"name":"validate","desc":"Used to validate data before saving. Ex. type guards.\\n\\n```lua\\nstore.validate = function(data)\\n\\tfor key, value in data do\\n\\t\\tlocal dataTempVersion = dataTemplate[key]\\n\\n\\t\\tif typeof(data[key]) ~= typeof(dataTempVersion) then\\n\\t\\t\\treturn false, `Invalid type for key: {key}`\\n\\t\\tend\\n\\tend\\n\\n\\treturn true\\nend\\n```","lua_type":"({ [string]: any }) -> true | (false&string)","source":{"line":74,"path":"src/Store.luau"}}],"types":[{"name":"StoreInfo","desc":"Table format for a store\'s info in [.GetStore()](#GetStore).","lua_type":"{ Name: string, Scope: string? }","source":{"line":69,"path":"src/Types.luau"}},{"name":"unreleasedHandler","desc":"Used to determine how to handle an session locked Keep.\\n\\n:::info\\nCheck [LoadMethod] for more info.\\n:::","lua_type":"(Session) -> string","source":{"line":85,"path":"src/Types.luau"}},{"name":"StoreBase","desc":"","lua_type":"{}","source":{"line":96,"path":"src/Types.luau"}},{"name":"MockStore","desc":"MockStores are used to mirror the real store, but doesn\'t save data.","lua_type":"StoreBase","source":{"line":129,"path":"src/Types.luau"}},{"name":"Store","desc":"Stores are used to load and save Keeps from a [DataStoreService:GetDataStore()](https://create.roblox.com/docs/reference/engine/classes/DataStoreService#GetDataStore).","lua_type":"StoreBase & { Mock: MockStore }","source":{"line":138,"path":"src/Types.luau"}}],"name":"Store","desc":"","realm":["Server"],"source":{"line":36,"path":"src/Store.luau"}}')}}]);