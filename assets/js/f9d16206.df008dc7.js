"use strict";(self.webpackChunkdocs=self.webpackChunkdocs||[]).push([[137],{17893:e=>{e.exports=JSON.parse('{"functions":[{"name":"AddGlobalUpdate","desc":"Adds a global update to the Keep\\n\\n```lua\\nglobalUpdates:AddGlobalUpdate({\\n\\tHello = \\"World!\\",\\n}):andThen(function(updateId)\\n\\tprint(\\"Added Global Update!\\")\\nend)\\n```","params":[{"name":"globalData","desc":"","lua_type":"{}"}],"returns":[{"desc":"","lua_type":"Promise<GlobalId>"}],"function_type":"method","source":{"line":933,"path":"src/init.luau"}},{"name":"GetActiveUpdates","desc":"Returns all **active** global updates\\n\\n```lua\\nlocal updates = globalUpdates:GetActiveUpdates()\\n\\nfor _, update in updates do\\n\\tprint(\\"ActiveUpdate data:\\", update.Data)\\nend\\n```","params":[],"returns":[{"desc":"","lua_type":"{ GlobalUpdate }"}],"function_type":"method","source":{"line":973,"path":"src/init.luau"}},{"name":"RemoveActiveUpdate","desc":"Removes an active global update\\n\\n```lua\\nlocal updates = globalUpdates:GetActiveUpdates()\\n\\nfor _, update in updates do\\n\\tglobalUpdates:RemoveActiveUpdate(update.ID):andThen(function()\\n\\t\\tprint(\\"Removed Global Update!\\")\\n\\tend)\\nend\\n```","params":[{"name":"updateId","desc":"","lua_type":"GlobalId"}],"returns":[{"desc":"","lua_type":"Promise<void>"}],"function_type":"method","source":{"line":1012,"path":"src/init.luau"}},{"name":"ChangeActiveUpdate","desc":"Change an **active** global update\'s data to the new data.\\n\\nUseful for stacking updates to save space for Keeps that maybe receiving lots of globals. Ex. a content creator receiving gifts","params":[{"name":"updateId","desc":"","lua_type":"GlobalId"},{"name":"globalData","desc":"","lua_type":"{}"}],"returns":[{"desc":"","lua_type":"Promise<void>"}],"function_type":"method","source":{"line":1065,"path":"src/init.luau"}}],"properties":[],"types":[{"name":"GlobalId","desc":"Used to identify a global update","lua_type":"number","source":{"line":914,"path":"src/init.luau"}}],"name":"GlobalUpdates","desc":"Used to add, lock and change global updates\\n\\nRevealed through [:PostGlobalUpdate()](Store#PostGlobalUpdate)","realm":["Server"],"source":{"line":907,"path":"src/init.luau"}}')}}]);