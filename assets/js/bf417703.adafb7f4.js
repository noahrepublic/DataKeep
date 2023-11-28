"use strict";(self.webpackChunkdocs=self.webpackChunkdocs||[]).push([[476],{3905:(e,n,t)=>{t.d(n,{Zo:()=>c,kt:()=>f});var a=t(67294);function r(e,n,t){return n in e?Object.defineProperty(e,n,{value:t,enumerable:!0,configurable:!0,writable:!0}):e[n]=t,e}function o(e,n){var t=Object.keys(e);if(Object.getOwnPropertySymbols){var a=Object.getOwnPropertySymbols(e);n&&(a=a.filter((function(n){return Object.getOwnPropertyDescriptor(e,n).enumerable}))),t.push.apply(t,a)}return t}function l(e){for(var n=1;n<arguments.length;n++){var t=null!=arguments[n]?arguments[n]:{};n%2?o(Object(t),!0).forEach((function(n){r(e,n,t[n])})):Object.getOwnPropertyDescriptors?Object.defineProperties(e,Object.getOwnPropertyDescriptors(t)):o(Object(t)).forEach((function(n){Object.defineProperty(e,n,Object.getOwnPropertyDescriptor(t,n))}))}return e}function s(e,n){if(null==e)return{};var t,a,r=function(e,n){if(null==e)return{};var t,a,r={},o=Object.keys(e);for(a=0;a<o.length;a++)t=o[a],n.indexOf(t)>=0||(r[t]=e[t]);return r}(e,n);if(Object.getOwnPropertySymbols){var o=Object.getOwnPropertySymbols(e);for(a=0;a<o.length;a++)t=o[a],n.indexOf(t)>=0||Object.prototype.propertyIsEnumerable.call(e,t)&&(r[t]=e[t])}return r}var i=a.createContext({}),p=function(e){var n=a.useContext(i),t=n;return e&&(t="function"==typeof e?e(n):l(l({},n),e)),t},c=function(e){var n=p(e.components);return a.createElement(i.Provider,{value:n},e.children)},d="mdxType",u={inlineCode:"code",wrapper:function(e){var n=e.children;return a.createElement(a.Fragment,{},n)}},y=a.forwardRef((function(e,n){var t=e.components,r=e.mdxType,o=e.originalType,i=e.parentName,c=s(e,["components","mdxType","originalType","parentName"]),d=p(t),y=r,f=d["".concat(i,".").concat(y)]||d[y]||u[y]||o;return t?a.createElement(f,l(l({ref:n},c),{},{components:t})):a.createElement(f,l({ref:n},c))}));function f(e,n){var t=arguments,r=n&&n.mdxType;if("string"==typeof e||r){var o=t.length,l=new Array(o);l[0]=y;var s={};for(var i in n)hasOwnProperty.call(n,i)&&(s[i]=n[i]);s.originalType=e,s[d]="string"==typeof e?e:r,l[1]=s;for(var p=2;p<o;p++)l[p]=t[p];return a.createElement.apply(null,l)}return a.createElement.apply(null,t)}y.displayName="MDXCreateElement"},55022:(e,n,t)=>{t.r(n),t.d(n,{assets:()=>i,contentTitle:()=>l,default:()=>u,frontMatter:()=>o,metadata:()=>s,toc:()=>p});var a=t(87462),r=(t(67294),t(3905));const o={sidebar_position:3},l="Basic Usage",s={unversionedId:"Usage",id:"Usage",title:"Basic Usage",description:"DataKeep will lift everything, the only thing you need to do is load data. DataKeep does not use getter/setter functions allowing for customizable experience like, make your own wrapper.",source:"@site/docs/Usage.md",sourceDirName:".",slug:"/Usage",permalink:"/DataKeep/docs/Usage",draft:!1,editUrl:"https://github.com/noahrepublic/DataKeep/edit/main/docs/Usage.md",tags:[],version:"current",sidebarPosition:3,frontMatter:{sidebar_position:3},sidebar:"defaultSidebar",previous:{title:"Installation",permalink:"/DataKeep/docs/Installation"},next:{title:"DataKeep vs ProfileService",permalink:"/DataKeep/docs/Versus"}},i={},p=[],c={toc:p},d="wrapper";function u(e){let{components:n,...t}=e;return(0,r.kt)(d,(0,a.Z)({},c,t,{components:n,mdxType:"MDXLayout"}),(0,r.kt)("h1",{id:"basic-usage"},"Basic Usage"),(0,r.kt)("p",null,"DataKeep will lift everything, the only thing you need to do is load data. DataKeep does not use getter/setter functions allowing for customizable experience like, make your own wrapper."),(0,r.kt)("p",null,"The following is a very basic Keep loader implementation."),(0,r.kt)("pre",null,(0,r.kt)("code",{parentName:"pre",className:"language-lua"},'local Players = game:GetService("Players")\n\nlocal DataKeep = require(path_to_datakeep)\n\nlocal defaultData = {\n    Coins = 0,\n}\n\nlocal loadedKeeps = {}\n\nlocal keepStore = DataKeep.GetStore("PlayerData", defaultData) -- generally you can just :awaitValue() I just want to showcase Promises to those unfamiliar\n\nlocal function onPlayerJoin(player)\n    keepStore:LoadKeep("Player_" .. player.UserId):andThen(function(keep)\n        if keep == nil then\n            player:Kick("Data locked") -- will never happen, when no releaseHandler is passed it default steals from the locked session\n        end\n\n        keep:Reconcile()\n        keep:AddUserId(player.UserId) -- help with GDPR requests\n\n        keep.OnRelease:Connect(function() -- don\'t have to clean up, it cleans up internally.\n            player:Kick("Session Release")\n        end)\n\n        if not player:IsDescendantOf(Players) then\n            keep:Release()\n            return\n        end\n\n        print(`Loaded {player.Name}\'s Keep!`)\n        \n        loadedKeeps[player] = keep\n        \n        local leaderstats = Instance.new("Folder")\n        leaderstats.Name = "leaderstats"\n\n        local coins = Instance.new("NumberValue")\n        coins.Name = "Coins"\n        coins.Value = keep.Data.Coins\n\n        leaderstats.Parent = player\n    end)\nend\n\nPlayers.PlayerRemoving:Connect(function(player)\n    local keep = loadedKeeps[player]\n\n    if not keep then return end\n\n    keep:Release()\nend)\n\nkeepStore:andThen(function(store)\n    keepStore = store\n    Players.PlayerAdded:Connect(onPlayerJoin)\nend)\n')),(0,r.kt)("h1",{id:"class-approach"},"Class Approach"),(0,r.kt)("p",null,'For more experienced developers I personally opt in to create a service that returns a "Player" OOP class that holds it own cleaner and a Keep inside.'))}u.isMDXComponent=!0}}]);