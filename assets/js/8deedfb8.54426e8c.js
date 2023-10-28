"use strict";(self.webpackChunkdocs=self.webpackChunkdocs||[]).push([[556],{3905:(e,t,r)=>{r.d(t,{Zo:()=>u,kt:()=>m});var n=r(67294);function a(e,t,r){return t in e?Object.defineProperty(e,t,{value:r,enumerable:!0,configurable:!0,writable:!0}):e[t]=r,e}function l(e,t){var r=Object.keys(e);if(Object.getOwnPropertySymbols){var n=Object.getOwnPropertySymbols(e);t&&(n=n.filter((function(t){return Object.getOwnPropertyDescriptor(e,t).enumerable}))),r.push.apply(r,n)}return r}function i(e){for(var t=1;t<arguments.length;t++){var r=null!=arguments[t]?arguments[t]:{};t%2?l(Object(r),!0).forEach((function(t){a(e,t,r[t])})):Object.getOwnPropertyDescriptors?Object.defineProperties(e,Object.getOwnPropertyDescriptors(r)):l(Object(r)).forEach((function(t){Object.defineProperty(e,t,Object.getOwnPropertyDescriptor(r,t))}))}return e}function o(e,t){if(null==e)return{};var r,n,a=function(e,t){if(null==e)return{};var r,n,a={},l=Object.keys(e);for(n=0;n<l.length;n++)r=l[n],t.indexOf(r)>=0||(a[r]=e[r]);return a}(e,t);if(Object.getOwnPropertySymbols){var l=Object.getOwnPropertySymbols(e);for(n=0;n<l.length;n++)r=l[n],t.indexOf(r)>=0||Object.prototype.propertyIsEnumerable.call(e,r)&&(a[r]=e[r])}return a}var d=n.createContext({}),p=function(e){var t=n.useContext(d),r=t;return e&&(r="function"==typeof e?e(t):i(i({},t),e)),r},u=function(e){var t=p(e.components);return n.createElement(d.Provider,{value:t},e.children)},c="mdxType",s={inlineCode:"code",wrapper:function(e){var t=e.children;return n.createElement(n.Fragment,{},t)}},v=n.forwardRef((function(e,t){var r=e.components,a=e.mdxType,l=e.originalType,d=e.parentName,u=o(e,["components","mdxType","originalType","parentName"]),c=p(r),v=a,m=c["".concat(d,".").concat(v)]||c[v]||s[v]||l;return r?n.createElement(m,i(i({ref:t},u),{},{components:r})):n.createElement(m,i({ref:t},u))}));function m(e,t){var r=arguments,a=t&&t.mdxType;if("string"==typeof e||a){var l=r.length,i=new Array(l);i[0]=v;var o={};for(var d in t)hasOwnProperty.call(t,d)&&(o[d]=t[d]);o.originalType=e,o[c]="string"==typeof e?e:a,i[1]=o;for(var p=2;p<l;p++)i[p]=r[p];return n.createElement.apply(null,i)}return n.createElement.apply(null,r)}v.displayName="MDXCreateElement"},26437:(e,t,r)=>{r.r(t),r.d(t,{contentTitle:()=>i,default:()=>c,frontMatter:()=>l,metadata:()=>o,toc:()=>d});var n=r(87462),a=(r(67294),r(3905));const l={},i="DataKeep",o={type:"mdx",permalink:"/DataKeep/CHANGELOG",source:"@site/pages/CHANGELOG.md",title:"DataKeep",description:"version 1.1.8: 10/27/2023",frontMatter:{}},d=[{value:"version 1.1.8: 10/27/2023",id:"version-118-10272023",level:2},{value:"Added",id:"added",level:3},{value:"Improved",id:"improved",level:3},{value:"Fixed",id:"fixed",level:3},{value:"version 1.1.7: 10/25/2023",id:"version-117-10252023",level:2},{value:"Implemented",id:"implemented",level:3},{value:"Improved",id:"improved-1",level:3},{value:"version 1.1.5: 10/22/2023",id:"version-115-10222023",level:2},{value:"Added",id:"added-1",level:3},{value:"Fixed",id:"fixed-1",level:3},{value:"version 1.1.4: 10/22/2023",id:"version-114-10222023",level:2},{value:"Added",id:"added-2",level:3},{value:"Improved",id:"improved-2",level:3},{value:"Fixed",id:"fixed-2",level:3}],p={toc:d},u="wrapper";function c(e){let{components:t,...r}=e;return(0,a.kt)(u,(0,n.Z)({},p,r,{components:t,mdxType:"MDXLayout"}),(0,a.kt)("h1",{id:"datakeep"},"DataKeep"),(0,a.kt)("h2",{id:"version-118-10272023"},(0,a.kt)("a",{parentName:"h2",href:"https://github.com/noahrepublic/DataKeep/releases/tag/v1.1.8"},"version 1.1.8"),": 10/27/2023"),(0,a.kt)("h3",{id:"added"},"Added"),(0,a.kt)("ul",null,(0,a.kt)("li",{parentName:"ul"},"MetaData reconciles")),(0,a.kt)("h3",{id:"improved"},"Improved"),(0,a.kt)("ul",null,(0,a.kt)("li",{parentName:"ul"},"Quicker shutdown saves/releases"),(0,a.kt)("li",{parentName:"ul"},"Promise caching on release")),(0,a.kt)("h3",{id:"fixed"},"Fixed"),(0,a.kt)("ul",null,(0,a.kt)("li",{parentName:"ul"},"Coroutine dead? ")),(0,a.kt)("h2",{id:"version-117-10252023"},(0,a.kt)("a",{parentName:"h2",href:"https://github.com/noahrepublic/DataKeep/releases/tag/v1.1.7"},"version 1.1.7"),": 10/25/2023"),(0,a.kt)("h3",{id:"implemented"},"Implemented"),(0,a.kt)("ul",null,(0,a.kt)("li",{parentName:"ul"},"CriticalState"),(0,a.kt)("li",{parentName:"ul"},"IssueSignal")),(0,a.kt)("h3",{id:"improved-1"},"Improved"),(0,a.kt)("ul",null,(0,a.kt)("li",{parentName:"ul"},"Promise caching + Keep caching"),(0,a.kt)("li",{parentName:"ul"},"Some API documentation"),(0,a.kt)("li",{parentName:"ul"},"Saving loop on shutdown")),(0,a.kt)("p",null,"(version skip, just was a bad build)"),(0,a.kt)("h2",{id:"version-115-10222023"},(0,a.kt)("a",{parentName:"h2",href:"https://github.com/noahrepublic/DataKeep/releases/tag/v1.1.5"},"version 1.1.5"),": 10/22/2023"),(0,a.kt)("h3",{id:"added-1"},"Added"),(0,a.kt)("p",null,"Keep.MetaData.LoadCount"),(0,a.kt)("h3",{id:"fixed-1"},"Fixed"),(0,a.kt)("p",null,"Stablized Session Lock"),(0,a.kt)("h2",{id:"version-114-10222023"},(0,a.kt)("a",{parentName:"h2",href:"https://github.com/noahrepublic/DataKeep/releases/tag/v1.1.4"},"version 1.1.4"),": 10/22/2023"),(0,a.kt)("h3",{id:"added-2"},"Added"),(0,a.kt)("p",null,"Keep.MetaData.Created "),(0,a.kt)("h3",{id:"improved-2"},"Improved"),(0,a.kt)("p",null,"MockStore detection"),(0,a.kt)("h3",{id:"fixed-2"},"Fixed"),(0,a.kt)("p",null,"Session locked state"))}c.isMDXComponent=!0}}]);