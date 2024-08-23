"use strict";(self.webpackChunkdocs=self.webpackChunkdocs||[]).push([[790],{50967:e=>{e.exports=JSON.parse('{"functions":[{"name":"GetStore","desc":"Loads a store from a [DataStoreService:GetDataStore()](https://create.roblox.com/docs/reference/engine/classes/DataStoreService#GetDataStore) and returns a Store object\\n\\n```lua\\nlocal keepStore = DataKeep.GetStore(\\"TestStore\\", {\\n\\tTest = \\"Hello World!\\",\\n}):expect()\\n```","params":[{"name":"storeInfo","desc":"","lua_type":"StoreInfo | string"},{"name":"dataTemplate","desc":"","lua_type":"any"}],"returns":[{"desc":"","lua_type":"Promise<Store>"}],"function_type":"static","source":{"line":315,"path":"src/init.luau"}},{"name":"LoadKeep","desc":"Loads a Keep from the store and returns a Keep object\\n\\n```lua\\nkeepStore:LoadKeep(`Player_{player.UserId}`, function()\\n\\treturn keepStore.LoadMethods.ForceLoad\\nend)):andThen(function(keep)\\n\\tif not keep then\\n\\t\\tplayer:Kick(\\"Session lock interrupted!\\")\\n\\t\\treturn\\n\\tend\\n\\n\\tprint(`Loaded {keep:Identify()}!`)\\nend)\\n```\\n\\n:::info\\nStores can be loaded multiple times as they are cached, that way you can call [:LoadKeep()](#LoadKeep) and get the same cached Keeps.\\n:::info","params":[{"name":"key","desc":"","lua_type":"string"},{"name":"unreleasedHandler","desc":"","lua_type":"unreleasedHandler?"}],"returns":[{"desc":"","lua_type":"Promise<Keep?>"}],"function_type":"method","source":{"line":431,"path":"src/init.luau"}},{"name":"ViewKeep","desc":"Loads a Keep from the store and returns a Keep object, but doesn\'t save it\\n\\nView-only Keeps have the same functions as normal Keeps, but can not operate on data\\n\\n```lua\\nkeepStore:ViewKeep(`Player_{player.UserId}`):andThen(function(viewOnlyKeep)\\n\\tprint(`Viewing {viewOnlyKeep:Identify()}!`)\\nend)\\n```\\n\\n:::warning\\nView-only Keeps are not cached!\\n:::warning\\n\\n:::warning\\n[Keep:Destroy()](Keep#Destroy) must be called when view-only Keep is not needed anymore.\\n:::warning","params":[{"name":"key","desc":"","lua_type":"string"},{"name":"version","desc":"","lua_type":"string?"}],"returns":[{"desc":"","lua_type":"Promise<Keep>"}],"function_type":"method","source":{"line":711,"path":"src/init.luau"}},{"name":"PreSave","desc":"Runs before saving a Keep, allowing you to modify the data before, like compressing data\\n\\n:::caution\\nCallback **must** return a new data table.\\n:::caution\\n\\n:::warning\\n```:PreSave()``` can only be set once.\\n:::warning\\n\\nCompression example:\\n\\n```lua\\nkeepStore:PreSave(function(data)\\n\\tlocal newData = {}\\n\\n\\tfor key, value in data do\\n\\t\\tnewData[key] = HttpService:JSONEncode(value)\\n\\tend\\n\\n\\treturn newData\\nend)\\n```","params":[{"name":"callback","desc":"","lua_type":"({ [string]: any }) -> { [string]: any }"}],"returns":[],"function_type":"method","source":{"line":803,"path":"src/init.luau"}},{"name":"PreLoad","desc":"Runs before loading a Keep, allowing you to modify the data before, like decompressing compressed data\\n\\n:::caution\\nCallback **must** return a new data table.\\n:::caution\\n\\n:::warning\\n```:PreLoad()``` can only be set once.\\n:::warning\\n\\nDecompression example:\\n\\n```lua\\nkeepStore:PreLoad(function(data)\\n\\tlocal newData = {}\\n\\n\\tfor key, value in data do\\n\\t\\tnewData[key] = HttpService:JSONDecode(value)\\n\\tend\\n\\n\\treturn newData\\nend)\\n```","params":[{"name":"callback","desc":"","lua_type":"({ [string]: any }) -> { [string]: any }"}],"returns":[],"function_type":"method","source":{"line":841,"path":"src/init.luau"}},{"name":"PostGlobalUpdate","desc":"Posts a global update to a Keep\\n\\n```updateHandler``` reveals globalUpdates to the API\\n\\n```lua\\nkeepStore:PostGlobalUpdate(`Player_{player.UserId}`, function(globalUpdates)\\n\\tglobalUpdates:AddGlobalUpdate({\\n\\t\\tHello = \\"World!\\",\\n\\t}):andThen(function(updateId)\\n\\t\\tprint(\\"Added Global Update!\\")\\n\\tend)\\nend)\\n```","params":[{"name":"key","desc":"","lua_type":"string"},{"name":"updateHandler","desc":"","lua_type":"(GlobalUpdates) -> ()"}],"returns":[{"desc":"","lua_type":"Promise<updatedData,DataStoreKeyInfo>"}],"function_type":"method","source":{"line":872,"path":"src/init.luau"}}],"properties":[{"name":"LoadMethods","desc":"","lua_type":"LoadMethods","source":{"line":91,"path":"src/init.luau"}},{"name":"Wrapper","desc":"Wrapper functions that are inheritted by Keeps when they are loaded\\n\\n:::info\\nAny wrapper changes post [.GetStore()](#GetStore) will not apply to that store but the next one.\\n:::info","lua_type":"{}","source":{"line":102,"path":"src/init.luau"}},{"name":"Mock","desc":"A mock store that mirrors the real store, but doesn\'t save data","lua_type":"MockStore","source":{"line":109,"path":"src/init.luau"}},{"name":"IssueSignal","desc":"Fired when an issue occurs, like a failed request\\n\\n```lua\\nkeepStore.IssueSignal:Connect(function(err)\\n\\tprint(\\"Issue!\\", err)\\nend)\\n```","lua_type":"Signal","source":{"line":122,"path":"src/init.luau"}},{"name":"CriticalStateSignal","desc":"Fired when the store enters critical state. After it has failed many requests and maybe dangerous to proceed with purchases or other important actions\\n\\n```lua\\nkeepStore.CriticalStateSignal:Connect(function()\\n\\tprint(\\"Critical State!\\")\\nend)\\n```","lua_type":"Signal","source":{"line":135,"path":"src/init.luau"}},{"name":"CriticalState","desc":"Whether the store is in critical state or not. See [CriticalStateSignal](#CriticalStateSignal)\\n\\n```lua\\nif keepStore.CriticalState then\\n\\twarn(\\"Critical State!\\")\\n\\treturn\\nend\\n\\n-- process purchase\\n```","lua_type":"boolean","source":{"line":151,"path":"src/init.luau"}},{"name":"validate","desc":"Used to validate data before saving. Ex. type guards\\n\\n```lua\\nkeepStore.validate = function(data)\\n\\tfor key, value in data do\\n\\t\\tlocal dataTempVersion = dataTemplate[key]\\n\\n\\t\\tif typeof(data[key]) ~= typeof(dataTempVersion) then\\n\\t\\t\\treturn false, `Invalid type for key: {key}`\\n\\t\\tend\\n\\tend\\n\\n\\treturn true\\nend\\n```","lua_type":"({ [string]: any }) -> true | (false & string)","source":{"line":172,"path":"src/init.luau"}}],"types":[{"name":"StoreInfo","desc":"Table format for a store\'s info in [.GetStore()](#GetStore)","lua_type":"{ Name: string, Scope: string? }","source":{"line":68,"path":"src/init.luau"}},{"name":"Store","desc":"Stores are used to load and save Keeps from a [DataStoreService:GetDataStore()](https://create.roblox.com/docs/reference/engine/classes/DataStoreService#GetDataStore)","lua_type":"{ LoadMethods: LoadMethods, Mock: MockStore, LoadKeep: (string, unreleasedHandler?) -> Promise<Keep>, ViewKeep: (string) -> Promise<Keep>, PreSave: (({ any }) -> { any }) -> (), PreLoad: (({ any }) -> { any }) -> (), PostGlobalUpdate: (string, (GlobalUpdates) -> ()) -> Promise<void>, IssueSignal: Signal, CriticalStateSignal: Signal, CriticalState: boolean }","source":{"line":86,"path":"src/init.luau"}},{"name":"LoadMethods","desc":"### \\"ForceLoad\\" (default)\\n\\nAttempts to load the Keep. If the Keep is session-locked, it will either be released for that remote server or \\"stolen\\" if it\'s not responding (possibly in dead lock).\\n\\n\\n### \\"Steal\\"\\n\\nLoads keep immediately, ignoring an existing remote session lock and applying a session lock for this session.\\n\\n\\n### \\"Cancel\\"\\n\\nCancels the load of the Keep","lua_type":"{ ForceLoad: string, Steal: string, Cancel: string }","source":{"line":209,"path":"src/init.luau"}},{"name":"unreleasedHandler","desc":"Used to determine how to handle an session locked Keep.\\n\\n:::info\\nCheck [LoadMethods] for more info.\\n:::info","lua_type":"(Keep.ActiveSession) -> string","source":{"line":220,"path":"src/init.luau"}}],"name":"Store","desc":"A store is a class that holds inner savable objects, Keep(s), from a datastore [DataStoreService:GetDataStore()](https://create.roblox.com/docs/reference/engine/classes/DataStoreService#GetDataStore)","realm":["Server"],"source":{"line":24,"path":"src/init.luau"}}')}}]);