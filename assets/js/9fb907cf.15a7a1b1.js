"use strict";(self.webpackChunkdocs=self.webpackChunkdocs||[]).push([[718],{3905:(e,t,n)=>{n.d(t,{Zo:()=>l,kt:()=>b});var r=n(67294);function i(e,t,n){return t in e?Object.defineProperty(e,t,{value:n,enumerable:!0,configurable:!0,writable:!0}):e[t]=n,e}function o(e,t){var n=Object.keys(e);if(Object.getOwnPropertySymbols){var r=Object.getOwnPropertySymbols(e);t&&(r=r.filter((function(t){return Object.getOwnPropertyDescriptor(e,t).enumerable}))),n.push.apply(n,r)}return n}function a(e){for(var t=1;t<arguments.length;t++){var n=null!=arguments[t]?arguments[t]:{};t%2?o(Object(n),!0).forEach((function(t){i(e,t,n[t])})):Object.getOwnPropertyDescriptors?Object.defineProperties(e,Object.getOwnPropertyDescriptors(n)):o(Object(n)).forEach((function(t){Object.defineProperty(e,t,Object.getOwnPropertyDescriptor(n,t))}))}return e}function c(e,t){if(null==e)return{};var n,r,i=function(e,t){if(null==e)return{};var n,r,i={},o=Object.keys(e);for(r=0;r<o.length;r++)n=o[r],t.indexOf(n)>=0||(i[n]=e[n]);return i}(e,t);if(Object.getOwnPropertySymbols){var o=Object.getOwnPropertySymbols(e);for(r=0;r<o.length;r++)n=o[r],t.indexOf(n)>=0||Object.prototype.propertyIsEnumerable.call(e,n)&&(i[n]=e[n])}return i}var p=r.createContext({}),u=function(e){var t=r.useContext(p),n=t;return e&&(n="function"==typeof e?e(t):a(a({},t),e)),n},l=function(e){var t=u(e.components);return r.createElement(p.Provider,{value:t},e.children)},s="mdxType",d={inlineCode:"code",wrapper:function(e){var t=e.children;return r.createElement(r.Fragment,{},t)}},f=r.forwardRef((function(e,t){var n=e.components,i=e.mdxType,o=e.originalType,p=e.parentName,l=c(e,["components","mdxType","originalType","parentName"]),s=u(n),f=i,b=s["".concat(p,".").concat(f)]||s[f]||d[f]||o;return n?r.createElement(b,a(a({ref:t},l),{},{components:n})):r.createElement(b,a({ref:t},l))}));function b(e,t){var n=arguments,i=t&&t.mdxType;if("string"==typeof e||i){var o=n.length,a=new Array(o);a[0]=f;var c={};for(var p in t)hasOwnProperty.call(t,p)&&(c[p]=t[p]);c.originalType=e,c[s]="string"==typeof e?e:i,a[1]=c;for(var u=2;u<o;u++)a[u]=n[u];return r.createElement.apply(null,a)}return r.createElement.apply(null,n)}f.displayName="MDXCreateElement"},38340:(e,t,n)=>{n.r(t),n.d(t,{assets:()=>p,contentTitle:()=>a,default:()=>d,frontMatter:()=>o,metadata:()=>c,toc:()=>u});var r=n(87462),i=(n(67294),n(3905));const o={sidebar_position:5},a="WriteLib",c={unversionedId:"WriteLib",id:"WriteLib",title:"WriteLib",description:"WriteLib provides a way to give Keeps custom mutating functions. A prebuilt WriteLib is provided in the module, but you can make your own, Keeps will inherit functions from the WriteLib",source:"@site/docs/WriteLib.md",sourceDirName:".",slug:"/WriteLib",permalink:"/DataKeep/docs/WriteLib",draft:!1,editUrl:"https://github.com/noahrepublic/DataKeep/edit/main/docs/WriteLib.md",tags:[],version:"current",sidebarPosition:5,frontMatter:{sidebar_position:5},sidebar:"defaultSidebar",previous:{title:"DataKeep vs ProfileService",permalink:"/DataKeep/docs/Versus"}},p={},u=[{value:"Defining a WriteLib",id:"defining-a-writelib",level:2}],l={toc:u},s="wrapper";function d(e){let{components:t,...n}=e;return(0,i.kt)(s,(0,r.Z)({},l,n,{components:t,mdxType:"MDXLayout"}),(0,i.kt)("h1",{id:"writelib"},"WriteLib"),(0,i.kt)("p",null,"WriteLib provides a way to give Keeps custom mutating functions. A prebuilt WriteLib is provided in the module, but you can make your own, Keeps will inherit functions from the WriteLib"),(0,i.kt)("h2",{id:"defining-a-writelib"},"Defining a WriteLib"),(0,i.kt)("pre",null,(0,i.kt)("code",{parentName:"pre",className:"language-lua"},'-- WriteLib.lua (stored anywheres you can access)\nreturn {\n    AddCoins = function(keep, amount)\n        keep.Data.Coins += amount\n    end,\n    RemoveCoins = function(keep, amount)\n        keep.Data.Coins -= amount\n    end,\n}\n\n-- main.lua\n\n\n\nlocal keepStore = DataKeep.GetStore("PlayerData", defaultData):awaitValue()\n\nkeepStore.Wrapper = require(path_to_WriteLib)\n\nkeepStore:LoadKeep("Player_" .. player.UserId):andThen(function(keep)\n    keep:AddCoins(100)\n    keep:RemoveCoins(50)\nend)\n')))}d.isMDXComponent=!0}}]);