"use strict";(self.webpackChunkdocs=self.webpackChunkdocs||[]).push([[476],{3905:(e,n,a)=>{a.d(n,{Zo:()=>c,kt:()=>f});var t=a(67294);function r(e,n,a){return n in e?Object.defineProperty(e,n,{value:a,enumerable:!0,configurable:!0,writable:!0}):e[n]=a,e}function l(e,n){var a=Object.keys(e);if(Object.getOwnPropertySymbols){var t=Object.getOwnPropertySymbols(e);n&&(t=t.filter((function(n){return Object.getOwnPropertyDescriptor(e,n).enumerable}))),a.push.apply(a,t)}return a}function s(e){for(var n=1;n<arguments.length;n++){var a=null!=arguments[n]?arguments[n]:{};n%2?l(Object(a),!0).forEach((function(n){r(e,n,a[n])})):Object.getOwnPropertyDescriptors?Object.defineProperties(e,Object.getOwnPropertyDescriptors(a)):l(Object(a)).forEach((function(n){Object.defineProperty(e,n,Object.getOwnPropertyDescriptor(a,n))}))}return e}function o(e,n){if(null==e)return{};var a,t,r=function(e,n){if(null==e)return{};var a,t,r={},l=Object.keys(e);for(t=0;t<l.length;t++)a=l[t],n.indexOf(a)>=0||(r[a]=e[a]);return r}(e,n);if(Object.getOwnPropertySymbols){var l=Object.getOwnPropertySymbols(e);for(t=0;t<l.length;t++)a=l[t],n.indexOf(a)>=0||Object.prototype.propertyIsEnumerable.call(e,a)&&(r[a]=e[a])}return r}var i=t.createContext({}),p=function(e){var n=t.useContext(i),a=n;return e&&(a="function"==typeof e?e(n):s(s({},n),e)),a},c=function(e){var n=p(e.components);return t.createElement(i.Provider,{value:n},e.children)},d="mdxType",u={inlineCode:"code",wrapper:function(e){var n=e.children;return t.createElement(t.Fragment,{},n)}},y=t.forwardRef((function(e,n){var a=e.components,r=e.mdxType,l=e.originalType,i=e.parentName,c=o(e,["components","mdxType","originalType","parentName"]),d=p(a),y=r,f=d["".concat(i,".").concat(y)]||d[y]||u[y]||l;return a?t.createElement(f,s(s({ref:n},c),{},{components:a})):t.createElement(f,s({ref:n},c))}));function f(e,n){var a=arguments,r=n&&n.mdxType;if("string"==typeof e||r){var l=a.length,s=new Array(l);s[0]=y;var o={};for(var i in n)hasOwnProperty.call(n,i)&&(o[i]=n[i]);o.originalType=e,o[d]="string"==typeof e?e:r,s[1]=o;for(var p=2;p<l;p++)s[p]=a[p];return t.createElement.apply(null,s)}return t.createElement.apply(null,a)}y.displayName="MDXCreateElement"},55022:(e,n,a)=>{a.r(n),a.d(n,{assets:()=>i,contentTitle:()=>s,default:()=>u,frontMatter:()=>l,metadata:()=>o,toc:()=>p});var t=a(87462),r=(a(67294),a(3905));const l={sidebar_position:3},s="Usage",o={unversionedId:"Usage",id:"Usage",title:"Usage",description:"Basic Approach",source:"@site/docs/Usage.md",sourceDirName:".",slug:"/Usage",permalink:"/DataKeep/docs/Usage",draft:!1,editUrl:"https://github.com/noahrepublic/DataKeep/edit/main/docs/Usage.md",tags:[],version:"current",sidebarPosition:3,frontMatter:{sidebar_position:3},sidebar:"defaultSidebar",previous:{title:"Installation",permalink:"/DataKeep/docs/Installation"},next:{title:"WriteLib",permalink:"/DataKeep/docs/WriteLib"}},i={},p=[{value:"Basic Approach",id:"basic-approach",level:2},{value:"Class Approach",id:"class-approach",level:2}],c={toc:p},d="wrapper";function u(e){let{components:n,...a}=e;return(0,r.kt)(d,(0,t.Z)({},c,a,{components:n,mdxType:"MDXLayout"}),(0,r.kt)("h1",{id:"usage"},"Usage"),(0,r.kt)("h2",{id:"basic-approach"},"Basic Approach"),(0,r.kt)("p",null,"DataKeep will lift everything, the only thing you need to do is load data. DataKeep does not use getter / setter functions allowing for customizable experience like, make your own wrapper."),(0,r.kt)("p",null,"The following is a very basic Keep loader implementation."),(0,r.kt)("pre",null,(0,r.kt)("code",{parentName:"pre",className:"language-lua"},'local Players = game:GetService("Players")\n\nlocal DataKeep = require(path_to_datakeep)\n\nlocal dataTemplate = {\n    Coins = 0,\n}\n\nlocal loadedKeeps = {}\n\nlocal keepStore = DataKeep.GetStore("PlayerData", dataTemplate) -- generally you can just :expect() I just want to showcase Promises to those unfamiliar\n\nlocal function onPlayerAdded(player: Player)\n    keepStore:LoadKeep(`Player_{player.UserId}`):andThen(function(keep)\n        if keep == nil then\n            player:Kick("Session lock interrupted!")\n        end\n\n        keep:Reconcile()\n        keep:AddUserId(player.UserId) -- help with GDPR requests\n\n        keep.Releasing:Connect(function(state) -- don\'t have to clean up, it cleans up internally\n            print(`{player.Name}\'s Keep is releasing!`)\n\n            state:andThen(function()\n                print(`{player.Name}\'s Keep has been released!`)\n\n                player:Kick("Session released!")\n                loadedKeeps[player] = nil\n            end):catch(function(err)\n                warn(`{player.Name}\'s Keep failed to release!`, err)\n            end)\n        end)\n\n        if not player:IsDescendantOf(Players) then\n            keep:Release()\n            return\n        end\n\n        loadedKeeps[player] = keep\n\n        local leaderstats = Instance.new("Folder")\n        leaderstats.Name = "leaderstats"\n\n        local coins = Instance.new("NumberValue")\n        coins.Name = "Coins"\n        coins.Value = keep.Data.Coins\n\n        leaderstats.Parent = player\n\n        print(`Loaded {player.Name}\'s Keep!`)\n    end)\nend\n\nkeepStore:andThen(function(store)\n    keepStore = store\n\n    -- loop through already connected players in case they joined before DataKeep loaded\n    for _, player in Players:GetPlayers() do\n        task.spawn(onPlayerAdded, player)\n    end\n\n    Players.PlayerAdded:Connect(onPlayerAdded)\nend)\n\nPlayers.PlayerRemoving:Connect(function(player)\n    local keep = loadedKeeps[player]\n\n    if not keep then\n        return\n    end\n\n    keep:Release()\nend)\n')),(0,r.kt)("h2",{id:"class-approach"},"Class Approach"),(0,r.kt)("p",null,'For more experienced developers I personally opt in to create a service that returns a "Player" OOP class that holds it own cleaner and a Keep inside.'),(0,r.kt)("p",null,'Note: "attributes" and "leaderstats" are folders in the script parent which contains numberValues / stringValues / boolValues'),(0,r.kt)("pre",null,(0,r.kt)("code",{parentName:"pre",className:"language-lua"},'--\x3e Services\n\nlocal Players = game:GetService("Players")\n\n--\x3e Includes\n\nlocal DataKeep = require(path_to_datakeep)\n\nlocal DataTemplate = require(script.Parent.DataTemplate)\n\n--\x3e Module Definition\n\nlocal Player = {}\nPlayer.__index = Player\n\n--\x3e Variables\n\nlocal keepStore = DataKeep.GetStore("PlayerData", DataTemplate):expect()\n\n--\x3e Private Functions\n\nlocal function initKeep(playerClass, keep)\n    local player = playerClass.Player\n\n    -- attributes & leaderstats\n\n    local attributes = Instance.new("Folder")\n    attributes.Name = "attributes"\n    attributes.Parent = player\n\n    local leaderstats = Instance.new("Folder")\n    leaderstats.Name = "leaderstats"\n    leaderstats.Parent = player\n\n    local function bindData(value, parent) -- leaderstats or attributes\n        local doesExist = keep.Data[value.Name]\n\n        if not doesExist then\n            return\n        end\n\n        value = value:Clone()\n\n        value.Value = keep.Data[value.Name]\n\n        value:GetPropertyChangedSignal("Value"):Connect(function() -- should clean on value destroy\n            keep.Data[value.Name] = value.Value\n        end)\n\n        value.Parent = parent\n\n        playerClass._keys[value.Name] = value\n    end\n\n    -- "attributes" and "leaderstats" are folders in the script parent\n    -- which contains numberValues / stringValues / boolValues\n\n    for _, attribute in script.Parent.attributes:GetChildren() do\n        bindData(attribute, attributes)\n    end\n\n    for _, leaderstat in script.Parent.leaderstats:GetChildren() do\n        bindData(leaderstat, leaderstats)\n    end\n\n    -- listen for globals\nend\n\nlocal function loadKeep(playerClass)\n    local player = playerClass.Player\n\n    local keep = keepStore:LoadKeep(`Player_{player.UserId}`)\n\n    keep:andThen(function(dataKeep)\n        if dataKeep == nil then\n            player:Kick("Session lock interrupted!")\n        end\n\n        dataKeep:Reconcile()\n        dataKeep:AddUserId(player.UserId) -- help with GDPR requests\n\n        dataKeep.Releasing:Connect(function(releaseState) -- don\'t have to clean up, it cleans up internally\n            releaseState\n                :andThen(function()\n                    player:Kick("Session released!")\n                    playerClass:Destroy()\n                end)\n                :catch(function(err)\n                    warn(err)\n                end)\n        end)\n\n        if not player:IsDescendantOf(Players) then\n            playerClass:Destroy()\n            return\n        end\n\n        initKeep(playerClass, dataKeep)\n    end)\n\n    return keep -- so they can attach to the promise\nend\n\n--\x3e Constructor\n\nfunction Player.new(player)\n    local self = setmetatable({\n        Player = player,\n\n        Keep = nil,\n\n        _keys = {}, -- stored attribute / leaderstats keys for changing to automatically change the datakeep. **MUST USE THESE FOR ANY ATTRIBUTES / LEADERSTATS BINDED**\n    }, Player)\n\n    self.Keep = loadKeep(self)\n\n    return self\nend\n\n--\x3e Public Methods\n\nfunction Player:GetKey(keyName: string)\n    return self._keys[keyName]\nend\n\nfunction Player:GetData(key: string)\n    local keep = self.Keep:expect()\n    return keep.Data[key]\nend\n\nfunction Player:Destroy()\n    -- do cleaning, this should generally include releasing the keep\n\n    if self._destroyed then\n        return\n    end\n\n    self._destroyed = true\n\n    if self.Keep then\n        local keep = self.Keep:expect()\n        keep:Release()\n    end\nend\n\nreturn Player\n')))}u.isMDXComponent=!0}}]);